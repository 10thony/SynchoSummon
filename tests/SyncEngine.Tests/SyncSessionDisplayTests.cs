using SyncEngine.Abstractions.Client;
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
}
