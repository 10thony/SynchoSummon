using SyncEngine.Abstractions.Client;

namespace SyncEngine.Abstractions.Auth;

/// <summary>
/// Optional credential lifecycle surface. Token providers may implement this alongside
/// <see cref="ISyncCredentialProvider"/> so sessions can surface auth failures distinctly.
/// </summary>
public interface ISyncCredentialStatus
{
    SyncCredentialState CredentialState { get; }

    event Action<SyncCredentialState>? CredentialStateChanged;
}
