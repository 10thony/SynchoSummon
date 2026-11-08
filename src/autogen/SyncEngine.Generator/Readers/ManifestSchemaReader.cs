using System.Text.Json;
using SyncEngine.Abstractions.Schema;

namespace SyncEngine.Generator.Readers;

/// <summary>
/// Reads a previously emitted (or hand-authored) manifest.json as the generator IR.
/// Useful for offline regeneration and tests without a live database.
/// </summary>
public sealed class ManifestSchemaReader(string manifestPath) : ISchemaReader
{
    private static readonly Dictionary<string, Type> TypeMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["String"] = typeof(string),
        ["string"] = typeof(string),
        ["Int32"] = typeof(int),
        ["int"] = typeof(int),
        ["Int64"] = typeof(long),
        ["long"] = typeof(long),
        ["Boolean"] = typeof(bool),
        ["bool"] = typeof(bool),
        ["Decimal"] = typeof(decimal),
        ["decimal"] = typeof(decimal),
        ["Double"] = typeof(double),
        ["double"] = typeof(double),
        ["Single"] = typeof(float),
        ["float"] = typeof(float),
        ["Guid"] = typeof(Guid),
        ["DateTimeOffset"] = typeof(DateTimeOffset),
        ["Byte[]"] = typeof(byte[]),
        ["byte[]"] = typeof(byte[]),
    };

    public async Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(
        CancellationToken cancellationToken = default)
    {
        await using var stream = File.OpenRead(manifestPath);
        var docs = await JsonSerializer.DeserializeAsync<List<ManifestEntity>>(
            stream,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true },
            cancellationToken) ?? [];

        var entities = docs.Select(d => new EntityDescriptor
        {
            EntityName = d.EntityName,
            TableName = d.TableName,
            SchemaName = d.SchemaName,
            KeyColumns = d.KeyColumns ?? [],
            Properties = (d.Properties ?? []).Select(p => new SyncPropertyDescriptor
            {
                PropertyName = p.PropertyName,
                ColumnName = p.ColumnName,
                ClrType = TypeMap.TryGetValue(p.Type ?? "string", out var t) ? t : typeof(string),
                IsKey = p.IsKey,
                IsPayload = p.IsPayload,
                IsNullable = p.IsNullable,
            }).ToArray(),
            Syncable = d.Syncable,
            DependencyOrder = d.DependencyOrder,
            ReferencedTables = d.ReferencedTables ?? [],
        }).ToList();

        return SchemaFilter.OrderByDependencies(entities);
    }

    private sealed class ManifestEntity
    {
        public string EntityName { get; set; } = "";
        public string TableName { get; set; } = "";
        public string? SchemaName { get; set; }
        public List<string>? KeyColumns { get; set; }
        public List<ManifestProperty>? Properties { get; set; }
        public bool Syncable { get; set; } = true;
        public int DependencyOrder { get; set; }
        public List<string>? ReferencedTables { get; set; }
    }

    private sealed class ManifestProperty
    {
        public string PropertyName { get; set; } = "";
        public string ColumnName { get; set; } = "";
        public string? Type { get; set; }
        public bool IsKey { get; set; }
        public bool IsPayload { get; set; } = true;
        public bool IsNullable { get; set; }
    }
}
