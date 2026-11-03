using Aviation.Shared.Entities;

namespace Aviation.Server.Services;

public sealed class LoadPackageRequest
{
    public string PackageId { get; set; } = string.Empty;

    public string Tier { get; set; } = "custom";

    public List<Facility> Facilities { get; set; } = [];

    public List<Equipment> Equipment { get; set; } = [];

    public List<MaintenanceLog> MaintenanceLogs { get; set; } = [];
}

public sealed class LoadPackageResult
{
    public string PackageId { get; set; } = string.Empty;

    public string Tier { get; set; } = string.Empty;

    public int FacilityCount { get; set; }

    public int EquipmentCount { get; set; }

    public int MaintenanceLogCount { get; set; }

    public int TotalEntities => FacilityCount + EquipmentCount + MaintenanceLogCount;

    public long ApproximatePayloadBytes { get; set; }

    public double ServerApplyMs { get; set; }

    public long FromVersion { get; set; }

    public long ToVersion { get; set; }
}
