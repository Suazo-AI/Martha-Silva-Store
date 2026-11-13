using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

/// <summary>One text line read from the photo. The box is axis-aligned in image pixels.</summary>
public sealed record OcrLine(string Text, double Score, double Left, double Top, double Right, double Bottom)
{
    public double CenterY => (Top + Bottom) / 2;
    public double Height => Math.Max(1, Bottom - Top);
}

public sealed record OcrResult(IReadOnlyList<OcrLine> Lines, string Engine);

/// <summary>
/// Reads the text of a tag photo. The pilot implementation runs on this PC only (RapidOCR sidecar, Infrastructure).
/// Tests use a fake. No cloud or paid implementation exists, by owner decision (docs/pilot/ETIQUETA.md).
/// </summary>
public interface ITagExtractor
{
    string Engine { get; }
    Task<OcrResult> ReadAsync(ReadOnlyMemory<byte> image, CancellationToken ct);
}

/// <summary>Fields parsed from the OCR lines with plain rules. Each value has a 0..1 confidence.</summary>
public sealed record TagFields(string? Barcode, string? Sku, string? Name, string? Brand, string? Size, string? Color,
    long? PriceMinor, string? Composition, IReadOnlyDictionary<string, double> Confidence, string RawText);

public sealed class TagExtractionOptions
{
    public const long MaxImageBytes = 6 * 1024 * 1024;
    public TimeSpan OcrTimeout { get; init; } = TimeSpan.FromSeconds(12);
}

public sealed class TagExtractionService(ITagExtractor extractor, ICatalogStore catalog, NodeContext node, TagExtractionOptions options)
{
    // Same roles that may count merchandise in a reception (ReceivingService).
    private static readonly string[] Receivers = [Roles.Inventory, Roles.Cashier, Roles.Manager, Roles.Owner];

