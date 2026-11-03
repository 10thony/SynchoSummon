using SyncEngine.Abstractions.Telemetry;

namespace SyncEngine.Server.Telemetry;

/// <summary>
/// Optional observer notified after each telemetry event is recorded.
/// Aviation apps use this for run-scoped catch-up aggregation without bloating the event ring.
/// </summary>
public interface ITelemetryListener
{
    void OnTelemetry(SyncTelemetryEvent telemetryEvent);
}
