using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions.Telemetry;
using SyncEngine.Server.Hubs;

namespace SyncEngine.Server.Telemetry;

public interface ISyncTelemetry
{
    void Record(SyncTelemetryEvent telemetryEvent);

    IReadOnlyList<SyncTelemetryEvent> GetRecent(int take = 200);

    SyncTelemetryStats GetStats();
}

public sealed class SyncTelemetryStats
{
    public long TotalEvents { get; init; }

    public long TotalBytesOut { get; init; }

    public long TotalBytesIn { get; init; }

    public long WriteCount { get; init; }

    public long WakeCount { get; init; }

    public long DeltaPullCount { get; init; }

    public long ClientApplyCount { get; init; }

    public double? AvgDeltaLatencyMs { get; init; }

    public double? AvgApplyLatencyMs { get; init; }

    public double? AvgWakeToApplyMs { get; init; }
}

public sealed class SyncTelemetryStore(
    IHubContext<TelemetryHub> hubContext,
    IServiceProvider services) : ISyncTelemetry
{
    private const int Capacity = 5000;
    private readonly ConcurrentQueue<SyncTelemetryEvent> _events = new();
    private ITelemetryListener[]? _listeners;
    private long _totalEvents;
    private long _bytesOut;
    private long _bytesIn;
    private long _writes;
    private long _wakes;
    private long _pulls;
    private long _applies;
    private double _deltaLatencySum;
    private long _deltaLatencyCount;
    private double _applyLatencySum;
    private long _applyLatencyCount;

    public void Record(SyncTelemetryEvent telemetryEvent)
    {
        ArgumentNullException.ThrowIfNull(telemetryEvent);
        _events.Enqueue(telemetryEvent);
        while (_events.Count > Capacity && _events.TryDequeue(out _))
        {
        }

        Interlocked.Increment(ref _totalEvents);
        switch (telemetryEvent.Kind)
        {
            case SyncTelemetryKind.Write:
                Interlocked.Increment(ref _writes);
                if (telemetryEvent.Bytes is > 0)
                {
                    Interlocked.Add(ref _bytesIn, telemetryEvent.Bytes.Value);
                }

                break;
            case SyncTelemetryKind.Wake:
                Interlocked.Increment(ref _wakes);
                break;
            case SyncTelemetryKind.DeltaPull:
                Interlocked.Increment(ref _pulls);
                if (telemetryEvent.Bytes is > 0)
                {
                    Interlocked.Add(ref _bytesOut, telemetryEvent.Bytes.Value);
                }

                if (telemetryEvent.LatencyMs is { } deltaMs)
                {
                    lock (this)
                    {
                        _deltaLatencySum += deltaMs;
                        _deltaLatencyCount++;
                    }
                }

                break;
            case SyncTelemetryKind.OfflinePush:
                if (telemetryEvent.Bytes is > 0)
                {
                    Interlocked.Add(ref _bytesIn, telemetryEvent.Bytes.Value);
                }

                break;
            case SyncTelemetryKind.ClientApply:
                Interlocked.Increment(ref _applies);
                if (telemetryEvent.LatencyMs is { } applyMs)
                {
                    lock (this)
                    {
                        _applyLatencySum += applyMs;
                        _applyLatencyCount++;
                    }
                }

                break;
        }

        // Resolve lazily so listeners (e.g. LoadRunService) can depend on ISyncTelemetry.
        _listeners ??= services.GetServices<ITelemetryListener>().ToArray();
        foreach (var listener in _listeners)
        {
            try
            {
                listener.OnTelemetry(telemetryEvent);
            }
            catch
            {
                // Listeners must not break telemetry recording.
            }
        }

        _ = hubContext.Clients.Group(TelemetryHub.ViewersGroup)
            .SendAsync("TelemetryEvent", telemetryEvent);
    }

    public IReadOnlyList<SyncTelemetryEvent> GetRecent(int take = 200)
    {
        take = Math.Clamp(take, 1, Capacity);
        return _events.Reverse().Take(take).ToArray();
    }

    public SyncTelemetryStats GetStats()
    {
        lock (this)
        {
            return new SyncTelemetryStats
            {
                TotalEvents = Interlocked.Read(ref _totalEvents),
                TotalBytesOut = Interlocked.Read(ref _bytesOut),
                TotalBytesIn = Interlocked.Read(ref _bytesIn),
                WriteCount = Interlocked.Read(ref _writes),
                WakeCount = Interlocked.Read(ref _wakes),
                DeltaPullCount = Interlocked.Read(ref _pulls),
                ClientApplyCount = Interlocked.Read(ref _applies),
                AvgDeltaLatencyMs = _deltaLatencyCount == 0 ? null : _deltaLatencySum / _deltaLatencyCount,
                AvgApplyLatencyMs = _applyLatencyCount == 0 ? null : _applyLatencySum / _applyLatencyCount,
            };
        }
    }
}
