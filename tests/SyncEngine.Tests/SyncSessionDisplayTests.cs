using SyncEngine.Abstractions.Client;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client;
using Xunit;

namespace SyncEngine.Tests;

public sealed class SyncSessionDisplayTests
{
    [Theory]
    [InlineData(SyncSessionPhase.Connecting, null, "Connecting…")]
    [InlineData(SyncSessionPhase.CatchingUp, null, "Catching up…")]
    [InlineData(SyncSessionPhase.OfflinePolling, null, "Offline (polling)")]
    [InlineData(SyncSessionPhase.Degraded, null, "Sync error – retrying")]
    public void Format_UsesStableLabels(SyncSessionPhase phase, long? checkpoint, string expected)
        => Assert.Equal(expected, SyncSessionDisplay.Format(phase, checkpoint));

    [Fact]
    public void Format_LiveIncludesCheckpoint()
        => Assert.Equal("Connected (v42)", SyncSessionDisplay.Format(SyncSessionPhase.Live, 42));

    [Fact]
    public void ResolveTransportMode_MapsFlags()
    {
        Assert.Equal(SyncTransportMode.HttpPollOnly, new SyncClientOptions { EnableSignalR = false }.ResolveTransportMode());
        Assert.Equal(
            SyncTransportMode.WakeAndPull,
            new SyncClientOptions { EnableSignalR = true, EnableDeltaStreaming = false }.ResolveTransportMode());
        Assert.Equal(
            SyncTransportMode.StreamAndWake,
            new SyncClientOptions { EnableSignalR = true, EnableDeltaStreaming = true }.ResolveTransportMode());
    }

    [Fact]
    public void Snapshot_NewFields_HaveCorrectDefaults()
    {
        var snapshot = new SyncSessionSnapshot(
            SyncSessionPhase.Live,
            SyncHubLinkState.Connected,
            SyncTransportMode.StreamAndWake,
            42,
            "Connected (v42)");

        Assert.Null(snapshot.OutboxPhase);
        Assert.Null(snapshot.OutboxPendingCount);
        Assert.Null(snapshot.CatchUpAppliedCount);
        Assert.Null(snapshot.LastStreamApplyUtc);
        Assert.Equal(0, snapshot.ChannelWakeDropCount);
        Assert.Equal(0, snapshot.ChannelDeltaDropCount);
    }

    [Fact]
    public void Create_PassesThroughNewFields()
    {
        var now = DateTimeOffset.UtcNow;
        var snapshot = SyncSessionDisplay.Create(
            SyncSessionPhase.Live,
            SyncHubLinkState.Connected,
            SyncTransportMode.StreamAndWake,
            checkpoint: 100,
            outboxPhase: SyncOutboxPhase.Pending,
            outboxPendingCount: 5,
            catchUpAppliedCount: 12,
            lastStreamApplyUtc: now,
            channelWakeDropCount: 3,
            channelDeltaDropCount: 1);

        Assert.Equal(SyncOutboxPhase.Pending, snapshot.OutboxPhase);
        Assert.Equal(5, snapshot.OutboxPendingCount);
        Assert.Equal(12, snapshot.CatchUpAppliedCount);
        Assert.Equal(now, snapshot.LastStreamApplyUtc);
        Assert.Equal(3, snapshot.ChannelWakeDropCount);
        Assert.Equal(1, snapshot.ChannelDeltaDropCount);
    }

    [Fact]
    public void Create_PreservesOriginalFieldsBehavior()
    {
        var snapshot = SyncSessionDisplay.Create(
            SyncSessionPhase.Live,
            SyncHubLinkState.Connected,
            SyncTransportMode.StreamAndWake,
            checkpoint: 42);

        Assert.Equal(SyncSessionPhase.Live, snapshot.Phase);
        Assert.Equal(SyncHubLinkState.Connected, snapshot.Hub);
        Assert.Equal(SyncTransportMode.StreamAndWake, snapshot.TransportMode);
        Assert.Equal(42, snapshot.Checkpoint);
        Assert.Equal("Connected (v42)", snapshot.DisplayStatus);
        Assert.Null(snapshot.Detail);
        Assert.Null(snapshot.LastError);
        Assert.Null(snapshot.LastSuccessUtc);
    }

    [Fact]
    public void ISyncApplyNotifications_IsSatisfiedBySyncPullService()
    {
        // Compile-time verification: SyncPullService implements ISyncApplyNotifications.
        Assert.True(typeof(ISyncApplyNotifications).IsAssignableFrom(typeof(SyncPullService)));
    }
}
