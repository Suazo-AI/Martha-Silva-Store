using System.Globalization;
using System.Text;

namespace Martha.Store.Api.Internal;

// The reception note is the sheet the store keeps by hand: what arrived, what is still missing and
// who signed for it. It is produced from the recorded receipts, never from a second manual count.
// The shape is a semicolon separated file so a spreadsheet opens it with the locale already set,
// and it starts with a byte order mark so accented names survive the round trip.
public static class InternalSupplyReport
{
    public static readonly string[] ReceptionNoteColumns =
    [
        "Fecha", "Orden", "Codigo de barras", "Producto", "Cantidad", "Costo unitario",
        "Total", "Pendiente", "Moneda", "Estado", "Recibido por", "Huella"
    ];

    public static string Money(long minor) => InternalCsv.Money(minor);

    public static string Escape(string? value) => InternalCsv.Escape(value);

    public static string Row(IEnumerable<string?> cells) => InternalCsv.Row(cells);

    public static string Document(IEnumerable<string> rows) => InternalCsv.Document(rows);
}
