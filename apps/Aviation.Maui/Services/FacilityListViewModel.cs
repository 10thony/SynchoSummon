using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using Aviation.Shared.Entities;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Client;
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
    private readonly ISyncSession _session;
    private readonly ILogger<FacilityListViewModel> _logger;
    private readonly SemaphoreSlim _refreshGate = new(1, 1);
    private readonly HashSet<string> _pendingIds = new(StringComparer.Ordinal);

    private string _statusText = "Starting…";
    private string? _errorText;
    private string _lastSyncText = "–";
    private string _facilityCountText = "0 facilities";
    private bool _isLoading = true;
    private string? _offlineBanner;

    public FacilityListViewModel(
        SqliteConnectionFactory connectionFactory,
        IDeltaCodec codec,
        IHttpClientFactory httpClientFactory,
        SyncPullService pullService,
        MauiSyncBootstrapper bootstrapper,
        ISyncSession session,
        ILogger<FacilityListViewModel> logger)
    {
        _connectionFactory = connectionFactory;
        _codec = codec;
        _http = httpClientFactory.CreateClient();
        _pullService = pullService;
        _bootstrapper = bootstrapper;
        _session = session;
        _logger = logger;

        _pullService.BatchApplied += OnBatchApplied;
        _bootstrapper.StatusChanged += OnBootstrapStatus;
        _bootstrapper.ErrorRaised += OnBootstrapError;
        _bootstrapper.SyncCompleted += OnBootstrapSyncCompleted;

        _session.SnapshotChanged += OnSnapshotChanged;
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

    public bool IsLoading
    {
        get => _isLoading;
        private set
        {
            if (SetField(ref _isLoading, value))
            {
                OnPropertyChanged(nameof(IsEmpty));
            }
        }
    }

    public bool IsEmpty => !IsLoading && Facilities.Count == 0;

    public bool HasPendingWrites => _pendingIds.Count > 0;

    public bool IsPending(string facilityId) => _pendingIds.Contains(facilityId);

    public string? OfflineBanner
    {
        get => _offlineBanner;
        private set => SetField(ref _offlineBanner, value);
    }

    public bool ShowOfflineBanner => !string.IsNullOrEmpty(_offlineBanner);

    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// Reload the top <see cref="DisplayLimit"/> facilities from local SQLite onto the UI.
    /// Uses diff-patch to avoid flicker instead of Clear+Add.
    /// </summary>
    public async Task RefreshAsync()
    {
        if (!await _refreshGate.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false))
        {
            return;
        }

        try
        {
            var items = await LoadFacilitiesAsync(DisplayLimit).ConfigureAwait(false);

            await InvokeOnMainThreadAsync(() =>
            {
                DiffPatch(Facilities, items, f => f.FacilityId, (existing, updated) =>
                {
                    existing.FacilityCode = updated.FacilityCode;
                    existing.Name = updated.Name;
                    existing.City = updated.City;
                    existing.StateCode = updated.StateCode;
                    existing.OperationalStatus = updated.OperationalStatus;
                });

                // Clear pending IDs for items that arrived from the real data
                foreach (var item in items)
                {
                    _pendingIds.Remove(item.FacilityId);
                }
                OnPropertyChanged(nameof(HasPendingWrites));

                FacilityCountText = items.Count >= DisplayLimit
                    ? $"showing top {DisplayLimit}"
                    : $"{items.Count} facilities";

                IsLoading = false;
                OnPropertyChanged(nameof(IsEmpty));
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

        _pendingIds.Add(facility.FacilityId);
        await InvokeOnMainThreadAsync(() =>
        {
            Facilities.Insert(0, facility);
            OnPropertyChanged(nameof(HasPendingWrites));
            OnPropertyChanged(nameof(IsEmpty));
        }).ConfigureAwait(false);

        try
        {
            using var response = await _http
                .PostAsJsonAsync("http://localhost:5080/api/facilities", facility)
                .ConfigureAwait(false);

            if (response.StatusCode == System.Net.HttpStatusCode.Conflict)
            {
                await InvokeOnMainThreadAsync(() =>
                    ErrorText = "Conflict: another user modified this facility.").ConfigureAwait(false);
            }
            else
            {
                response.EnsureSuccessStatusCode();
                await InvokeOnMainThreadAsync(() => ErrorText = null).ConfigureAwait(false);
            }
        }
        catch (HttpRequestException)
        {
            await InvokeOnMainThreadAsync(() =>
                ErrorText = "Offline — change will sync when connected.").ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AddFacility POST failed.");
            await InvokeOnMainThreadAsync(() =>
                ErrorText = $"Add failed: {ex.Message}").ConfigureAwait(false);
        }

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
                _logger.LogDebug(ex, "Skipping facility row that failed to decode ({Bytes} B).", payload.Length);
                continue;
            }

            if (facility is null)
            {
                continue;
            }

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

    /// <summary>
    /// Diff-patch an <see cref="ObservableCollection{T}"/> against a fresh source list.
    /// Never calls <c>Clear()</c> — removes stale items, updates existing ones in-place,
    /// and inserts new ones at the correct position.
    /// </summary>
    private static void DiffPatch<T>(
        ObservableCollection<T> target,
        IReadOnlyList<T> source,
        Func<T, string> keySelector,
        Action<T, T>? copyProps = null)
    {
        var sourceKeys = new HashSet<string>(source.Select(keySelector), StringComparer.Ordinal);

        for (var i = target.Count - 1; i >= 0; i--)
        {
            if (!sourceKeys.Contains(keySelector(target[i])))
                target.RemoveAt(i);
        }

        var targetMap = target.Select((item, idx) => (Key: keySelector(item), Index: idx))
            .ToDictionary(x => x.Key, x => x.Index, StringComparer.Ordinal);

        for (var i = 0; i < source.Count; i++)
        {
            var key = keySelector(source[i]);
            if (targetMap.TryGetValue(key, out var existingIdx))
            {
                copyProps?.Invoke(target[existingIdx], source[i]);
            }
            else
            {
                target.Insert(Math.Min(i, target.Count), source[i]);
            }
        }
    }

    private SyncSessionPhase _lastPhase = SyncSessionPhase.Stopped;

    private void OnSnapshotChanged(SyncSessionSnapshot snapshot)
    {
        var banner = snapshot.Phase switch
        {
            SyncSessionPhase.OfflinePolling => "You're offline. Changes will sync when connected.",
            SyncSessionPhase.Reconnecting => "Reconnecting to sync server…",
            SyncSessionPhase.Degraded when snapshot.LastError is not null =>
                $"Sync error: {snapshot.LastError.Message}",
            _ => null,
        };

        var wasDisconnected = _lastPhase is SyncSessionPhase.OfflinePolling
            or SyncSessionPhase.Reconnecting
            or SyncSessionPhase.Degraded;
        var nowConnected = snapshot.Phase is SyncSessionPhase.Live
            or SyncSessionPhase.CatchingUp
            or SyncSessionPhase.Syncing;
        var recovered = wasDisconnected && nowConnected;
        _lastPhase = snapshot.Phase;

        _ = InvokeOnMainThreadAsync(() =>
        {
            OfflineBanner = banner;
            OnPropertyChanged(nameof(ShowOfflineBanner));

            StatusText = snapshot.Phase is SyncSessionPhase.CatchingUp && snapshot.CatchUpAppliedCount is > 0
                ? $"Catching up ({snapshot.CatchUpAppliedCount} applied)…"
                : snapshot.DisplayStatus;

            if (recovered)
            {
                ErrorText = null;
            }
        });

        // After hub recovery, force a pull + UI reload so the list isn't stuck on stale SQLite.
        if (recovered)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    await PullAndRefreshAsync().ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    _logger.LogDebug(ex, "Post-reconnect refresh failed.");
                }
            });
        }
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

        _ = Task.Run(RefreshAsync);
    }

    private void OnBootstrapStatus(string status)
        => _ = InvokeOnMainThreadAsync(() => StatusText = status);

    private void OnBootstrapError(Exception? ex)
        => _ = InvokeOnMainThreadAsync(() => ErrorText = ex?.Message);

    private void OnBootstrapSyncCompleted()
    {
        _ = InvokeOnMainThreadAsync(() =>
        {
            LastSyncText = DateTimeOffset.Now.ToString("HH:mm:ss");
            ErrorText = null;
        });
        // Periodic HTTP pulls apply to SQLite even while OfflinePolling — refresh the list.
        _ = Task.Run(RefreshAsync);
    }

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
