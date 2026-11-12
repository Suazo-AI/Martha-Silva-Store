namespace Savia.Domain;

/// <summary>How an error is reported to a client. The API maps each kind to one HTTP status.</summary>
public enum ErrorKind { Validation, Unauthorized, Forbidden, NotFound, Conflict, Unavailable, Internal }

/// <summary>A stable, client-visible error. <see cref="Code"/> never changes once published.</summary>
public sealed record SaviaError(string Code, ErrorKind Kind, string Message);

public sealed class SaviaException(SaviaError error, Exception? inner = null) : Exception(error.Message, inner)
{
    public SaviaError Error { get; } = error;
}

public static class Errors
{
    public static readonly SaviaError Unauthorized = new("auth.required", ErrorKind.Unauthorized, "Inicie sesión.");
    public static readonly SaviaError BadCredentials = new("auth.bad_credentials", ErrorKind.Unauthorized, "Usuario o contraseña incorrectos.");
    public static readonly SaviaError RoleRequired = new("auth.role_required", ErrorKind.Forbidden, "Su rol no permite esta operación.");
    public static readonly SaviaError BranchAccess = new("auth.branch_access", ErrorKind.Forbidden, "No tiene acceso a esta sucursal.");
    public static readonly SaviaError WrongNode = new("node.wrong_kind", ErrorKind.NotFound, "Esta operación no existe en este nodo.");

    public static SaviaException Invalid(string code, string message) => new(new SaviaError(code, ErrorKind.Validation, message));
    public static SaviaException NotFound(string code, string message) => new(new SaviaError(code, ErrorKind.NotFound, message));
}

/// <summary>
/// Business rules live in SQL procedures (ADR-001 D2). They reject with THROW 5xxxx.
/// This catalog turns those numbers into stable API codes. It adds no rule of its own.
/// </summary>
public static class DbErrors
{
    private static readonly Dictionary<int, (string Code, ErrorKind Kind)> Known = new()
    {
        [51102] = ("stock.insufficient", ErrorKind.Conflict),
        [51103] = ("stock.pool_frozen", ErrorKind.Conflict),
        [51107] = ("inventory.approver_branch_access", ErrorKind.Forbidden),
        [51204] = ("catalog.code_taken", ErrorKind.Conflict),
        [51205] = ("catalog.code_taken", ErrorKind.Conflict),
        [51211] = ("catalog.item_id_reused", ErrorKind.Conflict),
        [51212] = ("catalog.sku_taken", ErrorKind.Conflict),
        [51302] = ("receiving.scan_id_reused", ErrorKind.Conflict),
        [51303] = ("receiving.session_not_open", ErrorKind.Conflict),
        [51307] = ("receiving.cannot_approve", ErrorKind.Conflict),
        [51308] = ("receiving.no_scans", ErrorKind.Conflict),
        [51309] = ("receiving.unresolved_codes", ErrorKind.Conflict),
        [51312] = ("receiving.not_approved", ErrorKind.Conflict),
        [51314] = ("receiving.unresolved_codes", ErrorKind.Conflict),
        [51321] = ("receiving.session_id_reused", ErrorKind.Conflict),
        [51324] = ("receiving.container_mismatch", ErrorKind.Conflict),
        [51502] = ("cash.till_id_reused", ErrorKind.Conflict),
        [51504] = ("auth.branch_access", ErrorKind.Forbidden),
        [51506] = ("cash.till_not_open", ErrorKind.Conflict),
        [51510] = ("sale.id_reused", ErrorKind.Conflict),
        [51512] = ("auth.branch_access", ErrorKind.Forbidden),
        [51513] = ("sale.price_changed", ErrorKind.Conflict),
        [51515] = ("cash.till_mismatch", ErrorKind.Conflict),
        [51517] = ("sale.tender_mismatch", ErrorKind.Validation),
        [51520] = ("cash.till_not_open", ErrorKind.Conflict),
        [51521] = ("cash.already_closed", ErrorKind.Conflict),
        [51522] = ("cash.till_not_open", ErrorKind.Conflict),
        [51523] = ("cash.count_missing", ErrorKind.Conflict),
        [51535] = ("auth.branch_access", ErrorKind.Forbidden),
        [51536] = ("cash.entry_id_reused", ErrorKind.Conflict),
        [51537] = ("auth.branch_access", ErrorKind.Forbidden),
        [51538] = ("sale.reversal_id_reused", ErrorKind.Conflict),
        [51542] = ("cash.count_id_reused", ErrorKind.Conflict),
        [51543] = ("cash.till_not_open", ErrorKind.Conflict),
        [51607] = ("credit.insufficient", ErrorKind.Conflict),
        // V009: credit transfer as transition rows, one writer per row.
        [51719] = ("credit.transfer_retired", ErrorKind.NotFound),
        [51720] = ("credit.transfer_invalid", ErrorKind.Validation),
        [51721] = ("credit.transfer_id_reused", ErrorKind.Conflict),
        [51722] = ("credit.transfer_no_balance", ErrorKind.Conflict),
        [51723] = ("node.wrong_kind", ErrorKind.NotFound),
        [51724] = ("auth.branch_access", ErrorKind.Forbidden),
        [51725] = ("credit.transfer_not_found", ErrorKind.NotFound),
        [51726] = ("credit.transfer_cancelled", ErrorKind.Conflict),
        [51727] = ("credit.transfer_approver", ErrorKind.Forbidden),
        [51728] = ("credit.transfer_not_approved", ErrorKind.Conflict),
        [51729] = ("credit.insufficient", ErrorKind.Conflict),
        [51730] = ("credit.transfer_not_dispatched", ErrorKind.Conflict),
        [51731] = ("credit.transfer_already_dispatched", ErrorKind.Conflict),
        [51732] = ("credit.allocation_inactive", ErrorKind.Conflict),
        // V008: sync foundation.
        [51806] = ("sync.local_node_taken", ErrorKind.Conflict),
        [51807] = ("sync.node_unknown", ErrorKind.NotFound),
        [51808] = ("sync.cursor_invalid", ErrorKind.Conflict),
        [51809] = ("sync.table_not_tracked", ErrorKind.Validation),
    };

    /// <param name="number">SQL Server error number.</param>
    /// <param name="message">SQL Server message. Shown only for business rejections (5xxxx).</param>
    public static SaviaError FromSql(int number, string message)
    {
        if (Known.TryGetValue(number, out var known)) return new(known.Code, known.Kind, message);
        return number switch
        {
            >= 50000 and <= 59999 => new($"rule.{number}", ErrorKind.Validation, message),
            2601 or 2627 => new("db.duplicate", ErrorKind.Conflict, "El registro ya existe."),
            547 => new("db.reference", ErrorKind.Conflict, "El registro referencia datos que no existen."),
            1205 or -2 => new("db.busy", ErrorKind.Unavailable, "La base de datos está ocupada. Reintente."),
            _ => new("db.error", ErrorKind.Internal, "Error interno de base de datos."),
        };
    }
}
