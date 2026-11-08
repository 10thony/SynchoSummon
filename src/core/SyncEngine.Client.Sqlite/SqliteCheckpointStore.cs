using Microsoft.Data.Sqlite;
using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client.Sqlite;

public sealed class SqliteCheckpointStore(SqliteConnectionFactory connectionFactory) : ICheckpointStore
{
    private int _initialized;

    public async Task<long> GetVersionAsync(string scope = "default", CancellationToken cancellationToken = default)
    {
        await EnsureSchemaAsync(cancellationToken);
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT version FROM sync_checkpoint WHERE scope = $scope";
        command.Parameters.AddWithValue("$scope", scope);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is long l ? l : result is int i ? i : 0L;
    }

    public async Task SetVersionAsync(long version, string scope = "default", CancellationToken cancellationToken = default)
    {
        await EnsureSchemaAsync(cancellationToken);
        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText =
            """
            INSERT INTO sync_checkpoint(scope, version, updated_at_utc)
            VALUES ($scope, $version, $updated)
            ON CONFLICT(scope) DO UPDATE SET
                version = excluded.version,
                updated_at_utc = excluded.updated_at_utc
            WHERE excluded.version >= sync_checkpoint.version
            """;
        command.Parameters.AddWithValue("$scope", scope);
        command.Parameters.AddWithValue("$version", version);
        command.Parameters.AddWithValue("$updated", DateTimeOffset.UtcNow.ToString("O"));
        var affected = await command.ExecuteNonQueryAsync(cancellationToken);

        await using var read = connection.CreateCommand();
        read.Transaction = transaction;
        read.CommandText = "SELECT version FROM sync_checkpoint WHERE scope = $scope";
        read.Parameters.AddWithValue("$scope", scope);
        var storedObj = await read.ExecuteScalarAsync(cancellationToken);
        var stored = storedObj is long l ? l : storedObj is int i ? i : 0L;

        if (version < stored && affected == 0)
        {
            throw new InvalidOperationException(
                $"Checkpoint rollback rejected for scope '{scope}': {version} < {stored}.");
        }

        await transaction.CommitAsync(cancellationToken);
    }

    private async Task EnsureSchemaAsync(CancellationToken cancellationToken)
    {
        if (Interlocked.Exchange(ref _initialized, 1) == 1)
        {
            return;
        }

        await using var connection = await connectionFactory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            CREATE TABLE IF NOT EXISTS sync_checkpoint (
                scope TEXT PRIMARY KEY NOT NULL,
                version INTEGER NOT NULL,
                updated_at_utc TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sync_entity (
                entity_name TEXT NOT NULL,
                entity_key BLOB NOT NULL,
                payload BLOB,
                PRIMARY KEY (entity_name, entity_key)
            );
            CREATE TABLE IF NOT EXISTS sync_outbox (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_name TEXT NOT NULL,
                operation INTEGER NOT NULL,
                entity_key BLOB NOT NULL,
                payload BLOB,
                created_at_utc TEXT NOT NULL
            );
            """;
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
