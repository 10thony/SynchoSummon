namespace SyncEngine.Client.Auth;

public sealed class SyncClientCredentialOptions
{
    public const string SectionName = "SyncEngine:ClientCredentials";

    public string ClientId { get; set; } = string.Empty;

    public string ClientSecret { get; set; } = string.Empty;

    /// <summary>Absolute or server-relative token URL. Defaults to {ServerBaseAddress}/sync/auth/token.</summary>
    public string? TokenEndpoint { get; set; }
}
