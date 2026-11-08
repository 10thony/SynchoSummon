using Aviation.Shared.Entities;
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
    private readonly IDeltaCodec _codec;
    private readonly HttpClient _http;
    private readonly string _serverBase;
    private readonly ILogger<FacilityViewService> _logger;

    // Debounce config: collapse bursts of EntityChanged into a single UI refresh.
    // Catch-up pulls after load-gen can fire thousands of EntityChanged events in rapid
    // succession; without this, every change caused the Blazor circuit to re-decode the
    // entire facility cache and re-render — pegging the circuit thread until the browser
    // gave up and showed the generic "reconnecting" UI.
    private static readonly TimeSpan DebounceInterval = TimeSpan.FromMilliseconds(150);
    // Guarantee a refresh at least every ~750ms during a long sustained burst so the
    // user still sees progress mid catch-up instead of waiting silently for the burst
    // to end.
    private static readonly TimeSpan MaxDebounceWait = TimeSpan.FromMilliseconds(750);

    private readonly object _timerLock = new();
    private readonly Timer _debounceTimer;
    private DateTime _firstPendingUtc;
    private bool _pending;
    private int _disposed;

    public FacilityViewService(
        InMemoryEntityStore store,
        IDeltaCodec codec,
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration,
        ILogger<FacilityViewService> logger)
    {
        _store = store;
        _codec = codec;
        _http = httpClientFactory.CreateClient();
        _serverBase = configuration["SyncEngine:ServerBaseAddress"] ?? "http://localhost:5080";
        _logger = logger;

        _debounceTimer = new Timer(OnDebounceTick, state: null, dueTime: Timeout.Infinite, period: Timeout.Infinite);
        _store.EntityChanged += OnStoreEntityChanged;
    }

    /// <summary>Fires at most once per <see cref="DebounceInterval"/> after cache mutations.</summary>
    public event Action? Changed;

    /// <summary>Fires when <see cref="Status"/> or <see cref="StatusMessage"/> transitions.</summary>
    public event Action? StatusChanged;

    public FacilityViewSyncStatus Status { get; private set; } = FacilityViewSyncStatus.Initializing;

    public string? StatusMessage { get; private set; }

    public DateTime? LastUpdateUtc { get; private set; }

    public int CachedCount => _store.GetAll(AviationEntityNames.Facility).Count;

    public IReadOnlyList<Facility> GetFacilities(int take = 100)
    {
        if (take <= 0)
        {
            return Array.Empty<Facility>();
        }

        // The UI only displays a sample — load packages can contain thousands of fat rows.
        // Walking the ConcurrentDictionary view is safe against concurrent writers; worst
        // case we read a snapshot that is one delta behind, which the next debounced
        // refresh will reconcile.
        var cap = Math.Min(take, 100);
        var results = new List<Facility>(cap);
        foreach (var bytes in _store.GetAll(AviationEntityNames.Facility).Values)
        {
            if (bytes is null || bytes.Length == 0)
            {
                // Deleted or empty payload — skip without noisy logging.
                continue;
            }

            Facility? facility;
            try
            {
                facility = _codec.Decode<Facility>(bytes);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Skipping undecodable facility payload ({Length} bytes).", bytes.Length);
                continue;
            }

            if (facility is null)
            {
                continue;
            }

            // Drop giant pads from the view model so the page stays light.
            facility.MetadataJson = null;
            results.Add(facility);
        }

        results.Sort(static (a, b) =>
            string.Compare(a.FacilityCode, b.FacilityCode, StringComparison.OrdinalIgnoreCase));

        if (results.Count > take)
        {
            results.RemoveRange(take, results.Count - take);
        }

        return results;
    }

    public async Task UpsertAsync(Facility facility, CancellationToken cancellationToken = default)
    {
        using var response = await _http.PostAsJsonAsync(
            $"{_serverBase.TrimEnd('/')}/api/facilities",
            facility,
            cancellationToken);
        response.EnsureSuccessStatusCode();
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
    /// Marks the last successful apply time. Session phase (Live vs Offline) is owned by
    /// the core sync session via <see cref="SetStatus"/> — do not infer Live here.
    /// </summary>
    public void MarkAppliedBatch()
    {
        LastUpdateUtc = DateTime.UtcNow;
        RaiseStatusChanged();
    }

    private void OnStoreEntityChanged(string entityName)
    {
        if (!string.Equals(entityName, AviationEntityNames.Facility, StringComparison.OrdinalIgnoreCase))
        {
            // Future-proof: ignore streams the facilities page does not render.
            return;
        }

        if (Volatile.Read(ref _disposed) != 0)
        {
            return;
        }

        lock (_timerLock)
        {
            if (!_pending)
            {
                _pending = true;
                _firstPendingUtc = DateTime.UtcNow;
            }

            // If we have been coalescing for too long, flush immediately so the user still
            // sees mid-burst progress instead of waiting for the whole catch-up to finish.
            var elapsed = DateTime.UtcNow - _firstPendingUtc;
            var delay = elapsed >= MaxDebounceWait ? TimeSpan.Zero : DebounceInterval;

            try
            {
                _debounceTimer.Change(delay, Timeout.InfiniteTimeSpan);
            }
            catch (ObjectDisposedException)
            {
                // Service is shutting down — drop the signal.
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
            // A subscriber (e.g. a disposed Blazor component) should never take the sync
            // pipeline down.
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

        _store.EntityChanged -= OnStoreEntityChanged;
        _debounceTimer.Dispose();
    }
}
