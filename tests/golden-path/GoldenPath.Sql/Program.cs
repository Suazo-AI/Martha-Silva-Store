// Herramienta del arnés del camino dorado (C5). Solo pruebas: nunca imprime la conexión, contraseñas ni mensajes
// del servidor. Cada comando escribe una línea JSON en stdout con conteos y nombres; los errores salen como tipo/número.
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.RegularExpressions;
using Martha.Store.Api.Internal;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

try
{
    return args switch
    {
        ["cert", var dir] => Cert(dir),
        ["create", var db] => await Create(db),
        ["branch", var db, var id] => await Branch(db, Guid.Parse(id)),
        ["oracles", var db] => await Oracles(db),
        ["receipt-identity", var db, var receipt, var actor, var order, var location, var item, var key, var quantity] =>
            await ReceiptIdentity(db, Guid.Parse(receipt), Guid.Parse(actor), Guid.Parse(order), Guid.Parse(location), Guid.Parse(item), Guid.Parse(key), int.Parse(quantity)),
        ["stock-identity", var db, var sale, var actor, var item, var location, var key, var reviewer, var reviewKey] =>
            await StockIdentity(db, Guid.Parse(sale), Guid.Parse(actor), Guid.Parse(item), Guid.Parse(location), Guid.Parse(key), Guid.Parse(reviewer), Guid.Parse(reviewKey)),
        ["exists", var db] => await Exists(db),
        ["drop", var db] => await Drop(db),
        _ => Fail("usage", "cert <dir> | create|oracles|exists|drop <db> | branch <db> <guid>")
    };
}
catch (Exception ex)
{
    // Messages may echo server names or values; report only the type and, for SQL, the error number.
    return ex is Refusal refusal ? Fail("refused", refusal.Message)
        : Fail(ex.GetType().Name, ex is SqlException sql ? $"sql_error_{sql.Number}" : "see_private_logs");
}

static int Fail(string error, string detail)
{
    Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error, detail }));
    return 1;
}

static int Ok(object value)
{
    Console.WriteLine(JsonSerializer.Serialize(value));
    return 0;
}

// Stricter than the product guard (SaviaInternalTest_*): only names this harness generates.
static string Guarded(string database)
{
    if (!Regex.IsMatch(database, @"\ASaviaInternalTest_Golden_[a-f0-9]{32}\z"))
        throw new Refusal("database_name_not_golden_disposable");
    return database;
}

static string Connection(string database)
{
    var supplied = Environment.GetEnvironmentVariable("MARTHA_TEST_SQL_CONNECTION");
    if (string.IsNullOrWhiteSpace(supplied)) throw new Refusal("missing_MARTHA_TEST_SQL_CONNECTION");
    var builder = new SqlConnectionStringBuilder(supplied)
    { InitialCatalog = database, Pooling = false, MultipleActiveResultSets = false };
    if (database != "master")
    {
        Guarded(database);
        InternalDatabaseGuard.Validate(builder.ConnectionString); // Same guard the API applies.
    }
    return builder.ConnectionString;
}

static InternalDbContext Context(string database) => new(new DbContextOptionsBuilder<InternalDbContext>()
    .UseSqlServer(Connection(database), sql => sql.CommandTimeout(60)).Options);

static async Task<bool> DatabaseExists(string database)
{
    await using var connection = new SqlConnection(Connection("master"));
    await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandText = "SELECT COUNT(*) FROM sys.databases WHERE name = @name";
    command.Parameters.AddWithValue("@name", database);
    return Convert.ToInt32(await command.ExecuteScalarAsync()) == 1;
}

