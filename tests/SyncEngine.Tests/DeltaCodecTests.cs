using Aviation.Shared.Entities;
using SyncEngine.Abstractions.Protocol;
using SyncEngine.Abstractions.Codec;
using Xunit;

namespace SyncEngine.Tests;

public sealed class DeltaCodecTests
{
    [Fact]
    public void RoundTrips_DeltaBatch_WithFacilityPayload()
    {
        var codec = new MemoryPackDeltaCodec();
        using var key = codec.Encode(new FacilityKey { FacilityId = "fac-1" });
        using var payload = codec.Encode(new Facility
        {
            FacilityId = "fac-1",
            FacilityCode = "DSM",
            Name = "Des Moines",
            FacilityTypeCode = "AIRPORT",
            City = "Des Moines",
            StateCode = "IA",
            ZipCode = "50321",
            Latitude = 41.5m,
            Longitude = -93.6m,
        });

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
        var decoded = codec.DecodeBatch(encoded.Memory.Span);

        Assert.Equal(1, decoded.ToVersion);
        Assert.Single(decoded.Changes);
        Assert.Equal(AviationEntityNames.Facility, decoded.Changes[0].EntityName);
        var facility = codec.Decode<Facility>(decoded.Changes[0].PayloadBytes);
        Assert.Equal("DSM", facility.FacilityCode);
    }
}
