using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using Aviation.Shared.Entities;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Client.Sqlite;

namespace Aviation.Maui.Services;

/// <summary>
/// Backs <c>MainPage</c>. Displays the top ~100 facilities and reflects live sync state.
/// </summary>
public sealed class FacilityListViewModel : INotifyPropertyChanged
{
    /// <summary>Cap the collection to keep the UI snappy even after a huge load-gen run.</summary>
    public const int DisplayLimit = 100;

    private readonly SqliteConnectionFactory _connectionFactory;
    private readonly IDeltaCodec _codec;
    private readonly HttpClient _http;
    private readonly SyncPullService _pullService;
    private readonly MauiSyncBootstrapper _bootstrapper;
    private readonly ILogger<FacilityListViewModel> _logger;
    private readonly SemaphoreSlim _refreshGate = new(1, 1);

    private string _statusText = "Starting…";
    private string? _errorText;
    private string _lastSyncText = "–";
    private string _facilityCountText = "0 facilities";

    public FacilityListViewModel(
        SqliteConnectionFactory connectionFactory,
        IDeltaCodec codec,
        IHttpClientFactory httpClientFactory,
        SyncPullService pullService,
        MauiSyncBootstrapper bootstrapper,
        ILogger<FacilityListViewModel> logger)
    {
        _connectionFactory = connectionFactory;
        _codec = codec;
        _http = httpClientFactory.CreateClient();
        _pullService = pullService;
        _bootstrapper = bootstrapper;
        _logger = logger;

        _pullService.BatchApplied += OnBatchApplied;
        _bootstrapper.StatusChanged += OnBootstrapStatus;
        _bootstrapper.ErrorRaised += OnBootstrapError;
        _bootstrapper.SyncCompleted += OnBootstrapSyncCompleted;
    }

    public ObservableCollection<Facility> Facilities { get; } = [];

    public string StatusText
    {
        get => _statusText;
        private set => SetField(ref _statusText, value);
    }

    public string? ErrorText
    {
        get => _errorText;
        private set
        {
            if (SetField(ref _errorText, value))
            {
                OnPropertyChanged(nameof(HasError));
            }
        }
    }

    public bool HasError => !string.IsNullOrEmpty(_errorText);

    public string LastSyncText
    {
        get => _lastSyncText;
        private set => SetField(ref _lastSyncText, value);
    }

    public string FacilityCountText
    {
        get => _facilityCountText;
        private set => SetField(ref _facilityCountText, value);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// Reload the top <see cref="DisplayLimit"/> facilities from local SQLite onto the UI.
    /// Decode failures on individual rows are swallowed; <c>MetadataJson</c> is stripped so
    /// large load-gen pads don't blow up the UI.
    /// </summary>
    public async Task RefreshAsync()
    {
        // Prevent overlapping refreshes (e.g. BatchApplied firing while a manual refresh runs).
        if (!await _refreshGate.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false))
        {
            return;
        }

        try
        {
            var items = await LoadFacilitiesAsync(DisplayLimit).ConfigureAwait(false);

            await InvokeOnMainThreadAsync(() =>
            {
                Facilities.Clear();
                foreach (var facility in items)
                {
                    Facilities.Add(facility);
                }

                FacilityCountText = items.Count >= DisplayLimit
                    ? $"showing top {DisplayLimit}"
                    : $"{items.Count} facilities";

                OnPropertyChanged(nameof(Facilities));
            }).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Facility refresh failed.");
            await InvokeOnMainThreadAsync(() => ErrorText = $"Refresh failed: {ex.Message}").ConfigureAwait(false);
        }
        finally
        {
            _refreshGate.Release();
        }
    }

    /// <summary>
    /// Force a pull from the server, then refresh the UI. Used by the Refresh button and after
    /// <see cref="AddFacilityAsync"/> so we don't wait on a SignalR wake we may miss.
    /// </summary>
    public async Task PullAndRefreshAsync(CancellationToken cancellationToken = default)
    {
        await _bootstrapper.TriggerPullAsync(cancellationToken).ConfigureAwait(false);
        await RefreshAsync().ConfigureAwait(false);
    }