static int Cert(string directory)
{
    Directory.CreateDirectory(directory);
    using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    var request = new CertificateRequest("CN=SAVIA golden path loopback (synthetic)", key, HashAlgorithmName.SHA256);
    var san = new SubjectAlternativeNameBuilder();
    san.AddIpAddress(System.Net.IPAddress.Loopback);
    san.AddDnsName("localhost");
    request.CertificateExtensions.Add(san.Build());
    request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
    request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature, true));
    request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension([new Oid("1.3.6.1.5.5.7.3.1")], false));
    var now = DateTimeOffset.UtcNow;
    using var certificate = request.CreateSelfSigned(now.AddMinutes(-5), now.AddDays(1));
    var keyPath = Path.Combine(directory, "key.pem");
    var certPath = Path.Combine(directory, "cert.pem");
    // Create the key file private before writing any key material.
    var options = new FileStreamOptions { Mode = FileMode.CreateNew, Access = FileAccess.Write };
    if (!OperatingSystem.IsWindows()) options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
    using (var stream = new FileStream(keyPath, options))
    using (var writer = new StreamWriter(stream)) writer.Write(key.ExportPkcs8PrivateKeyPem());
    File.WriteAllText(certPath, certificate.ExportCertificatePem());
    return Ok(new { ok = true, cert = "cert.pem", sha256 = certificate.GetCertHashString(HashAlgorithmName.SHA256) });
}

static async Task<int> Create(string database)
{
    Guarded(database);
    if (await DatabaseExists(database)) throw new Refusal("database_already_exists");
    await using var db = Context(database);
    // Release path: the real EF migrator (as PrivatePilotReleaseTests), never EnsureCreated.
    var migrator = db.GetService<IMigrator>();
    await migrator.MigrateAsync();
    var applied = (await db.Database.GetAppliedMigrationsAsync()).ToArray();
    var pending = (await db.Database.GetPendingMigrationsAsync()).ToArray();
    var known = db.Database.GetMigrations().ToArray();
    var staff = await db.InternalStaff.CountAsync();
    return Ok(new { ok = pending.Length == 0 && applied.SequenceEqual(known) && staff == 0,
        applied, pending = pending.Length, known = known.Length, staff, method = "IMigrator.MigrateAsync" });
}

static async Task<int> Branch(string database, Guid id)
{
    // No HTTP endpoint creates branches in this candidate; insert through the product's EF entity.
    await using var db = Context(database);
    if (await db.Set<InternalBranch>().AnyAsync()) throw new Refusal("branch_already_exists");
    db.Set<InternalBranch>().Add(new InternalBranch { Id = id, Name = "SINTETICO Golden sucursal", Active = true });
    await db.SaveChangesAsync();
    return Ok(new { ok = true, branches = await db.Set<InternalBranch>().CountAsync() });
}

static async Task<int> Exists(string database)
{
    Guarded(database);
    return Ok(new { ok = true, exists = await DatabaseExists(database) });
}

static async Task<int> Drop(string database)
{
    Guarded(database);
    if (await DatabaseExists(database))
    {
        await using var connection = new SqlConnection(Connection("master"));
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        // Name already matched the strict generated pattern above; brackets are safe for [a-zA-Z0-9_].
        command.CommandText = $"ALTER DATABASE [{database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{database}];";
        command.CommandTimeout = 60;
        await command.ExecuteNonQueryAsync();
    }
    var after = await DatabaseExists(database);
    return Ok(new { ok = !after, existsAfter = after });
}

