namespace SyncEngine.Abstractions.Schema.Manifest;

/// <summary>A single entity definition in a sync manifest file.</summary>
public sealed class ManifestEntity
{
    /// <summary>Canonical entity name used for handler routing.</summary>
    public string EntityName { get; set; } = "";

    /// <summary>Database table name backing this entity.</summary>
    public string TableName { get; set; } = "";

    /// <summary>Optional database schema (e.g. "dbo").</summary>
    public string? SchemaName { get; set; }

    /// <summary>Column names forming the composite primary key.</summary>
    public List<string>? KeyColumns { get; set; }

    /// <summary>Property definitions for this entity.</summary>
    public List<ManifestProperty>? Properties { get; set; }

    /// <summary>Whether this entity participates in sync.</summary>
    public bool Syncable { get; set; } = true;

    /// <summary>Topological order for FK-safe apply (lower first).</summary>
    public int DependencyOrder { get; set; }

    /// <summary>Referenced table names (FK targets), if known.</summary>
    public List<string>? ReferencedTables { get; set; }
}

/// <summary>A single property definition within a manifest entity.</summary>
public sealed class ManifestProperty
{
    /// <summary>C#/generated property name.</summary>
    public string PropertyName { get; set; } = "";

    /// <summary>Database column name.</summary>
    public string ColumnName { get; set; } = "";

    /// <summary>Optional CLR type name hint (e.g. "System.Int32").</summary>
    public string? Type { get; set; }

    /// <summary>True if this property is part of the entity key.</summary>
    public bool IsKey { get; set; }

    /// <summary>True if this property is included in the sync payload.</summary>
    public bool IsPayload { get; set; } = true;

    /// <summary>True if the property permits null values.</summary>
    public bool IsNullable { get; set; }
}
