namespace SyncEngine.Abstractions.Schema;

public interface ISchemaReader
{
    Task<IReadOnlyList<EntityDescriptor>> ReadEntitiesAsync(CancellationToken cancellationToken = default);
}
