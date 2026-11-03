using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Options;

namespace SyncEngine.Client.Sqlite;

public sealed class SqliteConnectionFactory(IOptions<SqliteSyncOptions> options)
{
    public async Task<SqliteConnection> OpenAsync(CancellationToken cancellationToken = default)
    {
        var connection = new SqliteConnection(options.Value.ConnectionString);
        await connection.OpenAsync(cancellationToken);
        await using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText =
                """
                PRAGMA journal_mode=WAL;
                PRAGMA synchronous=NORMAL;
                PRAGMA temp_store=MEMORY;
                PRAGMA mmap_size=268435456;
                """;
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }

        return connection;
    }
}
