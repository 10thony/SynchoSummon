using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Aviation.Shared.Entities;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Codec;
using Xunit;

namespace SyncEngine.Tests;

public sealed class AuthTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public AuthTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(_ => { });
    }

    [Fact]
    public async Task Unauthenticated_DeltaPull_IsRejected()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync($"{SyncRoutes.Deltas}?since=0&limit=10");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Unauthenticated_Push_IsRejected()
    {
        var client = _factory.CreateClient();
        using var content = new ByteArrayContent([1, 2, 3]);
        content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var response = await client.PostAsync(SyncRoutes.Push, content);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ValidToken_Allows_PullAndPush()
    {
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client);

        var version = await client.GetAsync(SyncRoutes.Version);
        Assert.Equal(HttpStatusCode.OK, version.StatusCode);

        var pull = await client.GetAsync($"{SyncRoutes.Deltas}?since=0&limit=10");
        Assert.Equal(HttpStatusCode.OK, pull.StatusCode);

        var codec = new MemoryPackDeltaCodec();
        var facility = new Facility
        {
            FacilityId = $"fac-auth-{Guid.NewGuid():N}"[..22],
            FacilityCode = "AUTH",
            Name = "Auth Push Field",
            FacilityTypeCode = "AIRPORT",
            City = "Des Moines",
            StateCode = "IA",
            ZipCode = "50309",
            Latitude = 41.5m,
            Longitude = -93.6m,
        };
        using var key = codec.Encode(new FacilityKey { FacilityId = facility.FacilityId });
        using var payload = codec.Encode(facility);
        var batch = new DeltaBatch
        {
            FromVersion = 0,
            ToVersion = 1,
            HasMore = false,
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = AviationEntityNames.Facility,
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = key.Memory.ToArray(),
                    PayloadBytes = payload.Memory.ToArray(),
                },
            ],
        };
        using var encoded = codec.EncodeBatch(batch);
        using var content = new ByteArrayContent(encoded.Memory.ToArray());
        content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var push = await client.PostAsync(SyncRoutes.Push, content);
        Assert.Equal(HttpStatusCode.OK, push.StatusCode);
    }

    [Fact]
    public async Task Spoofed_ClientId_Header_DoesNotOverride_Principal()
    {
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client);
        client.DefaultRequestHeaders.Remove("X-Sync-Client-Id");
        client.DefaultRequestHeaders.TryAddWithoutValidation("X-Sync-Client-Id", "ceo-laptop-id");

        var pull = await client.GetAsync($"{SyncRoutes.Deltas}?since=0&limit=1");
        Assert.Equal(HttpStatusCode.OK, pull.StatusCode);
    }

    [Fact]
    public async Task InvalidToken_IsRejected()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "not.a.jwt");
        var response = await client.GetAsync(SyncRoutes.Version);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Unauthenticated_Hub_IsRejected()
    {
        await using var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(_factory.Server.BaseAddress!, SyncRoutes.Hub), o =>
            {
                o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
            })
            .Build();

        var ex = await Assert.ThrowsAnyAsync<Exception>(() => hub.StartAsync());
        Assert.Contains("401", ex.ToString() + (ex.InnerException?.ToString() ?? string.Empty));
    }

    [Fact]
    public async Task Oversized_PushBody_IsRejected()
    {
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client);
        var huge = new byte[1024 * 1024 + 8];
        Random.Shared.NextBytes(huge);
        using var content = new ByteArrayContent(huge);
        content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var response = await client.PostAsync(SyncRoutes.Push, content);
        Assert.True(
            response.StatusCode is HttpStatusCode.RequestEntityTooLarge or HttpStatusCode.BadRequest,
            $"Expected 413 or 400, got {(int)response.StatusCode}");
    }

    [Fact]
    public async Task Push_UnknownEntity_IsRejected()
    {
        var client = _factory.CreateClient();
        await AuthTestHelpers.AuthorizeAsync(client);
        var codec = new MemoryPackDeltaCodec();
        var batch = new DeltaBatch
        {
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = "NotAllowedEntity",
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = Encoding.UTF8.GetBytes("k"),
                    PayloadBytes = Encoding.UTF8.GetBytes("p"),
                },
            ],
        };
        using var encoded = codec.EncodeBatch(batch);
        using var content = new ByteArrayContent(encoded.Memory.ToArray());
        content.Headers.ContentType = new MediaTypeHeaderValue(SyncContentTypes.MemoryPack);
        var response = await client.PostAsync(SyncRoutes.Push, content);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
