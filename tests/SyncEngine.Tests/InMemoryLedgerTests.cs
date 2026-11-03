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
}
