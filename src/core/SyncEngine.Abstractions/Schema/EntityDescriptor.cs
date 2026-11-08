namespace SyncEngine.Abstractions.Schema;

/// <summary>
/// Intermediate representation for deterministic schema → sync code generation.
/// Provider readers populate this; emitters never talk to the database directly.
/// </summary>
public sealed class EntityDescriptor
{
    public required string EntityName { get; init; }

    public required string TableName { get; init; }

    public string? SchemaName { get; init; }

    public required IReadOnlyList<string> KeyColumns { get; init; }

    public required IReadOnlyList<SyncPropertyDescriptor> Properties { get; init; }

    public bool Syncable { get; init; } = true;

    /// <summary>Topological order for FK-safe apply (lower first).</summary>
    public int DependencyOrder { get; init; }

    /// <summary>Referenced table names (FK targets), if known.</summary>
    public IReadOnlyList<string> ReferencedTables { get; init; } = Array.Empty<string>();
}

public sealed class SyncPropertyDescriptor
{
    public required string PropertyName { get; init; }

    public required string ColumnName { get; init; }

    public required Type ClrType { get; init; }

    public bool IsKey { get; init; }

    public bool IsPayload { get; init; } = true;

    public bool IsNullable { get; init; }
}

/// <summary>Optional filters applied after a provider schema read.</summary>
public sealed class SchemaReadOptions
{
    public IReadOnlyList<string>? IncludeTables { get; init; }

    public IReadOnlyList<string>? ExcludeTables { get; init; }

    public string? Schema { get; init; }
}

public static class SchemaFilter
{
    public static IReadOnlyList<EntityDescriptor> Apply(
        IReadOnlyList<EntityDescriptor> entities,
        SchemaReadOptions? options)
    {
        if (options is null)
        {
            return OrderByDependencies(entities);
        }

        IEnumerable<EntityDescriptor> query = entities;
        if (options.IncludeTables is { Count: > 0 } include)
        {
            var set = include.ToHashSet(StringComparer.OrdinalIgnoreCase);
            query = query.Where(e => set.Contains(e.TableName) || set.Contains(e.EntityName));
        }

        if (options.ExcludeTables is { Count: > 0 } exclude)
        {
            var set = exclude.ToHashSet(StringComparer.OrdinalIgnoreCase);
            query = query.Where(e => !set.Contains(e.TableName) && !set.Contains(e.EntityName));
        }

        return OrderByDependencies(query.ToList());
    }

    public static IReadOnlyList<EntityDescriptor> OrderByDependencies(IReadOnlyList<EntityDescriptor> entities)
    {
        var byTable = entities.ToDictionary(e => e.TableName, StringComparer.OrdinalIgnoreCase);
        var visiting = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var ordered = new List<EntityDescriptor>();

        void Visit(EntityDescriptor entity)
        {
            if (!visited.Add(entity.TableName))
            {
                return;
            }

            if (!visiting.Add(entity.TableName))
            {
                return; // cycle — keep stable order
            }

            foreach (var referenced in entity.ReferencedTables)
            {
                if (byTable.TryGetValue(referenced, out var dep))
                {
                    Visit(dep);
                }
            }

            visiting.Remove(entity.TableName);
            ordered.Add(entity);
        }

        foreach (var entity in entities.OrderBy(e => e.TableName, StringComparer.OrdinalIgnoreCase))
        {
            Visit(entity);
        }

        return ordered
            .Select((e, i) => new EntityDescriptor
            {
                EntityName = e.EntityName,
                TableName = e.TableName,
                SchemaName = e.SchemaName,
                KeyColumns = e.KeyColumns,
                Properties = e.Properties,
                Syncable = e.Syncable,
                DependencyOrder = i,
                ReferencedTables = e.ReferencedTables,
            })
            .ToArray();
    }
}