static async Task<int> Oracles(string database)
{
    await using var connection = new SqlConnection(Connection(database));
    await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandTimeout = 60;
    command.CommandText = """
        SET NOCOUNT ON;
        SELECT
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrders) AS purchase_orders,
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrderLines) AS purchase_lines,
          (SELECT ISNULL(SUM(Quantity),0) FROM savia_internal.PurchaseOrderLines) AS purchase_quantity,
          (SELECT ISNULL(SUM(ReceivedQuantity),0) FROM savia_internal.PurchaseOrderLines) AS purchase_received,
          (SELECT ISNULL(SUM(TotalMinor),0) FROM savia_internal.PurchaseOrders) AS purchase_total,
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrders WHERE Status='open') AS purchase_open,
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrders WHERE Status='partially_received') AS purchase_partial,
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrders WHERE Status='received') AS purchase_complete,
          (SELECT COUNT(*) FROM savia_internal.PurchaseReceipts) AS purchase_receipts,
          (SELECT COUNT(*) FROM savia_internal.PurchaseReceiptLines) AS purchase_receipt_lines,
          (SELECT ISNULL(SUM(TotalMinor),0) FROM savia_internal.PurchaseReceipts) AS purchase_receipt_total,
          (SELECT COUNT(*) FROM savia_internal.StockMovements WHERE Kind='purchase_receipt') AS purchase_movements,
          (SELECT COUNT(*) FROM savia_internal.Operations WHERE Scope='supply.purchase.create') AS purchase_operations,
          (SELECT COUNT(*) FROM savia_internal.Operations WHERE Scope='supply.receipt.create') AS receipt_operations,
          (SELECT COUNT(*) FROM savia_internal.PurchaseReceiptLines l JOIN savia_internal.PurchaseReceipts r ON r.Id=l.ReceiptId
             WHERE (SELECT COUNT(*) FROM savia_internal.StockMovements m WHERE m.OperationId=r.Id AND m.Kind='purchase_receipt'
               AND m.ItemId=l.ItemId AND m.LocationId=r.LocationId AND m.ActorId=r.ReceivedBy
               AND m.OnHandDelta=l.Quantity AND m.ReservedDelta=0) <> 1) AS receipt_movement_mismatch,
          (SELECT COUNT(*) FROM savia_internal.StockMovements m WHERE m.Kind='purchase_receipt' AND NOT EXISTS
             (SELECT 1 FROM savia_internal.PurchaseReceiptLines l WHERE l.ReceiptId=m.OperationId AND l.ItemId=m.ItemId)) AS orphan_receipt_movement,
          (SELECT COUNT(*) FROM savia_internal.PurchaseOrderLines l WHERE l.ReceivedQuantity <>
             ISNULL((SELECT SUM(r.Quantity) FROM savia_internal.PurchaseReceiptLines r WHERE r.PurchaseOrderLineId=l.Id),0)) AS receipt_order_mismatch,
          (SELECT COUNT(*) FROM savia_internal.SaleLines WHERE ExceptionReason IS NOT NULL) AS exception_lines,
          (SELECT COUNT(*) FROM savia_internal.StockExceptionReviews) AS stock_reviews,
          (SELECT COUNT(*) FROM savia_internal.StockMovements m JOIN savia_internal.SaleLines l ON l.SaleId=m.OperationId AND l.ItemId=m.ItemId WHERE l.ExceptionReason IS NOT NULL AND m.Kind='sale') AS exception_movements,
          (SELECT COUNT(*) FROM savia_internal.Sales) AS sales,
          (SELECT COUNT(*) FROM savia_internal.SaleLines) AS sale_lines,
          (SELECT COUNT(*) FROM savia_internal.StockMovements) AS movements,
          (SELECT COUNT(*) FROM savia_internal.StockMovements WHERE Kind = 'sale') AS sale_movements,
          (SELECT COUNT(*) FROM savia_internal.StockAdjustments) AS adjustments,
          (SELECT COUNT(*) FROM savia_internal.SaleLines l
             WHERE l.ExceptionReason IS NULL AND (SELECT COUNT(*) FROM savia_internal.StockMovements m
                    WHERE m.OperationId = l.SaleId AND m.ItemId = l.ItemId AND m.Kind = 'sale') <> 1) AS lines_without_exactly_one_movement,
          (SELECT COUNT(*) FROM savia_internal.StockMovements m
             WHERE m.Kind = 'sale' AND NOT EXISTS (SELECT 1 FROM savia_internal.SaleLines l
                    WHERE l.SaleId = m.OperationId AND l.ItemId = m.ItemId AND -m.OnHandDelta = l.Quantity)) AS sale_movements_not_matching_a_line,
          (SELECT COUNT(*) FROM savia_internal.StockBalances b
             WHERE b.OnHand <> ISNULL((SELECT SUM(m.OnHandDelta) FROM savia_internal.StockMovements m
                                       WHERE m.ItemId = b.ItemId AND m.LocationId = b.LocationId), 0)
                OR b.Reserved <> ISNULL((SELECT SUM(m.ReservedDelta) FROM savia_internal.StockMovements m
                                       WHERE m.ItemId = b.ItemId AND m.LocationId = b.LocationId), 0)) AS balance_vs_movement_sum_mismatch,
          (SELECT COUNT(*) FROM savia_internal.StockBalances b
             WHERE EXISTS (SELECT 1 FROM savia_internal.StockMovements m WHERE m.ItemId = b.ItemId AND m.LocationId = b.LocationId)
               AND b.OnHand <> (SELECT TOP 1 m.OnHandAfter FROM savia_internal.StockMovements m
                                WHERE m.ItemId = b.ItemId AND m.LocationId = b.LocationId
                                ORDER BY m.CreatedAt DESC, m.OnHandAfter)) AS balance_vs_last_movement_mismatch,
          (SELECT COUNT(*) FROM savia_internal.StockBalances WHERE OnHand < 0 OR Reserved < 0 OR Reserved > OnHand) AS negative_or_invalid_stock,
          (SELECT COUNT(*) FROM savia_internal.StockMovements WHERE OnHandAfter < 0 OR ReservedAfter < 0) AS negative_movement_after,
          (SELECT COUNT(*) FROM (SELECT ActorId, Scope, [Key] FROM savia_internal.Operations
                                 GROUP BY ActorId, Scope, [Key] HAVING COUNT(*) > 1) d) AS duplicate_idempotency_keys,
          (SELECT COUNT(*) FROM savia_internal.Operations) AS operations,
          (SELECT COUNT(*) FROM savia_internal.Operations WHERE Scope = 'commerce.sale.record') AS sale_operations,
          (SELECT ISNULL(SUM(OnHand), 0) FROM savia_internal.StockBalances) AS on_hand_total,
          (SELECT COUNT(*) FROM savia_internal.StockBalances) AS balances,
          (SELECT COUNT(*) FROM savia_internal.Staff) AS staff,
          (SELECT COUNT(*) FROM savia_internal.Staff WHERE Role <> 'Owner' AND BranchId IS NULL) AS unassigned_staff,
          (SELECT COUNT(*) FROM savia_internal.Branches) AS branches,
          (SELECT COUNT(*) FROM savia_internal.Locations) AS locations,
          (SELECT COUNT(*) FROM savia_internal.Items) AS items,
          (SELECT COUNT(*) FROM savia_internal.Items WHERE Sku NOT LIKE 'SINTETICO-GOLDEN-%') AS items_without_synthetic_marker,
          (SELECT COUNT(*) FROM savia_internal.Sessions WHERE RevokedAt IS NULL AND ExpiresAt > SYSDATETIMEOFFSET()) AS active_sessions,
          (SELECT COUNT(*) FROM savia_internal.Sessions s JOIN savia_internal.Staff st ON st.Id = s.StaffId
             WHERE st.Role = 'Cashier' AND st.BranchId IS NOT NULL AND s.RevokedAt IS NULL AND s.ExpiresAt > SYSDATETIMEOFFSET()) AS cashier_active_sessions,
          (SELECT COUNT(*) FROM dbo.__EFMigrationsHistory) AS migrations_applied;
        """;
    await using var reader = await command.ExecuteReaderAsync();
    if (!await reader.ReadAsync()) throw new Refusal("no_oracle_row");
    var result = new SortedDictionary<string, long>(StringComparer.Ordinal);
    for (var i = 0; i < reader.FieldCount; i++) result[reader.GetName(i)] = Convert.ToInt64(reader.GetValue(i));
    return Ok(new { ok = true, counts = result });
}

