namespace SyncEngine.Client.Sqlite;

public sealed class SqliteSyncOptions
{
    public const string SectionName = "SyncEngine:Sqlite";

    public string ConnectionString { get; set; } = "Data Source=syncengine.db";
}
