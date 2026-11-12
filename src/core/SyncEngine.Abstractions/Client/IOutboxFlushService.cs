namespace SyncEngine.Abstractions.Client;

/// <summary>
/// Abstraction for outbox flush lifecycle. Hosts bind UI to
/// <see cref="Phase"/> / <see cref="PhaseChanged"/> instead of reaching into concrete ClientOutbox.
/// </summary>
public interface IOutboxFlushService
{
    /// <summary>Current flush phase.</summary>
    SyncOutboxPhase Phase { get; }

    /// <summary>Number of pending outbox entries.</summary>
    int PendingCount { get; }

    /// <summary>Raised when the outbox flush phase changes.</summary>
    event Action<SyncOutboxPhase>? PhaseChanged;

    /// <summary>Flush pending outbox entries to the server. Returns count flushed.</summary>
    Task<int> FlushAsync(CancellationToken cancellationToken = default);
}
