using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Sqlite;
using Xunit;

namespace SyncEngine.Tests;

public sealed class SqliteApplyTests
{
    [Fact]
    public async Task AppliesBatch_IntoSqlite_AndAdvancesCheckpoint()
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"sync-test-{Guid.NewGuid():N}.db");
        var options = Options.Create(new SqliteSyncOptions { ConnectionString = $"Data Source={dbPath}" });
        var factory = new SqliteConnectionFactory(options);
        var checkpoint = new SqliteCheckpointStore(factory);
        var applier = new SqliteBatchApplier(factory, [new SqliteEntityDeltaHandler("Facility", factory)]);

        // Force schema
        await checkpoint.SetVersionAsync(0);

        var batch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = 2,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = "Facility",
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = [1, 2, 3],
                    PayloadBytes = [9, 9, 9],
                },
                new DeltaChange
                {
                    Version = 2,
                    EntityName = "Facility",
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = [4, 5, 6],
                    PayloadBytes = [8, 8, 8],
                },
            ],
        };

        await applier.ApplyAsync(batch);
        await checkpoint.SetVersionAsync(batch.ToVersion);

        Assert.Equal(2, await checkpoint.GetVersionAsync());

        await using var connection = await factory.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM sync_entity WHERE entity_name = 'Facility'";
        var count = Convert.ToInt64(await command.ExecuteScalarAsync());
        Assert.Equal(2, count);

        try { File.Delete(dbPath); } catch { /* ignore */ }
    }
}
