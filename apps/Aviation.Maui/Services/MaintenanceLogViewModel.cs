using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using Aviation.Shared.Entities;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Client.Sqlite;

namespace Aviation.Maui.Services;

/// <summary>
/// Read-only maintenance log list backed by the local SQLite sync store.
/// Sorted by <see cref="MaintenanceLog.LoggedAt"/> descending (newest first).
/// </summary>
public sealed class MaintenanceLogViewModel : INotifyPropertyChanged
{
    public const int DisplayLimit = 100;

    private readonly SqliteConnectionFactory _connectionFactory;
    private readonly IDeltaCodec _codec;
    private readonly SyncPullService _pullService;
    private readonly ILogger<MaintenanceLogViewModel> _logger;
    private readonly SemaphoreSlim _refreshGate = new(1, 1);

    private bool _isLoading = true;
    private string _countText = "0 logs";

    public MaintenanceLogViewModel(
        SqliteConnectionFactory connectionFactory,
        IDeltaCodec codec,
        SyncPullService pullService,
        ILogger<MaintenanceLogViewModel> logger)
    {
        _connectionFactory = connectionFactory;
        _codec = codec;
        _pullService = pullService;
        _logger = logger;

        _pullService.BatchApplied += OnBatchApplied;
    }

    public ObservableCollection<MaintenanceLog> Logs { get; } = [];

    public bool IsLoading
    {
        get => _isLoading;
        private set
        {
            if (SetField(ref _isLoading, value))
                OnPropertyChanged(nameof(IsEmpty));
        }
    }

    public bool IsEmpty => !IsLoading && Logs.Count == 0;

    public string CountText
    {
        get => _countText;
        private set => SetField(ref _countText, value);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public async Task RefreshAsync()
    {
        if (!await _refreshGate.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false))
            return;

        try
        {
            var items = await LoadLogsAsync(DisplayLimit).ConfigureAwait(false);

            await InvokeOnMainThreadAsync(() =>
            {
                DiffPatch(Logs, items, l => l.MaintenanceLogId, (existing, updated) =>
                {
                    existing.LogEntryType = updated.LogEntryType;
                    existing.Message = updated.Message;
                    existing.FacilityId = updated.FacilityId;
                    existing.EquipmentId = updated.EquipmentId;
                    existing.LoggedAt = updated.LoggedAt;
                    existing.LocationLabel = updated.LocationLabel;
                });

                CountText = items.Count >= DisplayLimit
                    ? $"showing top {DisplayLimit}"
                    : $"{items.Count} logs";

                IsLoading = false;
                OnPropertyChanged(nameof(IsEmpty));
            }).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "MaintenanceLog refresh failed.");
        }
        finally
        {
            _refreshGate.Release();
        }
    }

    private async Task<List<MaintenanceLog>> LoadLogsAsync(int limit)
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
        command.Parameters.AddWithValue("$name", AviationEntityNames.MaintenanceLog);
        command.Parameters.AddWithValue("$limit", fetchLimit);

        var decoded = new List<MaintenanceLog>(capacity: limit);
        await using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            if (reader.IsDBNull(0)) continue;

            byte[] payload;
            try { payload = (byte[])reader[0]; }
            catch { continue; }

            MaintenanceLog? item;
            try { item = _codec.Decode<MaintenanceLog>(payload); }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Skipping maintenance log row that failed to decode ({Bytes} B).", payload.Length);
                continue;
            }

            if (item is null) continue;

            item.MetadataJson = null;
            decoded.Add(item);
        }

        // Sort newest first
        decoded.Sort(static (a, b) => b.LoggedAt.CompareTo(a.LoggedAt));
        if (decoded.Count > limit)
            decoded.RemoveRange(limit, decoded.Count - limit);

        return decoded;
    }

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

    private void OnBatchApplied(DeltaBatch batch)
    {
        if (batch.Changes is null || batch.Changes.Length == 0)
            return;

        var touches = false;
        foreach (var change in batch.Changes)
        {
            if (string.Equals(change.EntityName, AviationEntityNames.MaintenanceLog, StringComparison.OrdinalIgnoreCase))
            {
                touches = true;
                break;
            }
        }

        if (touches)
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
            try { action(); tcs.TrySetResult(); }
            catch (Exception ex) { tcs.TrySetException(ex); }
        });
        return tcs.Task;
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;
        field = value;
        OnPropertyChanged(name);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
