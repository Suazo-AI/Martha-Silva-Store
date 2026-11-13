// Local OCR proof: runs the real tag extractor (RapidOCR sidecar + TagParser) on the synthetic tags and prints
// expected vs extracted per field with seconds per photo. With --raw <file> it scores another engine's OCR lines
// (same JSON shape as the sidecar) through the same parser, so both engines are compared on equal rules.
//
//   dotnet run --project savia/tools/ocr/TagProof -- savia/docs/pilot/etiqueta-proof [--raw lines.json --engine name]
using System.Diagnostics;
using System.Text.Json;
using Savia.Application;
using Savia.Infrastructure;

var dir = Path.GetFullPath(args.Length > 0 ? args[0] : "docs/pilot/etiqueta-proof");
string? raw = null, engineName = null;
for (var i = 1; i < args.Length - 1; i++)
{
    if (args[i] == "--raw") raw = args[i + 1];
    if (args[i] == "--engine") engineName = args[i + 1];
}
var expected = JsonDocument.Parse(File.ReadAllText(Path.Combine(dir, "expected.json"))).RootElement.EnumerateArray().ToList();
string[] fields = ["barcode", "sku", "name", "brand", "size", "color", "priceMinor", "composition"];

Dictionary<string, (OcrResult Ocr, double Seconds)> results = [];
if (raw is not null)
{
    foreach (var entry in JsonDocument.Parse(File.ReadAllText(raw)).RootElement.EnumerateArray())
    {
        var json = entry.GetRawText();
        results[entry.GetProperty("file").GetString()!] = (RapidOcrSidecarExtractor.ParseAnswer(json, "", engineName ?? "raw"),
            entry.GetProperty("ms").GetDouble() / 1000);
    }
}
else
{
    var root = Path.GetFullPath(Path.Combine(dir, "..", "..", ".."));
    using var extractor = new RapidOcrSidecarExtractor(Path.Combine(root, ".ocr", "venv", "Scripts", "python.exe"),
        Path.Combine(root, "tools", "ocr", "tag_ocr_sidecar.py"));
    engineName = extractor.Engine;
    var start = Stopwatch.StartNew();
    // Sidecar start and model load happen once per API process, not per photo; measured separately.
    await extractor.ReadAsync(await File.ReadAllBytesAsync(Path.Combine(dir, "tag1.png")), CancellationToken.None);
    Console.WriteLine($"start + first photo (warm-up, not counted): {start.Elapsed.TotalSeconds:F2} s");
    foreach (var e in expected)
    {
        var file = e.GetProperty("file").GetString()!;
        var bytes = await File.ReadAllBytesAsync(Path.Combine(dir, file));
        var clock = Stopwatch.StartNew();
        var ocr = await extractor.ReadAsync(bytes, CancellationToken.None);
        _ = TagParser.Parse(ocr.Lines);
        results[file] = (ocr, clock.Elapsed.TotalSeconds);
    }
}

Console.WriteLine($"\nEngine: {engineName}\n");
Console.WriteLine("| Foto | Tipo | Campo | Esperado | Extraído | OK |");
Console.WriteLine("|---|---|---|---|---|---|");
var ok = fields.ToDictionary(f => f, _ => 0);
var report = new List<object>();
foreach (var e in expected)
{
    var file = e.GetProperty("file").GetString()!;
    var (ocr, seconds) = results[file];
    var f = TagParser.Parse(ocr.Lines);
    var got = new Dictionary<string, string?>
    {
        ["barcode"] = f.Barcode, ["sku"] = f.Sku, ["name"] = f.Name, ["brand"] = f.Brand, ["size"] = f.Size,
        ["color"] = f.Color, ["priceMinor"] = f.PriceMinor?.ToString(), ["composition"] = f.Composition,
    };
    var row = new Dictionary<string, object?> { ["file"] = file, ["seconds"] = Math.Round(seconds, 2) };
    foreach (var field in fields)
    {
        var want = e.GetProperty(field).ValueKind == JsonValueKind.Null ? null : e.GetProperty(field).ToString();
        // barcode, SKU, size and price must match exactly; text fields ignore case and accents.
        var match = field is "barcode" or "sku" or "size" or "priceMinor"
            ? want == got[field]
            : want is null ? got[field] is null : got[field] is not null && TagParser.Fold(want) == TagParser.Fold(got[field]!);
        if (match) ok[field]++;
        row[field] = new { expected = want, extracted = got[field], ok = match };
        Console.WriteLine($"| {file} | {e.GetProperty("kind").GetString()} | {field} | {want ?? "—"} | {got[field] ?? "—"} | {(match ? "sí" : "NO")} |");
    }
    Console.WriteLine($"| {file} | | segundos | < 3 | {seconds:F2} | {(seconds < 3 ? "sí" : "NO")} |");
    report.Add(row);
}
Console.WriteLine($"\nAcierto por campo ({expected.Count} fotos): " + string.Join(", ", fields.Select(f => $"{f} {ok[f]}/{expected.Count}")));
var times = results.Values.Select(r => r.Seconds).ToList();
Console.WriteLine($"Segundos por foto: media {times.Average():F2}, máx {times.Max():F2}");
var outFile = Path.Combine(dir, $"result-{(raw is null ? "rapidocr" : engineName)}.json");
File.WriteAllText(outFile, JsonSerializer.Serialize(new { engine = engineName, perField = ok, photos = report }, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Wrote {outFile}");
