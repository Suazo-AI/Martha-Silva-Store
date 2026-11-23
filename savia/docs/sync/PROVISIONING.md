# Node provisioning (D-040, GAPS G3)

One command, `Savia.Migrator --provision-node`, registers a sync node and manages its credential.
It never applies migrations and never writes to Key Vault.
The secret is printed once; SQL stores only its SHA-256.

## Actions

| Action | Run on | Effect |
| --- | --- | --- |
| `register` | hub database (the hub node) and each store database (the hub node and the store's own node) | Adds a node row. A retry is a no-op. |
| `create` | hub database | Adds the store's node row, then a first credential. Refused if the node already has an active credential. |
| `rotate` | hub database | Replaces the credential. The old secret stops working at once. |
| `revoke` | hub database | The credential stops working (HTTP 401 `sync.unauthorized`). The node row stays. |

`sync.usp_ProvisionNode` (V054) refuses an id or code that already belongs to a different node definition with 51865 `sync.node_mismatch`.
It never re-enables a disabled node.

Rotation has no overlap window: `sync.NodeCredentials` holds one row per node.
Update the store's configuration right after `rotate`; until then the store's rounds get 401 and its sales wait in its own database.

## Steps for a new store

The connection string comes from `Savia__Sql__ConnectionString`, as for migrations.
It is never printed.

1. Provision the store's branch, location and register rows, and its staff, on the hub database and on the store database with the same ids (they are not synced; see V053):

   ```powershell
   dotnet Savia.Migrator.dll --provision-branch --branch-id <branch id> --branch-code <code> --branch-name <name> --store-name <name> `
     --location-id <location id> --location-code <code> --location-name <name> --register-id <register id> --register-code <code> --register-name <name>
   dotnet Savia.Migrator.dll --provision-staff --staff-id <id> --login <login> --display-name <name> --role CASHIER --branch-id <branch id> --set-password
   ```

   `--set-password` takes the password from `SAVIA_STAFF_PASSWORD`, or prints a new one once as `staff-password: <password>`.
   The hub's owner also needs a row on each store database (`--provision-staff` without `--set-password`).
   The full first-day sequence is in [DAY-ZERO.md](../../../docs/production-20261122/DAY-ZERO.md).
2. Once, on the hub database, register the hub's own node; without it the hub refuses every round with `sync.node_unknown`:

   ```powershell
   $env:Savia__Sql__ConnectionString = '<hub database>'
   dotnet Savia.Migrator.dll --provision-node register --node-id <hub node id> --node-kind azure --node-code <hub code>
   ```

   On the store database, register the hub node and the store node:

   ```powershell
   $env:Savia__Sql__ConnectionString = '<store database>'
   dotnet Savia.Migrator.dll --provision-node register --node-id <hub node id> --node-kind azure --node-code <hub code>
   dotnet Savia.Migrator.dll --provision-node register --node-id <store node id> --branch-id <branch id> --node-code <store code>
   ```

3. On the hub database, create the store's node and credential:

   ```powershell
   $env:Savia__Sql__ConnectionString = '<hub database>'
   dotnet Savia.Migrator.dll --provision-node create --node-id <store node id> --branch-id <branch id> --node-code <store code>
   ```

   The last output line is `node-secret: <secret>`.
   Do not paste it into a ticket, chat or log.

4. Put the secret in the operator's Key Vault (the operator runs this; the tool does not):

   ```powershell
   az keyvault secret set --vault-name <vault> --name savia-node-<store code> --value '<secret>'
   ```

5. Configure the store host from protected configuration (a Key Vault reference, or a machine-level environment variable readable only by the service account):

   | Setting | Value |
   | --- | --- |
   | `Savia__Node__Kind` | `Branch` |
   | `Savia__Node__NodeId` | store node id |
   | `Savia__Node__BranchId` | branch id |
   | `Savia__Node__LocationId` | the store's location id |
   | `Savia__Sync__HubUrl` | the hub's HTTPS address |
   | `Savia__Sync__NodeSecret` | the secret from step 3 |

6. Start the store host. Its first round binds the database to the node (`sync.usp_SetLocalNode`).

## Rotate or revoke

```powershell
dotnet Savia.Migrator.dll --provision-node rotate --node-id <store node id>
dotnet Savia.Migrator.dll --provision-node revoke --node-id <store node id>
```

After `rotate`, repeat steps 4 and 5 and restart the store host.

## Evidence

- `db/tests/sync/280_provision_node.sql`: node rows, conflicts (51865), hash-only credential, revoked credential not found.
- `tests/Savia.Tests/NodeProvisioningTests.cs`: argument rules and the secret format.
- `db/tests/security/300_day_zero_provisioning.sql` and `tests/Savia.Tests/SiteProvisioningTests.cs`: `--provision-branch` and `--provision-staff` (V062).
- Day-zero run from empty databases: [day-zero-evidence](../../../docs/production-20261122/day-zero-evidence/).
- Rehearsal: `tools/rehearsal/harness.py` provisions its three stores with this command; the `controls` scenario revokes store B (401), rotates it (new secret 200, old secret 401) and restarts B with the new secret.
