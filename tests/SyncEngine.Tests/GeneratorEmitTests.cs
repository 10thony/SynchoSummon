using SyncEngine.Abstractions.Schema;
using SyncEngine.Generator.Emission;
using SyncEngine.Generator.Readers;
using Xunit;

namespace SyncEngine.Tests;

public sealed class GeneratorEmitTests
{
    [Fact]
    public async Task ManifestProvider_Emits_ServerAndClient_PlugIn()
    {
        var manifest = Path.Combine(AppContext.BaseDirectory, "Fixtures", "fixture-manifest.json");
        Assert.True(File.Exists(manifest), $"Missing fixture manifest at {manifest}");

        var outDir = Path.Combine(Path.GetTempPath(), $"sync-gen-{Guid.NewGuid():N}");
        Directory.CreateDirectory(outDir);
        try
        {
            var reader = new ManifestSchemaReader(manifest);
            var entities = SchemaFilter.Apply(await reader.ReadEntitiesAsync(), null);
            Assert.Equal(2, entities.Count);

            var emitter = new SyncCodeEmitter
            {
                OutputRoot = outDir,
                RootNamespace = "GeneratorEmit.Test",
            };
            await emitter.EmitAsync(entities);

            Assert.True(File.Exists(Path.Combine(outDir, "manifest.json")));
            Assert.True(File.Exists(Path.Combine(outDir, "EntityNames.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Models", "Facility.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Models", "Equipment.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Server", "GeneratedEntityStore.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Server", "GeneratedOfflineApplicator.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Server", "GeneratedRestEndpoints.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Server", "GeneratedSyncServerExtensions.cs")));
            Assert.True(File.Exists(Path.Combine(outDir, "Client", "GeneratedSyncClientExtensions.cs")));

            var rest = await File.ReadAllTextAsync(Path.Combine(outDir, "Server", "GeneratedRestEndpoints.cs"));
            Assert.Contains("/api/facilities", rest);
            Assert.Contains("/api/equipments", rest);
            Assert.Contains("MapGeneratedSyncRest", rest);

            var names = await File.ReadAllTextAsync(Path.Combine(outDir, "EntityNames.cs"));
            Assert.Contains("public const string Facility", names);
            Assert.Contains("public const string Equipment", names);
        }
        finally
        {
            try { Directory.Delete(outDir, recursive: true); } catch { /* ignore */ }
        }
    }
}
