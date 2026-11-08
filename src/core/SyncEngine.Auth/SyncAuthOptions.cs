namespace SyncEngine.Auth;

public sealed class SyncAuthOptions
{
    public const string SectionName = "SyncEngine:Auth";

    /// <summary>Symmetric signing key (min 32 characters recommended).</summary>
    public string SigningKey { get; set; } = string.Empty;

    public string Issuer { get; set; } = "syncengine";

    public string Audience { get; set; } = "syncengine";

    public TimeSpan TokenLifetime { get; set; } = TimeSpan.FromHours(1);

    public List<SyncDevClientRegistration> Clients { get; set; } = [];
}

public sealed class SyncDevClientRegistration
{
    public string ClientId { get; set; } = string.Empty;

    public string ClientSecret { get; set; } = string.Empty;

    public string? TenantId { get; set; }

    public List<string> Roles { get; set; } = [];
}