    public async Task<TagExtractResponse> ExtractAsync(Actor actor, ReadOnlyMemory<byte> image, string? barcodeHint, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        Guard.Role(actor, Receivers);
        if (image.Length == 0) throw Errors.Invalid("tag.image_missing", "Falta la foto de la etiqueta.");
        if (image.Length > TagExtractionOptions.MaxImageBytes)
            throw Errors.Invalid("tag.image_too_large", "La foto supera 6 MB. Tómela de nuevo.");
        if (!IsSupportedImage(image.Span))
            throw Errors.Invalid("tag.image_type", "La foto debe ser JPEG, PNG o WebP.");

        var clock = Stopwatch.StartNew();
        var hint = TagParser.ValidBarcode(barcodeHint);
        if (hint is not null && await FindAsync(hint, null, ct) is { } known)
            return Response(Empty(hint), known, "match", extractor.Engine, (int)clock.ElapsedMilliseconds, null);

        TagFields fields;
        var source = "ocr";
        string? warning = null;
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(options.OcrTimeout);
            var ocr = await extractor.ReadAsync(image, timeout.Token);
            fields = TagParser.Parse(ocr.Lines, hint);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested && ex is not SaviaException { Error.Kind: ErrorKind.Forbidden })
        {
            // Slow or failed OCR never blocks the worker: the form opens with the barcode only.
            fields = Empty(hint);
            source = "none";
            warning = ex is OperationCanceledException
                ? "La lectura tardó demasiado. Complete los datos a mano."
                : "No se pudo leer la etiqueta. Complete los datos a mano.";
        }
        var match = await FindAsync(fields.Barcode, fields.Sku, ct);
        return Response(fields, match, source, extractor.Engine, (int)clock.ElapsedMilliseconds, warning);
    }

    private async Task<TagMatchedItem?> FindAsync(string? barcode, string? sku, CancellationToken ct)
    {
        if (barcode is not null)
        {
            var hits = await catalog.LookupAsync(barcode, null, ct);
            if (hits.Count == 1)
            {
                var i = hits[0];
                return new TagMatchedItem(i.ItemId, i.Sku, i.ProductName, i.VariantName, i.SizeCode, i.ColorCode, i.UnitPriceMinor, "barcode");
            }
        }
        if (sku is { Length: >= 2 })
        {
            var rows = (await catalog.SearchAsync(sku, node.LocationId, 10, ct))
                .Where(r => string.Equals(r.Sku, sku, StringComparison.OrdinalIgnoreCase)).ToList();
            if (rows.Count == 1)
            {
                var r = rows[0];
                return new TagMatchedItem(r.ItemId, r.Sku, r.ProductName, r.VariantName, r.SizeCode, r.ColorCode, r.UnitPriceMinor, "sku");
            }
        }
        return null;
    }

    private static TagFields Empty(string? barcode) => new(barcode, null, null, null, null, null, null, null,
        barcode is null ? new Dictionary<string, double>() : new Dictionary<string, double> { ["barcode"] = 1.0 }, "");

    private static TagExtractResponse Response(TagFields f, TagMatchedItem? match, string source, string engine, int ms, string? warning) =>
        new(f.Barcode, f.Sku, f.Name, f.Brand, f.Size, f.Color, f.PriceMinor, f.Composition, f.Confidence, f.RawText,
            match, source, engine, ms, warning);

    public static bool IsSupportedImage(ReadOnlySpan<byte> b) =>
        (b.Length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF)
        || (b.Length > 8 && b[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
        || (b.Length > 12 && b[..4].SequenceEqual("RIFF"u8) && b[8..12].SequenceEqual("WEBP"u8));
}

/// <summary>Rules that turn OCR lines into tag fields. Pure; unit tested.</summary>
public static partial class TagParser
{
    private const double Heuristic = 0.6;   // weight of a value found without its label

    private static readonly string[] SkuLabels = ["SKU", "REF", "REFERENCIA", "CODIGO", "COD", "ART", "ARTICULO", "ESTILO", "STYLE", "MODELO", "MOD", "ITEM"];
    private static readonly string[] SizeLabels = ["TALLA", "SIZE", "TALLE", "TAL", "TLL"];
    private static readonly string[] ColorLabels = ["COLOR", "COLOUR", "COL"];
    private static readonly string[] BrandLabels = ["MARCA", "BRAND"];
    private static readonly string[] NameLabels = ["DESCRIPCION", "DESC", "PRODUCTO", "PRENDA", "DESCRIPTION"];
    private static readonly string[] PriceLabels = ["PRECIO", "PRICE", "PVP"];
    private static readonly HashSet<string> Sizes = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"];

    private static readonly Dictionary<string, string> Colors = new(StringComparer.Ordinal)
    {
        ["AZUL"] = "Azul", ["BLUE"] = "Azul", ["NAVY"] = "Azul marino", ["NEGRO"] = "Negro", ["BLACK"] = "Negro",
        ["ROJO"] = "Rojo", ["RED"] = "Rojo", ["BLANCO"] = "Blanco", ["WHITE"] = "Blanco", ["VERDE"] = "Verde", ["GREEN"] = "Verde",
        ["GRIS"] = "Gris", ["GREY"] = "Gris", ["GRAY"] = "Gris", ["AMARILLO"] = "Amarillo", ["YELLOW"] = "Amarillo",
        ["ROSADO"] = "Rosado", ["ROSA"] = "Rosado", ["PINK"] = "Rosado", ["MORADO"] = "Morado", ["PURPLE"] = "Morado",
        ["CAFE"] = "Café", ["MARRON"] = "Café", ["BROWN"] = "Café", ["BEIGE"] = "Beige", ["NARANJA"] = "Naranja",
        ["ORANGE"] = "Naranja", ["CELESTE"] = "Celeste", ["CREMA"] = "Crema", ["VINO"] = "Vino", ["DORADO"] = "Dorado",
        ["PLATEADO"] = "Plateado", ["TURQUESA"] = "Turquesa", ["FUCSIA"] = "Fucsia", ["LILA"] = "Lila", ["KAKI"] = "Kaki",
        ["KHAKI"] = "Kaki", ["MOSTAZA"] = "Mostaza", ["CORAL"] = "Coral", ["AZUL MARINO"] = "Azul marino",
    };

    private static readonly Dictionary<string, string> Materials = new(StringComparer.Ordinal)
    {
        ["ALGODON"] = "Algodón", ["COTTON"] = "Algodón", ["POLIESTER"] = "Poliéster", ["POLYESTER"] = "Poliéster",
        ["ELASTANO"] = "Elastano", ["ELASTANE"] = "Elastano", ["SPANDEX"] = "Elastano", ["LYCRA"] = "Elastano",
        ["VISCOSA"] = "Viscosa", ["VISCOSE"] = "Viscosa", ["RAYON"] = "Rayón", ["ACRILICO"] = "Acrílico", ["ACRYLIC"] = "Acrílico",
        ["ACRILIC"] = "Acrílico", ["LANA"] = "Lana", ["WOOL"] = "Lana", ["LINO"] = "Lino", ["LINEN"] = "Lino", ["SEDA"] = "Seda",
        ["SILK"] = "Seda", ["NYLON"] = "Nailon", ["NAILON"] = "Nailon", ["POLIAMIDA"] = "Poliamida", ["POLYAMIDE"] = "Poliamida",
        ["MODAL"] = "Modal", ["CUERO"] = "Cuero", ["LEATHER"] = "Cuero",
    };

    public static TagFields Parse(IReadOnlyList<OcrLine> raw, string? barcodeHint = null)
    {
        var lines = raw.Select(l => l with { Text = Clean(l.Text) }).Where(l => l.Text.Length > 0)
            .OrderBy(l => l.Top).ThenBy(l => l.Left).ToList();
        var used = new HashSet<OcrLine>();
        var confidence = new Dictionary<string, double>();
        string? Set(string key, string? value, double score)
        {
            if (value is not null) confidence[key] = Math.Round(Math.Clamp(score, 0, 1), 2);
            return value;
        }

        // Barcode: a digit run with a valid check digit. The phone's decoded hint wins.
        string? barcode = null;
        if (ValidBarcode(barcodeHint) is { } hint) barcode = Set("barcode", hint, 1.0);
        else
            foreach (var line in lines)
            {
                var digits = Regex.Replace(line.Text, @"[\s\-]", "");
                foreach (Match m in DigitRun().Matches(digits))
                    if (ValidBarcode(m.Value) is { } code) { barcode = Set("barcode", code, Math.Max(line.Score, 0.95)); used.Add(line); break; }
                if (barcode is not null) break;
            }

        var sku = Labeled(lines, used, SkuLabels, v => SkuValue(v)) is { } s ? Set("sku", s.Value, s.Score) : null;
        if (sku is null)
            foreach (var line in lines.Where(l => !used.Contains(l)))
                if (SkuShape().IsMatch(line.Text.Replace(" ", "")) && line.Text.Any(char.IsDigit) && line.Text.Any(char.IsLetter))
                { sku = Set("sku", line.Text.Replace(" ", "").ToUpperInvariant(), line.Score * Heuristic); used.Add(line); break; }

        var size = Labeled(lines, used, SizeLabels, SizeValue) is { } z ? Set("size", z.Value, z.Score) : null;
        if (size is null)
            foreach (var line in lines.Where(l => !used.Contains(l)))
                if (Sizes.Contains(line.Text.ToUpperInvariant().Replace(" ", "")))
                { size = Set("size", SizeValue(line.Text), line.Score * Heuristic); used.Add(line); break; }

        var color = Labeled(lines, used, ColorLabels, ColorValue) is { } c ? Set("color", c.Value, c.Score) : null;
        if (color is null)
            foreach (var line in lines.Where(l => !used.Contains(l)))
                if (ColorValue(line.Text) is { } known) { color = Set("color", known, line.Score * Heuristic); used.Add(line); break; }

        long? price = null;
        foreach (var line in lines)
        {
            var m = PriceText().Match(line.Text);
            if (m.Success && ParseMoneyMinor(m.Groups["n"].Value) is { } p)
            { price = p; confidence["priceMinor"] = Math.Round(line.Score, 2); used.Add(line); break; }
        }
        if (price is null && Labeled(lines, used, PriceLabels, v => ParseMoneyMinor(v)?.ToString(CultureInfo.InvariantCulture)) is { } pl)
        { price = long.Parse(pl.Value, CultureInfo.InvariantCulture); confidence["priceMinor"] = Math.Round(pl.Score, 2); }

        var composition = Composition(lines, used, out var compScore) is { } comp ? Set("composition", comp, compScore) : null;

        var brand = Labeled(lines, used, BrandLabels, v => v.Trim()) is { } b ? Set("brand", b.Value, b.Score) : null;
        var name = Labeled(lines, used, NameLabels, v => v.Trim()) is { } n ? Set("name", n.Value, n.Score) : null;
        // Without labels: the first wordy line is the brand, the next one is the description.
        var wordy = lines.Where(l => !used.Contains(l) && IsWordy(l.Text)).ToList();
        if (brand is null && wordy.Count > 0) { brand = Set("brand", wordy[0].Text, wordy[0].Score * 0.7); used.Add(wordy[0]); wordy.RemoveAt(0); }
        if (name is null && wordy.Count > 0) { name = Set("name", wordy[0].Text, wordy[0].Score * 0.7); used.Add(wordy[0]); }

        return new TagFields(barcode, sku, name, brand, size, color, price, composition, confidence,
            string.Join("\n", lines.Select(l => l.Text)));
    }

    /// <summary>EAN-13, UPC-A (12) or EAN-8 with a valid check digit; null otherwise.</summary>
    public static string? ValidBarcode(string? code)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        code = code.Trim();
        if (code.Length is not (8 or 12 or 13) || !code.All(char.IsAsciiDigit)) return null;
        var sum = 0;
        for (var i = code.Length - 2; i >= 0; i--)
            sum += (code[i] - '0') * ((code.Length - 2 - i) % 2 == 0 ? 3 : 1);
        return (10 - sum % 10) % 10 == code[^1] - '0' ? code : null;
    }

    /// <summary>"C$ 1,250.00", "1.250,00", "890" -> minor units (125000, 125000, 89000). Null when not a price.</summary>
    public static long? ParseMoneyMinor(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var s = Regex.Replace(text, @"(?i)c\s*\$|cs\$|nio|us\$|\$|\s", "");
        if (s.Length == 0 || !Regex.IsMatch(s, @"^\d[\d.,]*$")) return null;
        int lastDot = s.LastIndexOf('.'), lastComma = s.LastIndexOf(',');
        // The last separator is decimal when one or two digits follow it; otherwise every separator groups thousands.
        var sep = Math.Max(lastDot, lastComma);
        var isDecimal = sep >= 0 && s.Length - sep - 1 is 1 or 2;
        var whole = isDecimal ? s[..sep] : s;
        var cents = isDecimal ? s[(sep + 1)..] : "";
        whole = whole.Replace(".", "").Replace(",", "");
        if (whole.Length == 0 || whole.Length > 9) return null;
        return long.Parse(whole, CultureInfo.InvariantCulture) * 100 + (cents.Length == 0 ? 0 : int.Parse(cents.PadRight(2, '0'), CultureInfo.InvariantCulture));
    }

    /// <summary>XS..XXXL (2XL -> XXL) or a numeric size such as 32 or 10. Null otherwise.</summary>
    public static string? SizeValue(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var t = text.Trim().ToUpperInvariant().Replace(" ", "").TrimEnd('.');
        t = t switch { "2XL" or "XXL" => "XXL", "3XL" or "XXXL" => "XXXL", "2XS" or "XXS" => "XXS", _ => t };
        if (Sizes.Contains(t)) return t;
        var digits = text.Trim();
        return Regex.IsMatch(digits, @"^\d{1,2}(/\d{1,2})?$") ? digits : null;
    }

    public static string? ColorValue(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var key = Fold(text).Trim();
        return Colors.TryGetValue(key, out var color) ? color : null;
    }

    private static string? SkuValue(string text)
    {
        var v = text.Trim().TrimStart(':', '#', '.').Trim().Replace(" ", "").ToUpperInvariant();
        return SkuShape().IsMatch(v) && v.Any(char.IsDigit) ? v : null;
    }

    /// <summary>Finds "LABEL value" in one line, or the value beside (same row, to the right) or below the label line.</summary>
    private static (string Value, double Score)? Labeled(List<OcrLine> lines, HashSet<OcrLine> used, string[] labels, Func<string, string?> value)
    {
        foreach (var line in lines)
        {
            var folded = Fold(line.Text);
            var label = labels.FirstOrDefault(l => folded == l || folded == l + ":" || folded.StartsWith(l + ":", StringComparison.Ordinal)
                || folded.StartsWith(l + " ", StringComparison.Ordinal) || folded.StartsWith(l + ".", StringComparison.Ordinal));
            if (label is null) continue;
            var rest = line.Text[Math.Min(line.Text.Length, label.Length)..].TrimStart(':', '.', '#', ' ');
            if (rest.Length > 0 && value(rest) is { } inline) { used.Add(line); return (inline, line.Score); }
            if (rest.Length > 0) continue;
            var beside = lines.Where(o => o != line && !used.Contains(o) && o.Left > line.Right - 2
                    && Math.Abs(o.CenterY - line.CenterY) < Math.Max(o.Height, line.Height) * 1.2)
                .OrderBy(o => Math.Abs(o.CenterY - line.CenterY)).ThenBy(o => o.Left);
            var below = lines.Where(o => o != line && !used.Contains(o) && o.Top >= line.CenterY
                    && o.Top - line.Bottom < line.Height * 3 && o.Right > line.Left - line.Height * 4)
                .OrderBy(o => o.Top);
            foreach (var candidate in beside.Concat(below).Take(3))
                if (!IsLabel(candidate.Text) && value(candidate.Text) is { } found)
                {
                    used.Add(line); used.Add(candidate);
                    return (found, Math.Min(line.Score, candidate.Score));
                }
        }
        return null;
    }

    private static string? Composition(List<OcrLine> lines, HashSet<OcrLine> used, out double score)
    {
        score = 0;
        var parts = new List<(int Pct, string Material)>();
        var scores = new List<double>();
        foreach (var line in lines.Where(l => l.Text.Contains('%')))
        {
            var text = line.Text;
            // "98% Algodón 2%" with the material on the next line below.
            if (Regex.IsMatch(text, @"\d\s*%\s*$"))
            {
                var next = lines.Where(o => o != line && !used.Contains(o) && o.Top >= line.CenterY && o.Top - line.Bottom < line.Height * 2
                        && o.Left < line.Right && o.Right > line.Left).OrderBy(o => o.Top).FirstOrDefault();
                if (next is not null) { text += " " + next.Text; used.Add(next); scores.Add(next.Score); }
            }
            foreach (Match m in CompositionPart().Matches(text))
            {
                var word = Fold(m.Groups["m"].Value).Replace('0', 'O');
                var material = Materials.TryGetValue(word, out var known) ? known
                    : Materials.FirstOrDefault(k => word.StartsWith(k.Key, StringComparison.Ordinal) || k.Key.StartsWith(word, StringComparison.Ordinal) && word.Length >= 5).Value;
                if (material is not null) parts.Add((int.Parse(m.Groups["p"].Value, CultureInfo.InvariantCulture), material));
            }
            used.Add(line);
            scores.Add(line.Score);
        }
        if (parts.Count == 0) return null;
        score = scores.Min() * (parts.Sum(p => p.Pct) == 100 ? 1 : 0.6);
        return string.Join(" ", parts.Select(p => $"{p.Pct}% {p.Material}"));
    }

    private static bool IsLabel(string text)
    {
        var f = Fold(text).TrimEnd(':', '.');
        return SkuLabels.Concat(SizeLabels).Concat(ColorLabels).Concat(BrandLabels).Concat(NameLabels).Concat(PriceLabels).Contains(f);
    }

    private static bool IsWordy(string text) =>
        text.Length >= 3 && text.All(c => char.IsLetter(c) || c is ' ' or '-' or '\'' or '&' or '.') && text.Count(char.IsLetter) >= 3
        && !IsLabel(text) && ColorValue(text) is null && SizeValue(text) is null;

    /// <summary>Full-width digits to ASCII (NFKC), collapsed spaces.</summary>
    private static string Clean(string text) => Regex.Replace(text.Normalize(NormalizationForm.FormKC), @"\s+", " ").Trim();

    /// <summary>Upper case without accents, for comparisons only.</summary>
    public static string Fold(string text)
    {
        var d = text.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(d.Length);
        foreach (var ch in d)
            if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark) sb.Append(ch);
        return Regex.Replace(sb.ToString().ToUpperInvariant(), @"\s+", " ").Trim();
    }

    [GeneratedRegex(@"\d{8,14}")] private static partial Regex DigitRun();
    [GeneratedRegex(@"^[A-Z0-9][A-Z0-9\-./]{2,29}$", RegexOptions.IgnoreCase)] private static partial Regex SkuShape();
    [GeneratedRegex(@"(?i)(?:c\s?\$|cs\$|nio)\s*(?<n>\d[\d.,\s]*\d|\d)")] private static partial Regex PriceText();
    [GeneratedRegex(@"(?<p>\d{1,3})\s*%\s*(?<m>[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0]+)")] private static partial Regex CompositionPart();
}
