using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Offline;

namespace SyncEngine.Client.Sqlite;

public sealed class SqliteOutboxStore(SqliteConnectionFactory connectionFactory)
{
    public async Task EnqueueAsync(DeltaChange change, CancellationToken cancellationToken = default)
    {
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO sync_outbox(entity_name, operation, entity_key, payload, created_at_utc)
            VALUES ($name, $op, $key, $payload, $created)
            """;
        command.Parameters.AddWithValue("$name", change.EntityName);
        command.Parameters.AddWithValue("$op", (int)change.Operation);
        command.Parameters.AddWithValue("$key", change.KeyBytes);
        command.Parameters.AddWithValue("$payload", (object?)change.PayloadBytes ?? DBNull.Value);
        command.Parameters.AddWithValue("$created", DateTimeOffset.UtcNow.ToString("O"));
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<DeltaChange>> DequeueBatchAsync(int limit, CancellationToken cancellationToken = default)
    {
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT id, entity_name, operation, entity_key, payload
            FROM sync_outbox
            ORDER BY id
            LIMIT $limit
            """;
        command.Parameters.AddWithValue("$limit", limit);

        var results = new List<(long Id, DeltaChange Change)>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = reader.GetInt64(0);
            results.Add((id, new DeltaChange
            {
                Version = id,
                EntityName = reader.GetString(1),
                Operation = (DeltaOperation)reader.GetInt32(2),
                KeyBytes = (byte[])reader[3],
                PayloadBytes = reader.IsDBNull(4) ? null : (byte[])reader[4],
            }));
        }

        return results.Select(r => r.Change).ToArray();
    }

    public async Task ClearThroughAsync(long maxId, CancellationToken cancellationToken = default)
    {
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "DELETE FROM sync_outbox WHERE id <= $id";
        command.Parameters.AddWithValue("$id", maxId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public void MirrorToMemoryOutbox(ClientOutbox outbox, DeltaChange change)
    {
        if (change.Operation == DeltaOperation.Delete)
        {
            outbox.EnqueueDelete(change.EntityName, change.KeyBytes);
        }
        else
        {
            outbox.EnqueueUpsert(change.EntityName, change.KeyBytes, change.PayloadBytes ?? Array.Empty<byte>());
        }
    }
}
