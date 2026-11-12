using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;

namespace SyncEngine.Client.Sqlite;

/// <summary>
/// Applies an entire delta batch inside one SQLite transaction for throughput.
/// </summary>
public sealed class SqliteBatchApplier : IClientDeltaApplier, ISyncBatchNotifier
{
    private readonly SqliteConnectionFactory _connectionFactory;
    private readonly Dictionary<string, IEntityDeltaHandler> _handlers;
    private readonly UnknownEntityBehavior _unknownEntityBehavior;
    private readonly ILogger<SqliteBatchApplier> _logger;
    private readonly HashSet<string> _warnedEntities = new(StringComparer.OrdinalIgnoreCase);
    private int _schemaReady;

    /// <inheritdoc />
    public event Action<DeltaBatch>? BatchApplied;

    public SqliteBatchApplier(
        SqliteConnectionFactory connectionFactory,
        IEnumerable<IEntityDeltaHandler> handlers,
        UnknownEntityBehavior unknownEntityBehavior = UnknownEntityBehavior.SkipAndWarn,
        ILogger<SqliteBatchApplier>? logger = null)
    {
        _connectionFactory = connectionFactory;
        _handlers = handlers.ToDictionary(h => h.EntityName, StringComparer.OrdinalIgnoreCase);
        _unknownEntityBehavior = unknownEntityBehavior;
        _logger = logger ?? NullLogger<SqliteBatchApplier>.Instance;
    }

    public async Task ApplyAsync(DeltaBatch batch, CancellationToken cancellationToken = default)
    {
        await using var connection = await _connectionFactory.OpenAsync(cancellationToken);
        await EnsureEntitySchemaAsync(connection, cancellationToken);

        await using var transaction = (Microsoft.Data.Sqlite.SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!_handlers.TryGetValue(change.EntityName, out _))
            {
                if (_unknownEntityBehavior == UnknownEntityBehavior.Throw)
                {
                    throw new InvalidOperationException($"No handler for '{change.EntityName}'.");
                }

                if (_warnedEntities.Add(change.EntityName))
                {
                    _logger.LogWarning(
                        "SyncEngine: No SQLite handler for entity '{EntityName}'. Skipping.",
                        change.EntityName);
                }

                continue;
            }

            await using var command = connection.CreateCommand();
            command.Transaction = transaction;

            if (change.Operation == DeltaOperation.Delete)
            {
                command.CommandText =
                    "DELETE FROM sync_entity WHERE entity_name = $name AND entity_key = $key";
                command.Parameters.AddWithValue("$name", change.EntityName);
                command.Parameters.AddWithValue("$key", change.KeyBytes);
            }
            else
            {
                command.CommandText =
                    """
                    INSERT INTO sync_entity(entity_name, entity_key, payload)
                    VALUES ($name, $key, $payload)
                    ON CONFLICT(entity_name, entity_key) DO UPDATE SET payload = excluded.payload
                    """;
                command.Parameters.AddWithValue("$name", change.EntityName);
                command.Parameters.AddWithValue("$key", change.KeyBytes);
                command.Parameters.AddWithValue("$payload", (object?)change.PayloadBytes ?? DBNull.Value);
            }

            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        BatchApplied?.Invoke(batch);
    }

    private async Task EnsureEntitySchemaAsync(
        Microsoft.Data.Sqlite.SqliteConnection connection,
        CancellationToken cancellationToken)
    {
        if (Volatile.Read(ref _schemaReady) == 1)
        {
            return;
        }

        await using var ensure = connection.CreateCommand();
        ensure.CommandText =
            """
            CREATE TABLE IF NOT EXISTS sync_entity (
                entity_name TEXT NOT NULL,
                entity_key BLOB NOT NULL,
                payload BLOB,
                PRIMARY KEY (entity_name, entity_key)
            );
            """;
        await ensure.ExecuteNonQueryAsync(cancellationToken);
        Volatile.Write(ref _schemaReady, 1);
    }
}
