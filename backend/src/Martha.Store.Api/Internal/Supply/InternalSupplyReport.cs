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

    public static string Money(long minor) =>
        (minor / 100m).ToString("0.00", CultureInfo.InvariantCulture);

    public static string Escape(string? value)
    {
        var text = value ?? "";
        if (text.IndexOfAny([';', '"', '\r', '\n']) < 0) return text;
        return "\"" + text.Replace("\"", "\"\"") + "\"";
    }

    public static string Row(IEnumerable<string?> cells)
    {
        var builder = new StringBuilder();
        var first = true;
        foreach (var cell in cells)
        {
            if (!first) builder.Append(';');
            builder.Append(Escape(cell));
            first = false;
        }
        return builder.ToString();
    }

    public static string Document(IEnumerable<string> rows)
    {
        var builder = new StringBuilder();
        builder.Append('\uFEFF'); // Byte order mark: spreadsheets read the file as UTF-8.
        foreach (var row in rows) builder.Append(row).Append("\r\n");
        return builder.ToString();
    }
}
