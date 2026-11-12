using System.Collections.Concurrent;
using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Client;

namespace Aviation.Blazor.Services;

/// <summary>
/// Lightweight sync status shown in the Blazor UI.
/// Maps from <see cref="SyncEngine.Abstractions.Client.SyncSessionPhase"/> — keep this UI enum
/// in sync with that core vocabulary when adding values.
/// </summary>
public enum FacilityViewSyncStatus
{
    Initializing,
    Syncing,
    CatchingUp,
    Live,
    Offline,
    Reconnecting,
    Error,
}

public sealed class FacilityViewService : IDisposable
{
    private readonly InMemoryEntityStore _store;
    private readonly ISyncEntityStore<Facility> _facilityStore;
    private readonly IDeltaCodec _codec;
    private readonly HttpClient _http;
    private readonly string _serverBase;
    private readonly ILogger<FacilityViewService> _logger;
    private readonly ConcurrentDictionary<string, Facility> _optimistic = new();

    // Debounce config: collapse bursts of EntityChanged into a single UI refresh.
    private static readonly TimeSpan DebounceInterval = TimeSpan.FromMilliseconds(150);
    private static readonly TimeSpan MaxDebounceWait = TimeSpan.FromMilliseconds(750);

    private readonly object _timerLock = new();
    private readonly Timer _debounceTimer;
    private DateTime _firstPendingUtc;
    private bool _pending;
    private int _disposed;

    public FacilityViewService(
        InMemoryEntityStore store,
        ISyncEntityStore<Facility> facilityStore,
        IDeltaCodec codec,
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration,
        ILogger<FacilityViewService> logger)
    {
        _store = store;
        _facilityStore = facilityStore;
        _codec = codec;
        _http = httpClientFactory.CreateClient();
        _serverBase = configuration["SyncEngine:ServerBaseAddress"] ?? "http://localhost:5080";
        _logger = logger;

        _debounceTimer = new Timer(OnDebounceTick, state: null, dueTime: Timeout.Infinite, period: Timeout.Infinite);
        _facilityStore.EntityChanged += OnFacilityEntityChanged;
    }

    /// <summary>Fires at most once per <see cref="DebounceInterval"/> after cache mutations.</summary>
    public event Action? Changed;

    /// <summary>Fires when <see cref="Status"/> or <see cref="StatusMessage"/> transitions.</summary>
    public event Action? StatusChanged;

    public FacilityViewSyncStatus Status { get; private set; } = FacilityViewSyncStatus.Initializing;

    public string? StatusMessage { get; private set; }

    public DateTime? LastUpdateUtc { get; private set; }

    public string? LastConflictMessage { get; private set; }

    public int CachedCount => _store.GetAll(AviationEntityNames.Facility).Count;

    /// <summary>Returns true if the given facility ID is an optimistic (unconfirmed) entry.</summary>
    public bool IsOptimistic(string facilityId) => _optimistic.ContainsKey(facilityId);

    public IReadOnlyList<Facility> GetFacilities(int take = 100)
    {
        if (take <= 0)
        {
            return Array.Empty<Facility>();
        }

        var cap = Math.Min(take, 100);
        var results = new List<Facility>(cap);
        var synced = _facilityStore.GetAll();

        foreach (var facility in synced)
        {
            if (facility is null)
            {
                continue;
            }

            facility.MetadataJson = null;
            results.Add(facility);
        }

        // Merge optimistic entries: add any not yet confirmed by the store.
        foreach (var (id, opt) in _optimistic)
        {
            if (!results.Any(f => f.FacilityId == id))
            {
                var clone = new Facility
                {
                    FacilityId = opt.FacilityId,
                    FacilityCode = opt.FacilityCode,
                    Name = opt.Name,
                    FacilityTypeCode = opt.FacilityTypeCode,
                    City = opt.City,
                    StateCode = opt.StateCode,
                    ZipCode = opt.ZipCode,
                    Latitude = opt.Latitude,
                    Longitude = opt.Longitude,
                    OperationalStatus = opt.OperationalStatus,
                };
                results.Add(clone);
            }
            else
            {
                // Real data arrived — remove from optimistic
                _optimistic.TryRemove(id, out _);
            }
        }

        results.Sort(static (a, b) =>
            string.Compare(a.FacilityCode, b.FacilityCode, StringComparison.OrdinalIgnoreCase));

        if (results.Count > take)
        {
            results.RemoveRange(take, results.Count - take);
        }

        return results;
    }

