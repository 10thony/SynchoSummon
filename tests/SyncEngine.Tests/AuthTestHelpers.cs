using System.Net.Http.Headers;
using System.Net.Http.Json;
using SyncEngine.Abstractions;
using Xunit;

namespace SyncEngine.Tests;

internal static class AuthTestHelpers
{
    public const string DefaultClientId = "e2e-dev";
    public const string DefaultClientSecret = "e2e-dev-secret";

    public static async Task<string> GetAccessTokenAsync(
        HttpClient client,
        string clientId = DefaultClientId,
        string clientSecret = DefaultClientSecret)
    {
        using var response = await client.PostAsJsonAsync(SyncRoutes.Token, new
        {
            client_id = clientId,
            client_secret = clientSecret,
        });
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<TokenResponse>();
        Assert.False(string.IsNullOrWhiteSpace(payload?.AccessToken));
        return payload!.AccessToken;
    }

    public static async Task AuthorizeAsync(
        HttpClient client,
        string clientId = DefaultClientId,
        string clientSecret = DefaultClientSecret)
    {
        var token = await GetAccessTokenAsync(client, clientId, clientSecret);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private sealed class TokenResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = string.Empty;
    }
}
