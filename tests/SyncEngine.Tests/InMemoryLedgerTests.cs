using SyncEngine.Abstractions.Protocol;
using SyncEngine.Server.Ledger;
using Xunit;

namespace SyncEngine.Tests;

public sealed class InMemoryLedgerTests
{
    [Fact]
    public async Task AppendAndPage_IsMonotonic_AndHasMoreUsesLimitPlusOne()
    {
        var ledger = new InMemoryChangeLedger();
        for (var i = 0; i < 5; i++)
        {
            await ledger.AppendAsync(
                "Facility",
                DeltaOperation.Upsert,
                new byte[] { (byte)i },
                new byte[] { 1, 2, 3 });
        }

        var page = await ledger.GetDeltasAsync(sinceVersion: 0, limit: 2);
        Assert.Equal(2, page.Changes.Length);
        Assert.True(page.HasMore);
        Assert.Equal(2, page.ToVersion);

        var page2 = await ledger.GetDeltasAsync(sinceVersion: 2, limit: 10);
        Assert.Equal(3, page2.Changes.Length);
        Assert.False(page2.HasMore);
        Assert.Equal(5, page2.ToVersion);
    }

    [Fact]
    public async Task GetDeltas_WhenRingTruncated_ThrowsInsteadOfSilentGap()
    {
        var ledger = new InMemoryChangeLedger(capacity: 3);
        for (var i = 0; i < 5; i++)
        {
            await ledger.AppendAsync(
                "Facility",
                DeltaOperation.Upsert,
                new byte[] { (byte)i },
                new byte[] { 1 });
        }

        // Versions 1-2 shed; oldest retained is 3. since=0 cannot be served completely.
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => ledger.GetDeltasAsync(sinceVersion: 0, limit: 10));
        Assert.Contains("truncated", ex.Message, StringComparison.OrdinalIgnoreCase);

        var tip = await ledger.GetDeltasAsync(sinceVersion: 2, limit: 10);
        Assert.Equal(3, tip.Changes.Length);
        Assert.Equal(5, tip.ToVersion);
    }
}
