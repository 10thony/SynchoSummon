using Npgsql;
using SyncEngine.Abstractions.Schema;

namespace SyncEngine.Generator.Readers;

public sealed class PostgresSchemaReader(string connectionString, string schema = "public") : ISchemaReader
{
    public async Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(
        CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var tables = new List<string>();
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = @schema
              AND table_type = 'BASE TABLE'
              AND table_name <> 'sync_change'
            ORDER BY table_name
            """,
            connection))
        {
            cmd.Parameters.AddWithValue("schema", schema);
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
            await using (var cmd = new NpgsqlCommand(
                """
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_schema = @schema AND table_name = @table
                ORDER BY ordinal_position
                """,
                connection))
            {
                cmd.Parameters.AddWithValue("schema", schema);
                cmd.Parameters.AddWithValue("table", table);
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
            await using (var cmd = new NpgsqlCommand(
                """
                SELECT kcu.column_name
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = @schema
                  AND tc.table_name = @table
                  AND tc.constraint_type = 'PRIMARY KEY'
                ORDER BY kcu.ordinal_position
                """,
                connection))
            {
                cmd.Parameters.AddWithValue("schema", schema);
                cmd.Parameters.AddWithValue("table", table);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    keys.Add(reader.GetString(0));
                }
            }

            var refs = new List<string>();
            await using (var cmd = new NpgsqlCommand(
                """
                SELECT DISTINCT ccu.table_name AS referenced_table
                FROM information_schema.table_constraints tc
                JOIN information_schema.constraint_column_usage ccu
                  ON tc.constraint_name = ccu.constraint_name
                 AND tc.table_schema = ccu.table_schema
                WHERE tc.table_schema = @schema
                  AND tc.table_name = @table
                  AND tc.constraint_type = 'FOREIGN KEY'
                """,
                connection))
            {
                cmd.Parameters.AddWithValue("schema", schema);
                cmd.Parameters.AddWithValue("table", table);
                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    refs.Add(reader.GetString(0));
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

    private static Type MapType(string pgType) => pgType.ToLowerInvariant() switch
    {
        "integer" or "smallint" => typeof(int),
        "bigint" => typeof(long),
        "boolean" => typeof(bool),
        "numeric" or "decimal" or "money" => typeof(decimal),
        "double precision" => typeof(double),
        "real" => typeof(float),
        "uuid" => typeof(Guid),
        "date" or "timestamp without time zone" or "timestamp with time zone" => typeof(DateTimeOffset),
        "bytea" => typeof(byte[]),
        _ => typeof(string),
    };

    private static string ToPascal(string name)
    {
        var parts = name.Split(['_', ' '], StringSplitOptions.RemoveEmptyEntries);
        return string.Concat(parts.Select(static p =>
            char.ToUpperInvariant(p[0]) + p[1..].ToLowerInvariant()));
    }
}
