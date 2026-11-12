namespace SyncEngine.Client.Offline;

/// <summary>Configuration for automatic outbox flushing.</summary>
public sealed class OutboxFlushOptions
{
    /// <summary>Interval between automatic flush attempts.</summary>
    public TimeSpan FlushInterval { get; set; } = TimeSpan.FromSeconds(5);

    /// <summary>Maximum changes per push request.</summary>
    public int MaxChangesPerPush { get; set; } = 1000;
}
