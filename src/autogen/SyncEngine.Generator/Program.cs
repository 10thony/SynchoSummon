using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using SyncEngine.Abstractions.Schema;
using SyncEngine.Generator.Emission;
using SyncEngine.Generator.Readers;
using SyncEngine.Providers.Oracle;

var providerName = (GetArg(args, "--provider") ?? SchemaProviders.Oracle).Trim().ToLowerInvariant();
var connection = GetArg(args, "--connection")
    ?? Environment.GetEnvironmentVariable("SYNCENGINE_ORACLE")
    ?? Environment.GetEnvironmentVariable("SYNCENGINE_CONNECTION");
var schema = GetArg(args, "--schema");
var output = GetArg(args, "--out") ?? "./generated";
var rootNamespace = GetArg(args, "--namespace") ?? "SyncEngine.Generated";
var manifestPath = GetArg(args, "--manifest");
var dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);
var allowRemote = args.Contains("--allow-remote", StringComparer.OrdinalIgnoreCase);
var include = GetArg(args, "--include")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
var exclude = GetArg(args, "--exclude")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
var help = args.Contains("--help", StringComparer.OrdinalIgnoreCase) || args.Contains("-h", StringComparer.OrdinalIgnoreCase);

if (help)
{
    Console.WriteLine(
        """
        SyncEngine schema generator (deterministic, non-LLM)

          --provider oracle|sqlserver|postgres|manifest
          --connection <cs>     DB connection (or SYNCENGINE_CONNECTION / SYNCENGINE_ORACLE)
          --manifest <path>     Required when --provider manifest
          --schema <name>       Schema/owner (oracle default NAS_SIM, sqlserver dbo, postgres public)
          --include a,b,c       Optional table/entity allow-list
          --exclude a,b,c       Optional table/entity deny-list
          --out <dir>           Output directory (default ./generated)
          --namespace <ns>      Root namespace (default SyncEngine.Generated)
          --allow-remote        Allow non-loopback hosts
          --dry-run             List entities only
          --help                Show help

        Emits Models, EntityNames, Server (store/REST/offline/DI), Client (DI), manifest.json.
        """);
    return 0;
}

