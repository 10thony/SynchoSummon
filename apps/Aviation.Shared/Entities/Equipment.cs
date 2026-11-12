using MemoryPack;
using SyncEngine.Abstractions.Entity;

namespace Aviation.Shared.Entities;

[MemoryPackable]
public partial class Equipment : ISyncEntity
{
    public static string EntityName => AviationEntityNames.Equipment;

    public string EquipmentId { get; set; } = string.Empty;

    public string FacilityId { get; set; } = string.Empty;

    public string EquipmentTypeCode { get; set; } = string.Empty;

    public string Identifier { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string OperationalStatus { get; set; } = "OPERATIONAL";

    public string? Manufacturer { get; set; }

    public string? Model { get; set; }

    public string? MetadataJson { get; set; }
}

[MemoryPackable]
public partial class EquipmentKey
{
    public string EquipmentId { get; set; } = string.Empty;
}
