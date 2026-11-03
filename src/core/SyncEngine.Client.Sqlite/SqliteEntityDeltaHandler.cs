using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;

namespace SyncEngine.Client.Sqlite;

/// <summary>
/// Generic SQLite applier: stores MemoryPack payloads keyed by entity + key bytes.
/// </summary>
public sealed class SqliteEntityDeltaHandler(string entityName, SqliteConnectionFactory connectionFactory)
    : IEntityDeltaHandler
{
    public string EntityName { get; } = entityName;

    public async Task ApplyAsync(DeltaChange change, CancellationToken cancellationToken = default)
    {
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();

        if (change.Operation == DeltaOperation.Delete)
        {
            command.CommandText =
                "DELETE FROM sync_entity WHERE entity_name = $name AND entity_key = $key";
            command.Parameters.AddWithValue("$name", EntityName);
            command.Parameters.AddWithValue("$key", change.KeyBytes);
            await command.ExecuteNonQueryAsync(cancellationToken);
            return;
        }

        command.CommandText =
            """
            INSERT INTO sync_entity(entity_name, entity_key, payload)
            VALUES ($name, $key, $payload)
            ON CONFLICT(entity_name, entity_key) DO UPDATE SET payload = excluded.payload
            """;
        command.Parameters.AddWithValue("$name", EntityName);
        command.Parameters.AddWithValue("$key", change.KeyBytes);
        command.Parameters.AddWithValue("$payload", (object?)change.PayloadBytes ?? DBNull.Value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
