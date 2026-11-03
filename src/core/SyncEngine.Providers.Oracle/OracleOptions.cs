namespace SyncEngine.Providers.Oracle;

public sealed class OracleOptions
{
    public const string SectionName = "SyncEngine:Oracle";

    public string ConnectionString { get; set; } =
        "User Id=nas_sim;Password=NasSim_Dev1;Data Source=localhost:1522/FREEPDB1";

    public string Schema { get; set; } = "NAS_SIM";
}