// Exact identity readback, parameterized, counts only. No raw SQL rows leave this process.
static async Task<int> ReceiptIdentity(string database, Guid receipt, Guid actor, Guid order, Guid location, Guid item, Guid key, int quantity)
{
    await using var connection = new SqlConnection(Connection(database));
    await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandText = """
        SELECT COUNT(*) FROM savia_internal.PurchaseReceipts r
        JOIN savia_internal.PurchaseReceiptLines l ON l.ReceiptId=r.Id
        JOIN savia_internal.StockMovements m ON m.OperationId=r.Id AND m.Kind='purchase_receipt'
          AND m.ItemId=l.ItemId AND m.LocationId=r.LocationId AND m.ActorId=r.ReceivedBy AND m.OnHandDelta=l.Quantity
        JOIN savia_internal.PurchaseOrders o ON o.Id=r.PurchaseOrderId
        JOIN savia_internal.Operations op ON op.ActorId=r.ReceivedBy AND op.Scope='supply.receipt.create'
          AND op.[Key]=@key AND op.LocationId=r.LocationId AND JSON_VALUE(op.ResultJson,'$.success')='true'
          AND JSON_VALUE(op.ResultJson,'$.value.id')=CONVERT(nvarchar(36),r.Id)
        WHERE r.Id=@receipt AND r.ReceivedBy=@actor AND r.PurchaseOrderId=@order AND r.LocationId=@location
          AND l.ItemId=@item AND o.LocationId=@location AND o.UpdatedBy=@actor
          AND l.Quantity=@quantity AND l.UnitCostMinor=700 AND r.TotalMinor=@quantity*700
          AND r.OrderStatusAfter=CASE WHEN @quantity=2 THEN 'partially_received' ELSE 'received' END
        """;
    foreach (var pair in new[] { ("@receipt", receipt), ("@actor", actor), ("@order", order), ("@location", location), ("@item", item) })
        command.Parameters.AddWithValue(pair.Item1, pair.Item2);
    command.Parameters.AddWithValue("@key", key.ToString());
    command.Parameters.AddWithValue("@quantity", quantity);
    return Ok(new { ok = true, matches = Convert.ToInt32(await command.ExecuteScalarAsync()) });
}

