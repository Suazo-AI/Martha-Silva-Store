namespace Martha.Store.Api.Internal;

// The closing report is what the store hands to the accountant: per till and per day, what was
// sold, what was refunded, what the system expected in the drawer, what was counted and the
// difference. It reads only recorded movements and closes; it never changes anything.
public static class InternalCashReport
{
    public static readonly string[] ClosingReportColumns =
    [
        "Tipo", "Fecha", "Caja", "Sucursal", "Moneda", "Apertura", "Ventas", "Devoluciones",
        "Esperado", "Contado", "Diferencia", "Estado", "Cerró", "Cajero"
    ];
}
