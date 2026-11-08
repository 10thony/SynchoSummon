using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using SyncEngine.Abstractions;
using SyncEngine.Abstractions.Auth;
using SyncEngine.Abstractions.Client;

namespace SyncEngine.Client.Auth;

public sealed class ClientCredentialsTokenProvider(
    IHttpClientFactory httpClientFactory,
    IOptions<SyncClientCredentialOptions> credentialOptions,
    IOptions<SyncClientOptions> clientOptions) : ISyncCredentialProvider, ISyncCredentialStatus
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly object _stateGate = new();
    private string? _accessToken;
    private DateTimeOffset _expiresAt;
    private SyncCredentialState _credentialState = SyncCredentialState.Unconfigured;

    public SyncCredentialState CredentialState
    {
        get
        {
            lock (_stateGate)
            {
                return _credentialState;
            }
        }
    }

    public event Action<SyncCredentialState>? CredentialStateChanged;

    public async Task<string?> GetAccessTokenAsync(CancellationToken cancellationToken = default)
    {
        if (!string.IsNullOrEmpty(_accessToken) && DateTimeOffset.UtcNow < _expiresAt)
        {
            SetCredentialState(SyncCredentialState.Valid);
            return _accessToken;
        }

        if (!string.IsNullOrEmpty(_accessToken) && DateTimeOffset.UtcNow >= _expiresAt)
        {
            SetCredentialState(SyncCredentialState.Expired);
        }

        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (!string.IsNullOrEmpty(_accessToken) && DateTimeOffset.UtcNow < _expiresAt)
            {
                SetCredentialState(SyncCredentialState.Valid);
                return _accessToken;
            }

            var creds = credentialOptions.Value;
            if (string.IsNullOrWhiteSpace(creds.ClientId) || string.IsNullOrWhiteSpace(creds.ClientSecret))
            {
                SetCredentialState(SyncCredentialState.Unconfigured);
                return null;
            }

            SetCredentialState(SyncCredentialState.Refreshing);
            try
            {
                var endpoint = ResolveTokenEndpoint(creds, clientOptions.Value);
                var http = httpClientFactory.CreateClient(nameof(ClientCredentialsTokenProvider));
                using var response = await http.PostAsJsonAsync(
                    endpoint,
                    new { client_id = creds.ClientId, client_secret = creds.ClientSecret },
                    cancellationToken);
                response.EnsureSuccessStatusCode();
                var payload = await response.Content.ReadFromJsonAsync<TokenPayload>(cancellationToken: cancellationToken)
                    ?? throw new InvalidOperationException("Token endpoint returned an empty body.");

                _accessToken = payload.AccessToken;
                var lifetime = TimeSpan.FromSeconds(Math.Max(30, payload.ExpiresIn - 30));
                _expiresAt = DateTimeOffset.UtcNow.Add(lifetime);
                SetCredentialState(SyncCredentialState.Valid);
                return _accessToken;
            }
            catch
            {
                SetCredentialState(SyncCredentialState.Failed);
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    private void SetCredentialState(SyncCredentialState state)
    {
        lock (_stateGate)
        {
            if (_credentialState == state)
            {
                return;
            }

            _credentialState = state;
        }

        CredentialStateChanged?.Invoke(state);
    }

    private static Uri ResolveTokenEndpoint(SyncClientCredentialOptions creds, SyncClientOptions client)
    {
        if (!string.IsNullOrWhiteSpace(creds.TokenEndpoint))
        {
            if (Uri.TryCreate(creds.TokenEndpoint, UriKind.Absolute, out var absolute))
            {
                return absolute;
            }

            return new Uri(new Uri(client.ServerBaseAddress.TrimEnd('/') + "/"), creds.TokenEndpoint.TrimStart('/'));
        }

        return new Uri(client.ServerBaseAddress.TrimEnd('/') + SyncRoutes.Token);
    }

    private sealed class TokenPayload
    {
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = string.Empty;

        [JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; } = 3600;
    }
}
