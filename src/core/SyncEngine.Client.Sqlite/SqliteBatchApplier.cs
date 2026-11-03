using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Sqlite;

/// <summary>
/// Applies an entire delta batch inside one SQLite transaction for throughput.
/// </summary>
public sealed class SqliteBatchApplier(
    SqliteConnectionFactory connectionFactory,
    IEnumerable<IEntityDeltaHandler> handlers) : IClientDeltaApplier
{
    private readonly Dictionary<string, IEntityDeltaHandler> _handlers =
        handlers.ToDictionary(h => h.EntityName, StringComparer.OrdinalIgnoreCase);

    public async Task ApplyAsync(DeltaBatch batch, CancellationToken cancellationToken = default)
    {
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using (var ensure = connection.CreateCommand())
        {
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
        }

        await using var transaction = (Microsoft.Data.Sqlite.SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        foreach (var change in batch.Changes.OrderBy(c => c.Version))
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!_handlers.TryGetValue(change.EntityName, out var handler))
            {
                throw new InvalidOperationException($"No handler for '{change.EntityName}'.");
            }

            // Handlers open their own connections; for max throughput use direct SQL here.
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
            _ = handler; // registered handlers remain for typed specialize later
        }

        await transaction.CommitAsync(cancellationToken);
    }
}
