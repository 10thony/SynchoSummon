using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.IdentityModel.Tokens;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Auth;
using SyncEngine.Server.Hosting;
using SyncEngine.Abstractions.Offline;
using WorkOS;

namespace SyncEngine.Auth.WorkOS;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Validates WorkOS / AuthKit JWTs and maps them to <see cref="SyncPrincipal"/> via
    /// the same <see cref="ClaimsSyncAuthenticator"/> used by SyncEngine.Auth.
    /// </summary>
    public static IServiceCollection AddSyncEngineWorkOsAuth(
        this IServiceCollection services,
        Action<WorkOsSyncAuthOptions> configure)
    {
        services.Configure(configure);
        services.AddOptions<WorkOsSyncAuthOptions>()
            .BindConfiguration(WorkOsSyncAuthOptions.SectionName);

        services.AddSingleton<SyncAuthFeature>(_ => new SyncAuthFeature { RequireAuthenticatedClients = true });
        services.AddSingleton<ISyncAuthenticator, ClaimsSyncAuthenticator>();
        services.Replace(ServiceDescriptor.Singleton<ISyncAuthorization, AuthenticatedSyncAuthorization>());
        services.TryAddSingleton(SyncPushLimits.Default);
        services.AddSyncEnginePushRateLimiter();

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer();

        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<Microsoft.Extensions.Options.IOptions<WorkOsSyncAuthOptions>>((jwt, workOs) =>
            {
                var opts = workOs.Value;
                if (string.IsNullOrWhiteSpace(opts.ClientId))
                {
                    throw new InvalidOperationException("SyncEngine:Auth:WorkOS:ClientId is required.");
                }

                jwt.Authority = opts.Authority;
                jwt.Audience = string.IsNullOrWhiteSpace(opts.Audience) ? opts.ClientId : opts.Audience;
                if (!string.IsNullOrWhiteSpace(opts.MetadataAddress))
                {
                    jwt.MetadataAddress = opts.MetadataAddress;
                }

                jwt.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    NameClaimType = SyncAuthClaims.ClientId,
                    RoleClaimType = "role",
                };

                jwt.Events = new JwtBearerEvents
                {
                    OnTokenValidated = context =>
                    {
                        // Normalize WorkOS org claim into tenant_id when present.
                        var org = context.Principal?.FindFirst("org_id")?.Value;
                        if (!string.IsNullOrWhiteSpace(org)
                            && context.Principal?.Identity is System.Security.Claims.ClaimsIdentity identity
                            && identity.FindFirst(SyncAuthClaims.TenantId) is null)
                        {
                            identity.AddClaim(new System.Security.Claims.Claim(SyncAuthClaims.TenantId, org));
                        }

                        var sub = context.Principal?.FindFirst("sub")?.Value;
                        if (!string.IsNullOrWhiteSpace(sub)
                            && context.Principal?.Identity is System.Security.Claims.ClaimsIdentity id2
                            && id2.FindFirst(SyncAuthClaims.ClientId) is null)
                        {
                            id2.AddClaim(new System.Security.Claims.Claim(SyncAuthClaims.ClientId, sub));
                        }

                        return Task.CompletedTask;
                    },
                    OnMessageReceived = context =>
                    {
                        var accessToken = context.Request.Query["access_token"];
                        var path = context.HttpContext.Request.Path;
                        if (!string.IsNullOrEmpty(accessToken)
                            && (path.StartsWithSegments("/sync/hub")
                                || path.StartsWithSegments("/sync/telemetry/hub")))
                        {
                            context.Token = accessToken;
                        }

                        return Task.CompletedTask;
                    },
                };
            });

        services.AddAuthorizationBuilder()
            .AddPolicy(SyncAuthPolicies.SyncClient, policy => policy.RequireAuthenticatedUser());

        services.AddSingleton(sp =>
        {
            var opts = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<WorkOsSyncAuthOptions>>().Value;
            if (!string.IsNullOrWhiteSpace(opts.ApiKey))
            {
                return new WorkOSClient(new WorkOSOptions { ApiKey = opts.ApiKey, ClientId = opts.ClientId });
            }

            return new WorkOSClient(new WorkOSOptions { ClientId = opts.ClientId });
        });

        return services;
    }
}
