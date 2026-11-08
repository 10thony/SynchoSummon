using Microsoft.Data.SqlClient;
using SyncEngine.Abstractions.Schema;

namespace SyncEngine.Generator.Readers;

public sealed class SqlServerSchemaReader(string connectionString, string schema = "dbo") : ISchemaReader
{
    public async Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var tables = new List<string>();
        await using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText =
                """
                SELECT TABLE_NAME
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = @schema
                  AND TABLE_TYPE = 'BASE TABLE'
                  AND TABLE_NAME <> 'sync_change'
                ORDER BY TABLE_NAME
                """;
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                tables.Add(reader.GetString(0));
            }
        }

        var entities = new List<EntityDescriptor>();
        foreach (var table in tables)
        {
            var columns = new List<(string Name, string Type, bool Nullable)>();
            await using (var cmd = connection.CreateCommand())
            {
                cmd.CommandText =
                    """
                    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table
                    ORDER BY ORDINAL_POSITION
                    """;
                cmd.Parameters.AddWithValue("@schema", schema);
                cmd.Parameters.AddWithValue("@table", table);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    columns.Add((
                        reader.GetString(0),
                        reader.GetString(1),
                        string.Equals(reader.GetString(2), "YES", StringComparison.OrdinalIgnoreCase)));
                }
            }

            var keys = new List<string>();
            await using (var cmd = connection.CreateCommand())
            {
                cmd.CommandText =
                    """
                    SELECT kcu.COLUMN_NAME
                    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
                    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                      ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
                     AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                    WHERE tc.TABLE_SCHEMA = @schema
                      AND tc.TABLE_NAME = @table
                      AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
                    ORDER BY kcu.ORDINAL_POSITION
                    """;
                cmd.Parameters.AddWithValue("@schema", schema);
                cmd.Parameters.AddWithValue("@table", table);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    keys.Add(reader.GetString(0));
                }
            }

            var refs = new List<string>();
            await using (var cmd = connection.CreateCommand())
            {
                cmd.CommandText =
                    """
                    SELECT DISTINCT OBJECT_NAME(fk.referenced_object_id)
                    FROM sys.foreign_keys fk
                    JOIN sys.tables t ON fk.parent_object_id = t.object_id
                    JOIN sys.schemas s ON t.schema_id = s.schema_id
                    WHERE s.name = @schema AND t.name = @table
                    """;
                cmd.Parameters.AddWithValue("@schema", schema);
                cmd.Parameters.AddWithValue("@table", table);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    if (!reader.IsDBNull(0))
                    {
                        refs.Add(reader.GetString(0));
                    }
                }
            }

            var keySet = keys.ToHashSet(StringComparer.OrdinalIgnoreCase);
            entities.Add(new EntityDescriptor
            {
                EntityName = ToPascal(table),
                TableName = table,
                SchemaName = schema,
                KeyColumns = keys,
                Properties = columns.Select(c => new SyncPropertyDescriptor
                {
                    PropertyName = ToPascal(c.Name),
                    ColumnName = c.Name,
                    ClrType = MapType(c.Type),
                    IsKey = keySet.Contains(c.Name),
                    IsPayload = true,
                    IsNullable = c.Nullable,
                }).ToArray(),
                Syncable = true,
                ReferencedTables = refs,
            });
        }

        return SchemaFilter.OrderByDependencies(entities);
    }

    private static Type MapType(string sqlType) => sqlType.ToLowerInvariant() switch
    {
        "int" or "smallint" or "tinyint" => typeof(int),
        "bigint" => typeof(long),
        "bit" => typeof(bool),
        "decimal" or "numeric" or "money" or "smallmoney" => typeof(decimal),
        "float" => typeof(double),
        "real" => typeof(float),
        "uniqueidentifier" => typeof(Guid),
        "date" or "datetime" or "datetime2" or "smalldatetime" or "datetimeoffset" => typeof(DateTimeOffset),
        "varbinary" or "binary" or "image" => typeof(byte[]),
        _ => typeof(string),
    };

    private static string ToPascal(string name)
    {
        var parts = name.Split(['_', ' '], StringSplitOptions.RemoveEmptyEntries);
        return string.Concat(parts.Select(static p =>
            char.ToUpperInvariant(p[0]) + p[1..].ToLowerInvariant()));
    }
}
