using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml.Linq;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

/// <summary>
/// Reads a catalog export as a table of text cells. CSV (comma, semicolon or tab) or XLSX.
/// XLSX is a ZIP of XML parts; it is read with the built-in System.IO.Compression and System.Xml.Linq.
/// No row rule lives here: SQL validates every cell.
/// </summary>
public static class CatalogFile
{
    public const int MaxBytes = 5 * 1024 * 1024;
    public const int MaxRows = 5000;
    private const long MaxPartBytes = 40L * 1024 * 1024;

    public static ImportFile Parse(string fileName, byte[] content)
    {
        if (content.Length == 0 || content.Length > MaxBytes) throw Errors.Invalid("import.size", "El archivo debe pesar entre 1 byte y 5 MB.");
        var table = Path.GetExtension(fileName).ToLowerInvariant() switch
        {
            ".csv" or ".txt" => Csv(content),
            ".xlsx" => Xlsx(content),
            _ => throw Errors.Invalid("import.format", "Use un archivo CSV o XLSX."),
        };
        var rows = table.Where(r => r.Any(c => c.Length > 0)).ToList();
        if (rows.Count < 2) throw Errors.Invalid("import.empty", "El archivo necesita una fila de encabezados y al menos una fila de datos.");
        if (rows.Count - 1 > MaxRows) throw Errors.Invalid("import.size", $"El archivo admite hasta {MaxRows} filas.");
        var width = rows.Max(r => r.Count);
        var headers = Enumerable.Range(0, width).Select(i => i < rows[0].Count && rows[0][i].Length > 0 ? rows[0][i] : $"Columna {i + 1}").ToArray();
        var data = rows.Skip(1).Select(r => Enumerable.Range(0, width).Select(i => i < r.Count ? r[i] : "").ToArray()).ToArray();
        return new ImportFile(fileName, headers, data);
    }

    private static string Decode(byte[] content)
    {
        try { return new UTF8Encoding(false, true).GetString(content).TrimStart('﻿'); }
        catch (DecoderFallbackException) { return Encoding.Latin1.GetString(content); }
    }

    public static List<List<string>> Csv(byte[] content)
    {
        var text = Decode(content);
        var firstLine = text.Split('\n', 2)[0];
        var delimiter = new[] { ';', '\t', ',' }.OrderByDescending(d => firstLine.Count(c => c == d)).First();
        var rows = new List<List<string>>();
        var row = new List<string>();
        var cell = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (quoted)
            {
                if (c == '"' && i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; }
                else if (c == '"') quoted = false;
                else cell.Append(c);
            }
            else if (c == '"' && cell.Length == 0) quoted = true;
            else if (c == delimiter) { row.Add(cell.ToString().Trim()); cell.Clear(); }
            else if (c == '\n' || c == '\r')
            {
                if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                row.Add(cell.ToString().Trim()); cell.Clear(); rows.Add(row); row = [];
            }
            else cell.Append(c);
        }
        if (quoted) throw Errors.Invalid("import.format", "El CSV tiene comillas sin cerrar.");
        if (cell.Length > 0 || row.Count > 0) { row.Add(cell.ToString().Trim()); rows.Add(row); }
        return rows;
    }

    public static List<List<string>> Xlsx(byte[] content)
    {
        try
        {
            using var zip = new ZipArchive(new MemoryStream(content), ZipArchiveMode.Read);
            XDocument Part(string name)
            {
                var entry = zip.GetEntry(name) ?? throw Errors.Invalid("import.format", "El XLSX no tiene hojas.");
                if (entry.Length > MaxPartBytes) throw Errors.Invalid("import.size", "La hoja es demasiado grande.");
                using var stream = entry.Open();
                return XDocument.Load(stream);
            }
            XNamespace main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
            XNamespace rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
            XNamespace pkg = "http://schemas.openxmlformats.org/package/2006/relationships";
            var shared = zip.GetEntry("xl/sharedStrings.xml") is null ? [] :
                Part("xl/sharedStrings.xml").Root!.Elements(main + "si").Select(si => string.Concat(si.Descendants(main + "t").Select(t => t.Value))).ToArray();
            // First sheet in workbook order, resolved through the workbook relationships.
            var sheetPath = "xl/worksheets/sheet1.xml";
            var first = Part("xl/workbook.xml").Root!.Element(main + "sheets")?.Elements(main + "sheet").FirstOrDefault();
            var relId = first?.Attribute(rel + "id")?.Value;
            if (relId is not null && zip.GetEntry("xl/_rels/workbook.xml.rels") is not null)
            {
                var target = Part("xl/_rels/workbook.xml.rels").Root!.Elements(pkg + "Relationship").FirstOrDefault(r => r.Attribute("Id")?.Value == relId)?.Attribute("Target")?.Value;
                if (target is not null) sheetPath = target.StartsWith('/') ? target.TrimStart('/') : "xl/" + target;
            }
            var rows = new List<List<string>>();
            foreach (var r in Part(sheetPath).Descendants(main + "row"))
            {
                var row = new List<string>();
                var next = 0;
                foreach (var c in r.Elements(main + "c"))
                {
                    var index = ColumnIndex(c.Attribute("r")?.Value) ?? next;
                    if (index > 200) throw Errors.Invalid("import.format", "La hoja tiene demasiadas columnas.");
                    while (row.Count < index) row.Add("");
                    var type = c.Attribute("t")?.Value;
                    var raw = c.Element(main + "v")?.Value ?? "";
                    var value = type switch
                    {
                        "s" => int.TryParse(raw, NumberStyles.None, CultureInfo.InvariantCulture, out var s) && s < shared.Length ? shared[s] : "",
                        "inlineStr" => string.Concat(c.Descendants(main + "t").Select(t => t.Value)),
                        "b" => raw == "1" ? "VERDADERO" : "FALSO",
                        "str" or "e" => raw,
                        _ => Number(raw),
                    };
                    row.Add(value.Trim());
                    next = index + 1;
                }
                rows.Add(row);
            }
            return rows;
        }
        catch (InvalidDataException) { throw Errors.Invalid("import.format", "El XLSX está dañado."); }
        catch (System.Xml.XmlException) { throw Errors.Invalid("import.format", "El XLSX está dañado."); }
    }

    // Excel stores 7501234567893 as a number; keep every digit, never scientific notation.
    private static string Number(string raw) =>
        decimal.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) ? d.ToString("0.############", CultureInfo.InvariantCulture) : raw;

    private static int? ColumnIndex(string? reference)
    {
        if (string.IsNullOrEmpty(reference)) return null;
        var index = 0;
        foreach (var ch in reference)
        {
            if (ch is >= 'A' and <= 'Z') index = index * 26 + (ch - 'A' + 1);
            else break;
        }
        return index == 0 ? null : index - 1;
    }
}
