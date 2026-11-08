using Microsoft.Extensions.Options;
using SyncEngine.Abstractions.Schema;
using SyncEngine.Abstractions.Store;

namespace SyncEngine.Providers.Oracle;

/// <summary>
/// Oracle schema reader — populates the SyncEngine generator IR.
/// </summary>
public sealed class OracleSchemaReader(IOrgStore store, IOptions<OracleOptions> options) : ISchemaReader
{
    public async Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(
        CancellationToken cancellationToken = default)
    {
        var schema = options.Value.Schema.ToUpperInvariant();
        var tables = await store.QueryAsync<TableRow>(
            """
            SELECT table_name AS TableName
            FROM all_tables
            WHERE owner = :owner
              AND table_name NOT LIKE 'BIN$%'
              AND table_name <> 'SYNC_CHANGE'
            ORDER BY table_name
            """,
            new Dictionary<string, object?> { ["owner"] = schema },
            cancellationToken);

        var entities = new List<EntityDescriptor>();
        foreach (var table in tables)
        {
            var columns = await store.QueryAsync<ColumnRow>(
                """
                SELECT column_name AS ColumnName, data_type AS DataType, nullable AS Nullable
                FROM all_tab_columns
                WHERE owner = :owner AND table_name = :tableName
                ORDER BY column_id
                """,
                new Dictionary<string, object?>
                {
                    ["owner"] = schema,
                    ["tableName"] = table.TableName,
                },
                cancellationToken);

            var keys = await store.QueryAsync<ColumnRow>(
                """
                SELECT acc.column_name AS ColumnName, 'KEY' AS DataType, 'N' AS Nullable
                FROM all_constraints ac
                JOIN all_cons_columns acc
                  ON ac.owner = acc.owner
                 AND ac.constraint_name = acc.constraint_name
                WHERE ac.owner = :owner
                  AND ac.table_name = :tableName
                  AND ac.constraint_type = 'P'
                ORDER BY acc.position
                """,
                new Dictionary<string, object?>
                {
                    ["owner"] = schema,
                    ["tableName"] = table.TableName,
                },
                cancellationToken);

            var fks = await store.QueryAsync<FkRow>(
                """
                SELECT DISTINCT c_pk.table_name AS ReferencedTable
                FROM all_constraints c
                JOIN all_constraints c_pk
                  ON c.r_owner = c_pk.owner
                 AND c.r_constraint_name = c_pk.constraint_name
                WHERE c.owner = :owner
                  AND c.table_name = :tableName
                  AND c.constraint_type = 'R'
                """,
                new Dictionary<string, object?>
                {
                    ["owner"] = schema,
                    ["tableName"] = table.TableName,
                },
                cancellationToken);

            var keySet = keys.Select(k => k.ColumnName).ToHashSet(StringComparer.OrdinalIgnoreCase);
            entities.Add(new EntityDescriptor
            {
                EntityName = ToPascal(table.TableName),
                TableName = table.TableName,
                SchemaName = schema,
                KeyColumns = keys.Select(k => k.ColumnName).ToArray(),
                Properties = columns.Select(c => new SyncPropertyDescriptor
                {
                    PropertyName = ToPascal(c.ColumnName),
                    ColumnName = c.ColumnName,
                    ClrType = MapType(c.DataType),
                    IsKey = keySet.Contains(c.ColumnName),
                    IsPayload = true,
                    IsNullable = string.Equals(c.Nullable, "Y", StringComparison.OrdinalIgnoreCase),
                }).ToArray(),
                Syncable = true,
                ReferencedTables = fks.Select(f => f.ReferencedTable).ToArray(),
            });
        }

        return SchemaFilter.OrderByDependencies(entities);
    }

    private static Type MapType(string oracleType) => oracleType.ToUpperInvariant() switch
    {
        "NUMBER" => typeof(decimal),
        "FLOAT" => typeof(double),
        "BINARY_FLOAT" => typeof(float),
        "BINARY_DOUBLE" => typeof(double),
        "DATE" or "TIMESTAMP" or "TIMESTAMP(6)" => typeof(DateTimeOffset),
        "BLOB" or "RAW" => typeof(byte[]),
        _ => typeof(string),
    };

    private static string ToPascal(string name)
    {
        var parts = name.Split('_', StringSplitOptions.RemoveEmptyEntries);
        return string.Concat(parts.Select(static p =>
            char.ToUpperInvariant(p[0]) + p[1..].ToLowerInvariant()));
    }

    private sealed class TableRow
    {
        public string TableName { get; set; } = string.Empty;
    }

    private sealed class ColumnRow
    {
        public string ColumnName { get; set; } = string.Empty;

        public string DataType { get; set; } = string.Empty;

        public string Nullable { get; set; } = "Y";
    }

    private sealed class FkRow
    {
        public string ReferencedTable { get; set; } = string.Empty;
    }
}