static async Task<int> StockIdentity(string database, Guid sale, Guid actor, Guid item, Guid location, Guid key, Guid reviewer, Guid reviewKey)
{
    await using var connection = new SqlConnection(Connection(database)); await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandText = """
      SELECT
       (SELECT COUNT(*) FROM savia_internal.Sales s JOIN savia_internal.SaleLines l ON l.SaleId=s.Id
        JOIN savia_internal.Operations op ON op.ActorId=s.ActorId AND op.Scope='commerce.sale.record' AND op.[Key]=@key
          AND JSON_VALUE(op.ResultJson,'$.value.saleId')=CONVERT(nvarchar(36),s.Id)
        WHERE s.Id=@sale AND s.ActorId=@actor AND s.LocationId=@location AND l.ItemId=@item
          AND l.Quantity=1 AND l.ReturnedQuantity=0 AND l.Size='S' AND l.ExceptionReason='SINTETICO physical garment present'
          AND s.TotalMinor=1250 AND l.TotalMinor=1250 AND l.UnitPriceMinor=1250
          AND NOT EXISTS(SELECT 1 FROM savia_internal.StockMovements m WHERE m.OperationId=s.Id)
          AND NOT EXISTS(SELECT 1 FROM savia_internal.StockBalances b WHERE b.ItemId=@item AND b.LocationId=@location AND (b.OnHand<>0 OR b.Reserved<>0))) AS allocation_matches,
       (SELECT COUNT(*) FROM savia_internal.StockExceptionReviews r
        JOIN savia_internal.SaleLines l ON l.Id=r.SaleLineId
        JOIN savia_internal.Sales s ON s.Id=l.SaleId
        JOIN savia_internal.Operations op ON op.ActorId=r.ReviewerId AND op.Scope='commerce.stock.review' AND op.[Key]=@reviewKey
          AND JSON_VALUE(op.ResultJson,'$.value.id')=CONVERT(nvarchar(36),r.Id)
        WHERE s.Id=@sale AND r.ReviewerId=@reviewer AND r.ReviewerId<>s.ActorId AND r.CauseState='open'
          AND r.ResponsibleActorId=@reviewer AND r.NextReviewAt>r.CreatedAt
          AND r.Evidence='SINTETICO sale and physical count examined'
          AND r.Outcome='SINTETICO cause unproven; follow up') AS review_matches
      """;
    foreach(var pair in new[]{("@sale",sale),("@actor",actor),("@item",item),("@location",location),("@reviewer",reviewer)}) command.Parameters.AddWithValue(pair.Item1,pair.Item2);
    command.Parameters.AddWithValue("@key",key.ToString());command.Parameters.AddWithValue("@reviewKey",reviewKey.ToString());
    await using var reader=await command.ExecuteReaderAsync();await reader.ReadAsync();
    return Ok(new {ok=true,allocation_matches=reader.GetInt32(0),review_matches=reader.GetInt32(1)});
}

// Refusals carry only fixed codes written above, never server or request text.
sealed class Refusal(string code) : Exception(code);
