namespace Aviation.Blazor.Services;

/// <summary>
/// Explicit UI refresh state machine: Idle → Running → (DirtyWhileRunning → Running)* → Idle.
/// Replaces the `_refreshing` + `_refreshRequested` boolean pair.
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
