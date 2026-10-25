using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

// All writes run inside the shared SQL runner's serializable transaction. No local
// cache, provider fallback, transaction commit, seed or identity authority exists here.
public sealed class InternalDirectoryService(InternalDbContext db, IInternalCommandRunner commands)
{
    public async Task<InternalResult<InternalItemView>> SaveItem(Guid? id, InternalItemWrite request, Guid actorId, string key, CancellationToken ct)
    {
        var normalized = InternalDirectoryValidation.Item(request);
        if (!normalized.Success) return InternalResult<InternalItemView>.Fail(normalized.Error!);
        if (!ValidCommand(id, actorId, key)) return InternalResult<InternalItemView>.Fail("invalid_request");
        var value = normalized.Value!;
        return await commands.Run(actorId, id.HasValue ? "directory.items.update" : "directory.items.create", key,
            InternalRules.Fingerprint(new { id, value }), async token =>
            {
                InternalItem? item = id.HasValue ? await db.Set<InternalItem>().SingleOrDefaultAsync(x => x.Id == id.Value, token) : null;
                if (id.HasValue && item is null) return InternalResult<InternalItemView>.Fail("not_found");
                var ownId = id ?? Guid.Empty;
                if (await db.Set<InternalItem>().AnyAsync(x => x.Sku == value.Sku && x.Id != ownId, token))
                    return InternalResult<InternalItemView>.Fail("duplicate_sku");
                if (item is null)
                {
                    item = new InternalItem { Id = Guid.NewGuid() };
                    db.Add(item);
                }
                item.Sku = value.Sku!;
                item.Name = value.Name!;
                item.UnitPriceMinor = value.UnitPriceMinor;
                item.Currency = value.Currency!;
                item.Active = value.Active;
                await db.SaveChangesAsync(token);
                return InternalResult<InternalItemView>.Ok(View(item));
            }, ct);
    }

    public async Task<InternalResult<InternalLocationView>> SaveLocation(Guid? id, InternalLocationWrite request, Guid actorId, string key, CancellationToken ct)
    {
        var normalized = InternalDirectoryValidation.Location(request);
        if (!normalized.Success) return InternalResult<InternalLocationView>.Fail(normalized.Error!);
        if (!ValidCommand(id, actorId, key)) return InternalResult<InternalLocationView>.Fail("invalid_request");
        var value = normalized.Value!;
        return await commands.Run(actorId, id.HasValue ? "directory.locations.update" : "directory.locations.create", key,
            InternalRules.Fingerprint(new { id, value }), async token =>
            {
                InternalLocation? location = id.HasValue ? await db.Set<InternalLocation>().SingleOrDefaultAsync(x => x.Id == id.Value, token) : null;
                if (id.HasValue && location is null) return InternalResult<InternalLocationView>.Fail("not_found");
                if (location is null)
                {
                    location = new InternalLocation { Id = Guid.NewGuid() };
                    db.Add(location);
                }
                location.Name = value.Name!;
                location.Active = value.Active;
                await db.SaveChangesAsync(token);
                return InternalResult<InternalLocationView>.Ok(View(location));
            }, ct);
    }

    public async Task<InternalResult<InternalPartyView>> SaveParty(Guid? id, InternalPartyWrite request, Guid actorId, string key, CancellationToken ct)
    {
        var normalized = InternalDirectoryValidation.Party(request);
        if (!normalized.Success) return InternalResult<InternalPartyView>.Fail(normalized.Error!);
        if (!ValidCommand(id, actorId, key)) return InternalResult<InternalPartyView>.Fail("invalid_request");
        var value = normalized.Value!;
        return await commands.Run(actorId, id.HasValue ? "directory.parties.update" : "directory.parties.create", key,
            InternalRules.Fingerprint(new { id, value }), async token =>
            {
                InternalParty? party = id.HasValue ? await db.Set<InternalParty>().SingleOrDefaultAsync(x => x.Id == id.Value, token) : null;
                if (id.HasValue && party is null) return InternalResult<InternalPartyView>.Fail("not_found");
                // A referenced supplier/customer may not change meaning under an old
                // sale or purchase order. Create a separate party for another role.
                if (party is not null && party.Kind != value.Kind) return InternalResult<InternalPartyView>.Fail("party_kind_immutable");
                if (party is null)
                {
                    party = new InternalParty { Id = Guid.NewGuid(), Kind = value.Kind! };
                    db.Add(party);
                }
                party.Name = value.Name!;
                party.Email = value.Email;
                party.Phone = value.Phone;
                party.Active = value.Active;
                await db.SaveChangesAsync(token);
                return InternalResult<InternalPartyView>.Ok(View(party));
            }, ct);
    }

    public Task<InternalResult<InternalItemView>> DeactivateItem(Guid id, Guid actorId, string key, CancellationToken ct) =>
        Deactivate<InternalItem, InternalItemView>(id, actorId, key, "items", x => x.Active = false, View, ct);
    public Task<InternalResult<InternalLocationView>> DeactivateLocation(Guid id, Guid actorId, string key, CancellationToken ct) =>
        Deactivate<InternalLocation, InternalLocationView>(id, actorId, key, "locations", x => x.Active = false, View, ct);
    public Task<InternalResult<InternalPartyView>> DeactivateParty(Guid id, Guid actorId, string key, CancellationToken ct) =>
        Deactivate<InternalParty, InternalPartyView>(id, actorId, key, "parties", x => x.Active = false, View, ct);

    private async Task<InternalResult<TView>> Deactivate<TEntity, TView>(Guid id, Guid actorId, string key, string scope,
        Action<TEntity> deactivate, Func<TEntity, TView> view, CancellationToken ct) where TEntity : class
    {
        if (!ValidCommand(id, actorId, key)) return InternalResult<TView>.Fail("invalid_request");
        return await commands.Run(actorId, $"directory.{scope}.deactivate", key, InternalRules.Fingerprint(new { id }), async token =>
        {
            var entity = await db.Set<TEntity>().FindAsync([id], token);
            if (entity is null) return InternalResult<TView>.Fail("not_found");
            deactivate(entity);
            await db.SaveChangesAsync(token);
            return InternalResult<TView>.Ok(view(entity));
        }, ct);
    }

    private static bool ValidCommand(Guid? id, Guid actorId, string key) =>
        id != Guid.Empty && actorId != Guid.Empty && InternalRules.ValidKey(key);

    public static InternalItemView View(InternalItem item) => new(item.Id, item.Sku, item.Name, item.UnitPriceMinor, item.Currency, item.Active);
    public static InternalLocationView View(InternalLocation location) => new(location.Id, location.Name, location.Active);
    public static InternalPartyView View(InternalParty party) => new(party.Id, party.Kind, party.Name, party.Email, party.Phone, party.Active);
}