string outputRoot;
try
{
    outputRoot = JailOutputPath(output);
}
catch (InvalidOperationException ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

ISchemaReader reader;
try
{
    reader = CreateReader(providerName, connection, schema, manifestPath, allowRemote);
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

Console.WriteLine($"Reading schema via provider '{providerName}'...");
IReadOnlyList<EntityDescriptor> entities;
try
{
    entities = await reader.ReadEntitiesAsync();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Schema read failed: {ex.Message}");
    return 1;
}

entities = SchemaFilter.Apply(entities, new SchemaReadOptions
{
    IncludeTables = include,
    ExcludeTables = exclude,
    Schema = schema,
});

Console.WriteLine($"Discovered {entities.Count} entities ({entities.Count(e => e.Syncable)} syncable).");
if (dryRun)
{
    foreach (var entity in entities)
    {
        Console.WriteLine(
            $"- {entity.EntityName} ({entity.TableName}) keys=[{string.Join(',', entity.KeyColumns)}] order={entity.DependencyOrder}");
    }

    return 0;
}

var emitter = new SyncCodeEmitter
{
    OutputRoot = outputRoot,
    RootNamespace = rootNamespace,
};
await emitter.EmitAsync(entities);
Console.WriteLine($"Wrote full sync plug-in ({entities.Count(e => e.Syncable)} entities) to {outputRoot}");
return 0;

static ISchemaReader CreateReader(
    string provider,
    string? connection,
    string? schema,
    string? manifestPath,
    bool allowRemote)
{
    return provider switch
    {
        SchemaProviders.Manifest => CreateManifestReader(manifestPath),
        SchemaProviders.Oracle => CreateOracleReader(connection, schema ?? "NAS_SIM", allowRemote),
        SchemaProviders.SqlServer => CreateSqlServerReader(connection, schema ?? "dbo", allowRemote),
        SchemaProviders.Postgres => CreatePostgresReader(connection, schema ?? "public", allowRemote),
        _ => throw new InvalidOperationException(
            $"Unknown --provider '{provider}'. Use oracle, sqlserver, postgres, or manifest."),
    };
}

static ISchemaReader CreateManifestReader(string? path)
{
    if (string.IsNullOrWhiteSpace(path))
    {
        throw new InvalidOperationException("--manifest is required when --provider manifest.");
    }

    if (!File.Exists(path))
    {
        throw new InvalidOperationException($"Manifest not found: {path}");
    }

    return new ManifestSchemaReader(path);
}

static ISchemaReader CreateOracleReader(string? connection, string schema, bool allowRemote)
{
    RequireConnection(connection);
    if (!allowRemote && LooksRemoteOracle(connection!))
    {
        throw new InvalidOperationException("Refusing non-loopback Data Source. Pass --allow-remote to override.");
    }

    var services = new ServiceCollection();
    services.AddSyncEngineOracle(o =>
    {
        o.ConnectionString = connection!;
        o.Schema = schema;
    });
    var provider = services.BuildServiceProvider();
    return provider.GetRequiredService<ISchemaReader>();
}

static ISchemaReader CreateSqlServerReader(string? connection, string schema, bool allowRemote)
{
    RequireConnection(connection);
    if (!allowRemote && LooksRemoteHost(connection!, "Server=", "Data Source="))
    {
        throw new InvalidOperationException("Refusing non-loopback SQL Server host. Pass --allow-remote to override.");
    }

    return new SqlServerSchemaReader(connection!, schema);
}

static ISchemaReader CreatePostgresReader(string? connection, string schema, bool allowRemote)
{
    RequireConnection(connection);
    if (!allowRemote && LooksRemoteHost(connection!, "Host="))
    {
        throw new InvalidOperationException("Refusing non-loopback Postgres host. Pass --allow-remote to override.");
    }

    return new PostgresSchemaReader(connection!, schema);
}

static void RequireConnection(string? connection)
{
    if (string.IsNullOrWhiteSpace(connection))
    {
        throw new InvalidOperationException("Missing --connection or SYNCENGINE_CONNECTION / SYNCENGINE_ORACLE.");
    }
}

static string? GetArg(string[] args, string name)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
        {
            return args[i + 1];
        }
    }

    return null;
}

static string JailOutputPath(string output)
{
    var cwd = Path.GetFullPath(Environment.CurrentDirectory);
    var full = Path.GetFullPath(Path.Combine(cwd, output));
    if (!IsUnderRoot(cwd, full))
    {
        throw new InvalidOperationException($"--out '{output}' escapes the current directory.");
    }

    return full;
}

static bool IsUnderRoot(string root, string path)
{
    var rootFull = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                   + Path.DirectorySeparatorChar;
    var pathFull = Path.GetFullPath(path);
    return pathFull.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase)
           || string.Equals(Path.GetFullPath(root), pathFull, StringComparison.OrdinalIgnoreCase);
}

static bool LooksRemoteOracle(string connectionString)
{
    const string marker = "Data Source=";
    var idx = connectionString.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
    if (idx < 0)
    {
        return false;
    }

    var start = idx + marker.Length;
    var end = connectionString.IndexOf(';', start);
    var dataSource = end < 0 ? connectionString[start..] : connectionString[start..end];
    dataSource = dataSource.Trim();
    var host = dataSource.Split('/')[0].Split(':')[0];
    return !(string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
             || host is "127.0.0.1" or "::1" || host.StartsWith("(DESCRIPTION", StringComparison.OrdinalIgnoreCase));
}

static bool LooksRemoteHost(string connectionString, params string[] markers)
{
    foreach (var marker in markers)
    {
        var idx = connectionString.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
        if (idx < 0)
        {
            continue;
        }

        var start = idx + marker.Length;
        var end = connectionString.IndexOf(';', start);
        var host = (end < 0 ? connectionString[start..] : connectionString[start..end]).Trim();
        host = host.Split(',')[0].Split('\\')[0];
        if (!(string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
              || host is "127.0.0.1" or "::1" or "." or "(local)"))
        {
            return true;
        }
    }

    return false;
}
