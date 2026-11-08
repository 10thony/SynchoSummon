namespace SyncEngine.Providers.Oracle;

public sealed class OracleOptions
{
    public const string SectionName = "SyncEngine:Oracle";

    /// <summary>Required. Set via configuration / environment — no compiled default password.</summary>
    public string ConnectionString { get; set; } = string.Empty;

    public string Schema { get; set; } = "NAS_SIM";
}
