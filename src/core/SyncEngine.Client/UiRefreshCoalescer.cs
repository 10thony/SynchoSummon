namespace SyncEngine.Client;

/// <summary>
/// Framework-agnostic UI refresh coalescer: Idle → Running → (DirtyWhileRunning → Running)* → Idle.
/// Collapses bursts of invalidation signals into a single refresh pass.
/// Moved from Aviation.Blazor into Client so every adopter gets the primitive.
/// </summary>
public sealed class UiRefreshCoalescer
{
    public enum Phase
    {
        Idle = 0,
        Running = 1,
        DirtyWhileRunning = 2,
    }

    private Phase _phase = Phase.Idle;

    public Phase Current => _phase;

    /// <summary>
    /// Returns true when the caller should start work. If already running, marks dirty and returns false.
    /// </summary>
    public bool TryBegin()
    {
        if (_phase is Phase.Running or Phase.DirtyWhileRunning)
        {
            _phase = Phase.DirtyWhileRunning;
            return false;
        }

        _phase = Phase.Running;
        return true;
    }

    /// <summary>
    /// Clears the dirty bit for a loop iteration. Returns true when another pass is needed.
    /// </summary>
    public bool ConsumeDirty()
    {
        if (_phase != Phase.DirtyWhileRunning)
        {
            return false;
        }

        _phase = Phase.Running;
        return true;
    }

    public void End() => _phase = Phase.Idle;
}
