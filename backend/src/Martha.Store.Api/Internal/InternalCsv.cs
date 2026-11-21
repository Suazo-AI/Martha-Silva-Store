using System.Globalization;
using System.Text;

namespace Martha.Store.Api.Internal;

// Shared shape for the sheets the store takes out of the system. Semicolon separated so the
// spreadsheet opens it with the locale already set, quoted when a value could break the row, and
// a byte order mark so accented names survive the round trip.
public static class InternalCsv
{
    public static string Money(long minor, int exponent = 2) =>
        (minor / Math.Pow(10, exponent)).ToString("0.00", CultureInfo.InvariantCulture);

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
        builder.Append('﻿');
        foreach (var row in rows) builder.Append(row).Append("\r\n");
        return builder.ToString();
    }
}
