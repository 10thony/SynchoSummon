extern alias PlugAndPlay;

using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using PlugAndPlay.Generated;
using PlugAndPlay.Generated.Models;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Codec;
using SyncEngine.Abstractions.Protocol;
using Xunit;

using PlugAndPlayProgram = PlugAndPlay::Program;

namespace SyncEngine.Tests;

public sealed class PlugAndPlayIntegrationTests
    : IClassFixture<WebApplicationFactory<PlugAndPlayProgram>>
{
    private readonly WebApplicationFactory<PlugAndPlayProgram> _factory;

    public PlugAndPlayIntegrationTests(WebApplicationFactory<PlugAndPlayProgram> factory)
    {
        _factory = factory.WithWebHostBuilder(_ => { });
    }

    [Fact]
    public async Task GeneratedRest_CrudRoundTrip_WithSyncDelta()
    {
        // Arrange
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client, "sample-dev", "sample-dev-secret");
        var codec = new MemoryPackDeltaCodec();

        var facilityId = $"pnp-crud-{Guid.NewGuid():N}"[..28];
        var facility = new
        {
            FacilityId = facilityId,
            FacilityCode = "PNP",
            Name = "PlugAndPlay CRUD Test",
        };

        // Act 1 — Create facility via REST
        var createResponse = await client.PostAsJsonAsync("/api/facilities", facility);
        createResponse.EnsureSuccessStatusCode();

        // Assert — GET returns the created facility
        var listResponse = await client.GetAsync("/api/facilities");
        listResponse.EnsureSuccessStatusCode();
        var facilities = await listResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(
            facilities.EnumerateArray().Any(f =>
                f.GetProperty("facilityId").GetString() == facilityId),
            "Created facility should appear in GET /api/facilities.");

        // Act 2 — Check sync version advanced
        var versionResponse = await client.GetAsync(SyncRoutes.Version);
        versionResponse.EnsureSuccessStatusCode();
        var versionBytes = await versionResponse.Content.ReadAsByteArrayAsync();
        var version = codec.DecodeVersion(versionBytes);
        Assert.True(version.Version > 0, "Sync version should be > 0 after a mutation.");

        // Act 3 — Fetch deltas since 0 and assert an Upsert for Facility
        var deltasResponse = await client.GetAsync($"{SyncRoutes.Deltas}?since=0&limit=100");
        deltasResponse.EnsureSuccessStatusCode();
        var deltasBytes = await deltasResponse.Content.ReadAsByteArrayAsync();
        var batch = codec.DecodeBatch(deltasBytes);
        Assert.True(batch.ToVersion > 0, "Delta batch should have advanced version.");
        Assert.Contains(batch.Changes, c =>
            c.EntityName == EntityNames.Facility
            && c.Operation == DeltaOperation.Upsert);

        var prevVersion = batch.ToVersion;

        // Act 4 — DELETE the facility
        var deleteResponse = await client.DeleteAsync($"/api/facilities/{facilityId}");
        Assert.Equal(System.Net.HttpStatusCode.NoContent, deleteResponse.StatusCode);

        // Act 5 — Deltas since prevVersion should contain a Delete
        var postDeleteDeltasResponse = await client.GetAsync(
            $"{SyncRoutes.Deltas}?since={prevVersion}&limit=100");
        postDeleteDeltasResponse.EnsureSuccessStatusCode();
        var postDeleteBytes = await postDeleteDeltasResponse.Content.ReadAsByteArrayAsync();
        var postDeleteBatch = codec.DecodeBatch(postDeleteBytes);
        Assert.Contains(postDeleteBatch.Changes, c =>
            c.EntityName == EntityNames.Facility
            && c.Operation == DeltaOperation.Delete);
    }

    [Fact]
    public async Task OfflinePush_RoundTrip_ViaSync()
    {
        // Arrange
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client, "sample-dev", "sample-dev-secret");
        var codec = new MemoryPackDeltaCodec();

        var equipmentId = $"eq-push-{Guid.NewGuid():N}"[..28];
        var equipment = new Equipment
        {
            EquipmentId = equipmentId,
            FacilityId = "fac-push-1",
            Name = "Pushed Equipment",
        };
        var equipKey = new EquipmentKey { EquipmentId = equipmentId };

        using var keyBuf = codec.Encode(equipKey);
        using var payloadBuf = codec.Encode(equipment);

        var pushBatch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = 1,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = EntityNames.Equipment,
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = keyBuf.Memory.ToArray(),
                    PayloadBytes = payloadBuf.Memory.ToArray(),
                },
            ],
        };

        using var encodedBatch = codec.EncodeBatch(pushBatch);
        using var content = new ByteArrayContent(encodedBatch.Memory.ToArray());
        content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);

        // Act 1 — Push the batch
        var pushResponse = await client.PostAsync(SyncRoutes.Push, content);
        pushResponse.EnsureSuccessStatusCode();

        // Assert — Equipment appears in REST GET
        var listResponse = await client.GetAsync("/api/equipments");
        listResponse.EnsureSuccessStatusCode();
        var equipments = await listResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(
            equipments.EnumerateArray().Any(e =>
                e.GetProperty("equipmentId").GetString() == equipmentId),
            "Pushed equipment should appear in GET /api/equipments.");

        // Assert — Sync version advanced
        var deltasResponse = await client.GetAsync($"{SyncRoutes.Deltas}?since=0&limit=100");
        deltasResponse.EnsureSuccessStatusCode();
        var deltasBytes = await deltasResponse.Content.ReadAsByteArrayAsync();
        var batch = codec.DecodeBatch(deltasBytes);
        Assert.True(batch.ToVersion > 0, "Sync version should have advanced after push.");
        Assert.Contains(batch.Changes, c =>
            c.EntityName == EntityNames.Equipment
            && c.Operation == DeltaOperation.Upsert);
    }
}
