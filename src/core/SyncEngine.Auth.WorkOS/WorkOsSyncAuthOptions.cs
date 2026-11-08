namespace SyncEngine.Auth.WorkOS;

public sealed class WorkOsSyncAuthOptions
{
    public const string SectionName = "SyncEngine:Auth:WorkOS";

    public string ClientId { get; set; } = string.Empty;

    public string? ApiKey { get; set; }

    /// <summary>JWT authority / issuer used for AuthKit access tokens.</summary>
    public string Authority { get; set; } = "https://api.workos.com/";

    public string Audience { get; set; } = string.Empty;

    public string? MetadataAddress { get; set; }
}
