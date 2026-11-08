using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client;

public sealed class InMemoryCheckpointStore : ICheckpointStore
{
    private readonly Dictionary<string, long> _versions = new(StringComparer.OrdinalIgnoreCase);
    private readonly object _gate = new();

    public Task<long> GetVersionAsync(string scope = "default", CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            return Task.FromResult(_versions.TryGetValue(scope, out var v) ? v : 0);
        }
    }

    public Task SetVersionAsync(long version, string scope = "default", CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (_versions.TryGetValue(scope, out var current) && version < current)
            {
                throw new InvalidOperationException(
                    $"Checkpoint rollback rejected for scope '{scope}': {version} < {current}.");
            }

            _versions[scope] = version;
        }

        return Task.CompletedTask;
    }
}
