using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SyncEngine.Abstractions.Auth;

namespace SyncEngine.Auth;

public sealed class SyncJwtTokenService(IOptions<SyncAuthOptions> options)
{
    private readonly SyncAuthOptions _options = options.Value;

    public bool TryIssueToken(string clientId, string clientSecret, out SyncTokenResponse? response, out string? error)
    {
        response = null;
        error = null;

        var registration = _options.Clients.FirstOrDefault(c =>
            string.Equals(c.ClientId, clientId, StringComparison.Ordinal));
        if (registration is null
            || !FixedTimeEquals(registration.ClientSecret, clientSecret))
        {
            error = "invalid_client";
            return false;
        }

        var now = DateTimeOffset.UtcNow;
        var expires = now.Add(_options.TokenLifetime);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, registration.ClientId),
            new(SyncAuthClaims.ClientId, registration.ClientId),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
        };

        if (!string.IsNullOrWhiteSpace(registration.TenantId))
        {
            claims.Add(new Claim(SyncAuthClaims.TenantId, registration.TenantId));
        }

        foreach (var role in registration.Roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var credentials = new SigningCredentials(CreateSecurityKey(_options.SigningKey), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            notBefore: now.UtcDateTime,
            expires: expires.UtcDateTime,
            signingCredentials: credentials);

        response = new SyncTokenResponse(
            new JwtSecurityTokenHandler().WriteToken(token),
            "Bearer",
            (int)_options.TokenLifetime.TotalSeconds,
            registration.ClientId,
            registration.TenantId);
        return true;
    }

    public static SymmetricSecurityKey CreateSecurityKey(string signingKey)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(signingKey);
        var bytes = Encoding.UTF8.GetBytes(signingKey);
        if (bytes.Length < 32)
        {
            bytes = SHA256.HashData(bytes);
        }

        return new SymmetricSecurityKey(bytes);
    }

    private static bool FixedTimeEquals(string expected, string actual)
    {
        var a = Encoding.UTF8.GetBytes(expected);
        var b = Encoding.UTF8.GetBytes(actual ?? string.Empty);
        if (a.Length != b.Length)
        {
            // still compare to reduce timing signal on length
            CryptographicOperations.FixedTimeEquals(a, a);
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(a, b);
    }
}

public sealed record SyncTokenResponse(
    string AccessToken,
    string TokenType,
    int ExpiresIn,
    string ClientId,
    string? TenantId);
