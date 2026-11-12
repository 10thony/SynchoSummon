using MemoryPack;
using SyncEngine.Abstractions.Entity;

namespace Aviation.Shared.Entities;

[MemoryPackable]
public partial class MaintenanceLog : ISyncEntity
{
    public static string EntityName => AviationEntityNames.MaintenanceLog;

    public string MaintenanceLogId { get; set; } = string.Empty;

    public string MaintenanceActivityId { get; set; } = string.Empty;

    public string LogEntryType { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public DateTimeOffset LoggedAt { get; set; }

    public string? FacilityId { get; set; }

    public string? EquipmentId { get; set; }

    public string? LocationLabel { get; set; }

    public string? MetadataJson { get; set; }
}

[MemoryPackable]
public partial class MaintenanceLogKey
{
    public string MaintenanceLogId { get; set; } = string.Empty;
}

public static class AviationEntityNames
{
    public const string Facility = "Facility";
    public const string Equipment = "Equipment";
    public const string MaintenanceLog = "MaintenanceLog";

    public static readonly string[] All = [Facility, Equipment, MaintenanceLog];
}
