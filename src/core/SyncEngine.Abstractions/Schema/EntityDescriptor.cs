namespace SyncEngine.Abstractions.Schema;

public sealed class EntityDescriptor
{
    public required string EntityName { get; init; }

    public required string TableName { get; init; }

    public required IReadOnlyList<string> KeyColumns { get; init; }

    public required IReadOnlyList<SyncPropertyDescriptor> Properties { get; init; }

    public bool Syncable { get; init; } = true;

    public int DependencyOrder { get; init; }
}

public sealed class SyncPropertyDescriptor
{
    public required string PropertyName { get; init; }

    public required string ColumnName { get; init; }

    public required Type ClrType { get; init; }

    public bool IsKey { get; init; }

    public bool IsPayload { get; init; } = true;
}
