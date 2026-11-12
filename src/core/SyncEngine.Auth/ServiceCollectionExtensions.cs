using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Server.Hosting;
using SyncEngine.Abstractions.Offline;

namespace SyncEngine.Auth;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSyncEngineAuth(
        this IServiceCollection services,
        Action<SyncAuthOptions>? configure = null)
    {
        if (configure is not null)
        {
            services.Configure(configure);
        }

        services.AddOptions<SyncAuthOptions>()
            .BindConfiguration(SyncAuthOptions.SectionName);

        services.AddSingleton<SyncJwtTokenService>();
        services.AddSingleton<SyncAuthFeature>(_ => new SyncAuthFeature { RequireAuthenticatedClients = true });
        services.AddSingleton<ISyncAuthenticator, ClaimsSyncAuthenticator>();
        services.Replace(ServiceDescriptor.Singleton<ISyncAuthorization, AuthenticatedSyncAuthorization>());
        services.TryAddSingleton(SyncPushLimits.Default);
        services.AddSyncEnginePushRateLimiter();

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer();

        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<SyncAuthOptions>>((jwt, authOptions) =>
            {
                var opts = authOptions.Value;
                if (string.IsNullOrWhiteSpace(opts.SigningKey))
                {
                    throw new InvalidOperationException(
                        "SyncEngine:Auth:SigningKey is required when AddSyncEngineAuth is used.");
                }

                jwt.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = opts.Issuer,
                    ValidateAudience = true,
                    ValidAudience = opts.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = SyncJwtTokenService.CreateSecurityKey(opts.SigningKey),
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromMinutes(1),
                    NameClaimType = SyncAuthClaims.ClientId,
                };

                jwt.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        // SignalR sends access_token as a query string on WebSockets.
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
            .AddPolicy(SyncAuthPolicies.SyncClient, policy =>
            {
                policy.RequireAuthenticatedUser();
            });

        return services;
    }

    public static IServiceCollection AddSyncEngineDevClients(
        this IServiceCollection services,
        Action<SyncDevClientBuilder> configure)
    {
        services.PostConfigure<SyncAuthOptions>(options =>
        {
            var builder = new SyncDevClientBuilder(options);
            configure(builder);
        });
        return services;
    }

    public static IEndpointRouteBuilder MapSyncEngineAuth(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(SyncRoutes.Token, async (
            SyncTokenRequest request,
            SyncJwtTokenService tokens) =>
        {
            if (string.IsNullOrWhiteSpace(request.ClientId)
                || string.IsNullOrWhiteSpace(request.ClientSecret))
            {
                return Results.BadRequest(new { error = "invalid_request" });
            }

            if (!tokens.TryIssueToken(request.ClientId, request.ClientSecret, out var response, out var error))
            {
                return Results.Json(new { error }, statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Json(new
            {
                access_token = response!.AccessToken,
                token_type = response.TokenType,
                expires_in = response.ExpiresIn,
                client_id = response.ClientId,
                tenant_id = response.TenantId,
            });
        }).AllowAnonymous();

        return endpoints;
    }
}

public sealed class SyncDevClientBuilder(SyncAuthOptions options)
{
    public SyncDevClientBuilder Add(string clientId, string secret, string? tenant = null, params string[] roles)
    {
        options.Clients.RemoveAll(c => string.Equals(c.ClientId, clientId, StringComparison.Ordinal));
        options.Clients.Add(new SyncDevClientRegistration
        {
            ClientId = clientId,
            ClientSecret = secret,
            TenantId = tenant,
            Roles = roles.ToList(),
        });
        return this;
    }
}

public sealed class SyncTokenRequest
{
    public string? ClientId { get; set; }

    public string? ClientSecret { get; set; }

    // JSON snake_case aliases for clients that post form-style names
    public string? client_id
    {
        get => ClientId;
        set => ClientId = value;
    }

    public string? client_secret
    {
        get => ClientSecret;
        set => ClientSecret = value;
    }
}
