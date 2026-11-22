# Node provisioning (D-040, GAPS G3)

One command, `Savia.Migrator --provision-node`, registers a sync node and manages its credential.
It never applies migrations and never writes to Key Vault.
The secret is printed once; SQL stores only its SHA-256.

## Actions

| Action | Run on | Effect |
| --- | --- | --- |
| `register` | each store database | Adds a node row (the hub node, and the store's own node). A retry is a no-op. |
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

1. Provision the store's branch, location and register rows on every database with the same ids (they are not synced; see V053).
2. On the store database, register the hub node and the store node:

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
- Rehearsal: `tools/rehearsal/harness.py` provisions its three stores with this command; the `controls` scenario revokes store B (401), rotates it (new secret 200, old secret 401) and restarts B with the new secret.
