namespace SyncEngine.Abstractions.Schema;

public interface ISchemaReader
{
    Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(CancellationToken cancellationToken = default);
}

/// <summary>Well-known schema provider ids for <c>syncengine-gen --provider</c>.</summary>
public static class SchemaProviders
{
    public const string Oracle = "oracle";
    public const string SqlServer = "sqlserver";
    public const string Postgres = "postgres";
    public const string Manifest = "manifest";
}
