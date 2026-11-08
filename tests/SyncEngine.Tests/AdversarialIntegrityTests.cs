using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using SyncEngine.Client.Codec;
using SyncEngine.Server.Ledger;
using SyncEngine.Server.Offline;
using Xunit;

namespace SyncEngine.Tests;

public sealed class AdversarialIntegrityTests
{
    [Fact]
    public async Task PullFilter_AlwaysAdvances_ToVersion()
    {
        var ledger = new InMemoryChangeLedger();
        var codec = new MemoryPackDeltaCodec();
        for (var i = 0; i < 5; i++)
        {
            using var key = codec.Encode($"k-{i}");
            await ledger.AppendAsync("SecretEntity", DeltaOperation.Upsert, key.Memory, key.Memory);
        }

        var authZ = new DenyEntityAuthorization("SecretEntity");
        var batch = await ledger.GetDeltasAsync(0, 10);
        var ledgerTo = batch.ToVersion;
        var filtered = batch.Changes
            .Where(c => authZ.CanRead(new SyncPrincipal { Subject = "u", ClientId = "u" }, c.EntityName, c.KeyBytes, c.TenantId))
            .ToArray();

        var clientBatch = new DeltaBatch
        {
            FromVersion = batch.FromVersion,
            ToVersion = ledgerTo,
            HasMore = batch.HasMore,
            Changes = filtered,
        };

        Assert.Empty(clientBatch.Changes);
        Assert.Equal(ledgerTo, clientBatch.ToVersion);
        Assert.True(clientBatch.ToVersion > 0);
    }

    [Fact]
    public async Task CheckpointStore_Rejects_Rollback()
    {
        var store = new InMemoryCheckpointStore();
        await store.SetVersionAsync(10);
        await Assert.ThrowsAsync<InvalidOperationException>(() => store.SetVersionAsync(9));
    }

    [Fact]
    public async Task PushHandler_Rejects_OversizedBody()
    {
        var handler = CreatePushHandler(new UnsafeAllowAllSyncAuthorization());
        var principal = new SyncPrincipal { Subject = "t", ClientId = "t", IsAuthenticated = true };
        await Assert.ThrowsAsync<SyncPushRejectedException>(() =>
            handler.HandleAsync(new byte[2 * 1024 * 1024], principal, CancellationToken.None));
    }

    [Fact]
    public async Task PushHandler_Rejects_Unauthenticated_WhenAuthZRequiresIt()
    {
        var handler = CreatePushHandler(new AuthenticatedSyncAuthorization());
        var codec = new MemoryPackDeltaCodec();
        var batch = new DeltaBatch
        {
            Changes =
            [
                new DeltaChange
                {
                    Version = 1,
                    EntityName = "Facility",
                    Operation = DeltaOperation.Upsert,
                    KeyBytes = [1],
                    PayloadBytes = [2],
                },
            ],
        };
        using var encoded = codec.EncodeBatch(batch);
        await Assert.ThrowsAsync<SyncPushRejectedException>(() =>
            handler.HandleAsync(encoded.Memory, SyncPrincipal.Anonymous, CancellationToken.None));
    }

    [Fact]
    public void TenantScoped_Authorization_Filters_CrossTenant()
    {
        var authZ = new TenantScopedSyncAuthorization();
        var principal = new SyncPrincipal
        {
            Subject = "a",
            ClientId = "a",
            TenantId = "tenant-a",
            IsAuthenticated = true,
        };

        Assert.True(authZ.CanRead(principal, "Facility", [1], tenantId: null));
        Assert.True(authZ.CanRead(principal, "Facility", [1], tenantId: "tenant-a"));
        Assert.False(authZ.CanRead(principal, "Facility", [1], tenantId: "tenant-b"));
    }

    private static OfflinePushHandler CreatePushHandler(ISyncAuthorization authorization)
    {
        var codec = new MemoryPackDeltaCodec();
        var ledger = new InMemoryChangeLedger();
        var writer = new ChangeLedgerWriter(
            ledger,
            new SyncEngine.Server.Store.NoOpOrgStore(),
            new NoopNotifier(),
            new SilentTelemetry());
        return new OfflinePushHandler(
            codec,
            writer,
            new NoOpOfflineEntityApplicator(),
            authorization,
            new SyncPushLimits { AllowedEntityNames = null, MaxBodyBytes = 1024 * 1024 });
    }

    private sealed class DenyEntityAuthorization(string denied) : ISyncAuthorization
    {
        public bool CanRead(SyncPrincipal principal, string entityName, ReadOnlySpan<byte> keyBytes, string? tenantId = null)
            => !string.Equals(entityName, denied, StringComparison.OrdinalIgnoreCase);

        public bool CanPush(
            SyncPrincipal principal,
            string entityName,
            ReadOnlySpan<byte> keyBytes,
            DeltaOperation operation,
            string? tenantId = null) => true;
    }

    private sealed class NoopNotifier : SyncEngine.Abstractions.Notify.ISyncNotifier
    {
        public ValueTask EnqueueWakeAsync(
            long version,
            string entityName,
            CancellationToken cancellationToken = default,
            string? tenantId = null)
            => ValueTask.CompletedTask;
    }

    private sealed class SilentTelemetry : SyncEngine.Server.Telemetry.ISyncTelemetry
    {
        public void Record(SyncEngine.Abstractions.Telemetry.SyncTelemetryEvent telemetryEvent)
        {
        }

        public IReadOnlyList<SyncEngine.Abstractions.Telemetry.SyncTelemetryEvent> GetRecent(int take = 200)
            => [];

        public SyncEngine.Server.Telemetry.SyncTelemetryStats GetStats()
            => new();
    }
}