    public async Task UpsertOptimisticAsync(Facility facility, CancellationToken cancellationToken = default)
    {
        _optimistic[facility.FacilityId] = facility;
        Changed?.Invoke();

        try
        {
            using var response = await _http.PostAsJsonAsync(
                $"{_serverBase.TrimEnd('/')}/api/facilities", facility, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                LastConflictMessage = response.StatusCode == System.Net.HttpStatusCode.Conflict
                    ? "Conflict: another user modified this facility."
                    : $"Server error: {response.StatusCode}";
                RaiseStatusChanged();
            }
            else
            {
                LastConflictMessage = null;
            }
        }
        catch (HttpRequestException)
        {
            LastConflictMessage = "Offline — change queued locally.";
            RaiseStatusChanged();
        }
    }

    public async Task UpsertAsync(Facility facility, CancellationToken cancellationToken = default)
    {
        using var response = await _http.PostAsJsonAsync(
            $"{_serverBase.TrimEnd('/')}/api/facilities",
            facility,
            cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    public void DismissConflict()
    {
        LastConflictMessage = null;
        RaiseStatusChanged();
    }

    /// <summary>Called by the sync host to publish lightweight status to the UI.</summary>
    public void SetStatus(FacilityViewSyncStatus status, string? message = null)
    {
        if (Status == status && string.Equals(StatusMessage, message, StringComparison.Ordinal))
        {
            return;
        }

        Status = status;
        StatusMessage = message;
        if (status == FacilityViewSyncStatus.Live)
        {
            LastUpdateUtc = DateTime.UtcNow;
        }

        RaiseStatusChanged();
    }

    /// <summary>
    /// Marks the last successful apply time.
    /// </summary>
    public void MarkAppliedBatch()
    {
        LastUpdateUtc = DateTime.UtcNow;
        RaiseStatusChanged();
    }

    private void OnFacilityEntityChanged(SyncEntityEvent<Facility> evt)
    {
        if (Volatile.Read(ref _disposed) != 0)
        {
            return;
        }

        // Clean up optimistic entries when real data arrives
        if (evt.Entity is { } entity)
        {
            _optimistic.TryRemove(entity.FacilityId, out _);
        }

        lock (_timerLock)
        {
            if (!_pending)
            {
                _pending = true;
                _firstPendingUtc = DateTime.UtcNow;
            }

            var elapsed = DateTime.UtcNow - _firstPendingUtc;
            var delay = elapsed >= MaxDebounceWait ? TimeSpan.Zero : DebounceInterval;

            try
            {
                _debounceTimer.Change(delay, Timeout.InfiniteTimeSpan);
            }
            catch (ObjectDisposedException)
            {
            }
        }
    }

    private void OnDebounceTick(object? state)
    {
        lock (_timerLock)
        {
            if (!_pending)
            {
                return;
            }

            _pending = false;
        }

        var handler = Changed;
        if (handler is null)
        {
            return;
        }

        try
        {
            handler();
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "FacilityViewService.Changed subscriber threw.");
        }
    }

    private void RaiseStatusChanged()
    {
        var handler = StatusChanged;
        if (handler is null)
        {
            return;
        }

        try
        {
            handler();
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "FacilityViewService.StatusChanged subscriber threw.");
        }
    }

    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0)
        {
            return;
        }

        _facilityStore.EntityChanged -= OnFacilityEntityChanged;
        _debounceTimer.Dispose();
    }
}
