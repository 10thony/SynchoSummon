using MemoryPack;

namespace Aviation.Shared.Entities;

[MemoryPackable]
public partial class Facility
{
    public string FacilityId { get; set; } = string.Empty;

    public string FacilityCode { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string FacilityTypeCode { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string StateCode { get; set; } = string.Empty;

    public string ZipCode { get; set; } = string.Empty;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public string OperationalStatus { get; set; } = "OPERATIONAL";

    /// <summary>Optional JSON / pad used by load packages to inflate payload size.</summary>
    public string? MetadataJson { get; set; }
}

[MemoryPackable]
public partial class FacilityKey
{
    public string FacilityId { get; set; } = string.Empty;
}