    public async Task AddFacilityAsync()
    {
        var id = Guid.NewGuid().ToString("N")[..8];
        var facility = new Facility
        {
            FacilityId = $"fac-{id}",
            FacilityCode = $"M{id[..3]}".ToUpperInvariant(),
            Name = $"Maui Facility {id}",
            FacilityTypeCode = "AIRPORT",
            City = "Dubuque",
            StateCode = "IA",
            ZipCode = "52001",
            Latitude = 42.4020m,
            Longitude = -90.7095m,
        };

        try
        {
            using var response = await _http
                .PostAsJsonAsync("http://localhost:5080/api/facilities", facility)
                .ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            await InvokeOnMainThreadAsync(() => ErrorText = null).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AddFacility POST failed.");
            await InvokeOnMainThreadAsync(() => ErrorText = $"Add failed: {ex.Message}").ConfigureAwait(false);
            throw;
        }

        // Don't rely solely on the SignalR wake — pull now so the row shows up immediately
        // in the demo even if the hub happens to be reconnecting.
        await PullAndRefreshAsync().ConfigureAwait(false);
    }

    private async Task<List<Facility>> LoadFacilitiesAsync(int limit)
    {
        await using var connection = await _connectionFactory.OpenAsync().ConfigureAwait(false);

        await using (var ensure = connection.CreateCommand())
        {
            ensure.CommandText =
                """
                CREATE TABLE IF NOT EXISTS sync_entity (
                    entity_name TEXT NOT NULL,
                    entity_key BLOB NOT NULL,
                    payload BLOB,
                    PRIMARY KEY (entity_name, entity_key)
                );
                """;
            await ensure.ExecuteNonQueryAsync().ConfigureAwait(false);
        }

        // Fetch a bit more than the display limit so decode errors don't shrink the list below the cap.
        var fetchLimit = Math.Max(limit * 4, limit);

        await using var command = connection.CreateCommand();
        command.CommandText =
            "SELECT payload FROM sync_entity WHERE entity_name = $name AND payload IS NOT NULL LIMIT $limit";
        command.Parameters.AddWithValue("$name", AviationEntityNames.Facility);
        command.Parameters.AddWithValue("$limit", fetchLimit);

        var decoded = new List<Facility>(capacity: limit);
        await using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            if (reader.IsDBNull(0))
            {
                continue;
            }

            byte[] payload;
            try
            {
                payload = (byte[])reader[0];
            }
            catch
            {
                continue;
            }

            Facility? facility;
            try
            {
                facility = _codec.Decode<Facility>(payload);
            }
            catch (Exception ex)
            {
                // A single bad row — maybe a MemoryPack schema skew — should never kill the refresh.
                _logger.LogDebug(ex, "Skipping facility row that failed to decode ({Bytes} B).", payload.Length);
                continue;
            }

            if (facility is null)
            {
                continue;
            }

            // Drop the fat pad before the row touches the UI; the raw bytes stay in SQLite.
            facility.MetadataJson = null;
            decoded.Add(facility);
        }

        decoded.Sort(static (a, b) => string.Compare(a.FacilityCode, b.FacilityCode, StringComparison.OrdinalIgnoreCase));
        if (decoded.Count > limit)
        {
            decoded.RemoveRange(limit, decoded.Count - limit);
        }
        return decoded;
    }

    private void OnBatchApplied(DeltaBatch batch)
    {
        if (batch.Changes is null || batch.Changes.Length == 0)
        {
            return;
        }

        var touchesFacility = false;
        foreach (var change in batch.Changes)
        {
            if (string.Equals(change.EntityName, AviationEntityNames.Facility, StringComparison.OrdinalIgnoreCase))
            {
                touchesFacility = true;
                break;
            }
        }

        if (!touchesFacility)
        {
            return;
        }

        // Kick the refresh onto a background Task so we don't re-enter the pull lock
        // or run the SQLite reader on the pull-service's thread. RefreshAsync marshals
        // the ObservableCollection updates to the UI thread itself.
        _ = Task.Run(RefreshAsync);
    }

    private void OnBootstrapStatus(string status)
        => _ = InvokeOnMainThreadAsync(() => StatusText = status);

    private void OnBootstrapError(Exception? ex)
        => _ = InvokeOnMainThreadAsync(() => ErrorText = ex?.Message);

    private void OnBootstrapSyncCompleted()
        => _ = InvokeOnMainThreadAsync(() =>
        {
            LastSyncText = DateTimeOffset.Now.ToString("HH:mm:ss");
            ErrorText = null;
        });

    private static Task InvokeOnMainThreadAsync(Action action)
    {
        if (MainThread.IsMainThread)
        {
            action();
            return Task.CompletedTask;
        }

        var tcs = new TaskCompletionSource();
        MainThread.BeginInvokeOnMainThread(() =>
        {
            try
            {
                action();
                tcs.TrySetResult();
            }
            catch (Exception ex)
            {
                tcs.TrySetException(ex);
            }
        });
        return tcs.Task;
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(name);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
