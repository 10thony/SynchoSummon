namespace SyncEngine.Abstractions.Auth;

public static class SyncAuthClaims
{
    public const string ClientId = "client_id";
    public const string TenantId = "tenant_id";
    public const string Scope = "sync";
}

public static class SyncAuthPolicies
{
    public const string SyncClient = "SyncEngine.SyncClient";
}
