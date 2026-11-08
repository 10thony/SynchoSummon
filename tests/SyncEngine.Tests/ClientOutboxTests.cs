using SyncEngine.Abstractions.Protocol;
using SyncEngine.Client.Codec;
using SyncEngine.Client.Offline;
using Xunit;

namespace SyncEngine.Tests;

public sealed class ClientOutboxTests
{
    [Fact]
    public void Enqueue_DoesNotDoubleCount_Pending()
    {
        var outbox = new ClientOutbox();
        for (var i = 0; i < 20; i++)
        {
            outbox.EnqueueUpsert("Facility", new byte[] { (byte)i }, new byte[] { 1, 2, 3 });
        }

        Assert.Equal(20, outbox.PendingCount);
    }
}
