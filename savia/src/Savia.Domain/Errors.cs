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
        [51304] = ("receiving.reason_required", ErrorKind.Validation),
        [51305] = ("receiving.scan_not_resolvable", ErrorKind.Conflict),
        [51306] = ("receiving.code_not_registered", ErrorKind.Conflict),
        [51307] = ("receiving.cannot_approve", ErrorKind.Conflict),
        [51308] = ("receiving.no_scans", ErrorKind.Conflict),
        [51309] = ("receiving.unresolved_codes", ErrorKind.Conflict),
        [51312] = ("receiving.not_approved", ErrorKind.Conflict),
        [51314] = ("receiving.unresolved_codes", ErrorKind.Conflict),
        [51321] = ("receiving.session_id_reused", ErrorKind.Conflict),
        [51324] = ("receiving.container_mismatch", ErrorKind.Conflict),
        [51330] = ("receiving.reason_required", ErrorKind.Validation),
        [51331] = ("receiving.scan_not_found", ErrorKind.NotFound),
        [51332] = ("receiving.session_not_counting", ErrorKind.Conflict),
        [51333] = ("receiving.scan_not_rejectable", ErrorKind.Conflict),
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
        [51545] = ("cash.opening_breakdown", ErrorKind.Validation),
        [51546] = ("stock.confirm_physical", ErrorKind.Conflict),
        [51547] = ("sale.discount_reason", ErrorKind.Validation),
        [51548] = ("stock.exception_not_found", ErrorKind.NotFound),
        [51544] = ("sale.discount_approval_required", ErrorKind.Forbidden),
        [51542] = ("cash.count_id_reused", ErrorKind.Conflict),
        [51543] = ("cash.till_not_open", ErrorKind.Conflict),
        [51607] = ("credit.insufficient", ErrorKind.Conflict),
        [51525] = ("return.empty", ErrorKind.Validation),
        [51526] = ("return.id_reused", ErrorKind.Conflict),
        [51527] = ("return.location", ErrorKind.Forbidden),
        [51528] = ("cash.till_not_open", ErrorKind.Conflict),
        [51529] = ("return.approval_required", ErrorKind.Forbidden),
        [51530] = ("return.customer_or_sale", ErrorKind.Conflict),
        [51531] = ("return.lines", ErrorKind.Validation),
        [51532] = ("return.quantity", ErrorKind.Conflict),
        [51533] = ("return.amount", ErrorKind.Conflict),
        [51534] = ("return.zero_credit", ErrorKind.Conflict),
        [51606] = ("credit.customer_or_currency", ErrorKind.Conflict),
        [52102] = ("sale.fx", ErrorKind.Validation),
        [52103] = ("sale.rate_changed", ErrorKind.Conflict),
        [52104] = ("sale.fx_conversion", ErrorKind.Validation),
        [52105] = ("cash.change_short", ErrorKind.Conflict),
        [52106] = ("cash.parent_required", ErrorKind.Validation),
        [52107] = ("rate.immutable", ErrorKind.Conflict),
        [51900] = ("report.range", ErrorKind.Validation),
        [52001] = ("auth.role_required", ErrorKind.Forbidden),
        [52002] = ("sale.seller_required", ErrorKind.Validation),
        [52003] = ("commission.rate", ErrorKind.Validation),
        [52004] = ("input.id_reused", ErrorKind.Conflict),
        [52005] = ("sale.customer_not_needed", ErrorKind.Validation),
        [52006] = ("receiving.quality", ErrorKind.Validation),
        // V024: shared sales, return outcomes and window, catalog import.
        [52009] = ("sale.too_many_sellers", ErrorKind.Validation),
        [52020] = ("return.outcome", ErrorKind.Validation),
        [52021] = ("return.transfer_reference", ErrorKind.Validation),
        [52022] = ("return.exchange_lines", ErrorKind.Validation),
        [52023] = ("return.window_expired", ErrorKind.Conflict),
        [52024] = ("return.till_cash_short", ErrorKind.Conflict),
        [52025] = ("return.difference_kind", ErrorKind.Validation),
        [52030] = ("import.file", ErrorKind.Validation),
        [52031] = ("import.row_errors", ErrorKind.Conflict),
        [51901] = ("customer.search_too_short", ErrorKind.Validation),
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
        [51733] = ("credit.search_too_short", ErrorKind.Validation),
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
