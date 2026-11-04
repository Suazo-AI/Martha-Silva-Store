using System.Globalization;
using System.Net.Mail;
using System.Text;

namespace Martha.Store.Api.Internal;

public static class InternalDirectoryValidation
{
    public static InternalResult<InternalItemWrite> Item(InternalItemWrite value)
    {
        var rawSku = value.Sku?.Trim();
        var sku = rawSku?.ToUpperInvariant();
        var rawCurrency = value.Currency?.Trim();
        var currency = rawCurrency?.ToUpperInvariant();
        if (rawSku is not { Length: >= 1 and <= 64 } || !rawSku.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.') ||
            !Text(value.Name, 200, out var name) || value.UnitPriceMinor < 0 || value.UnitPriceMinor > InternalRules.MaxMinor ||
            rawCurrency is null || !rawCurrency.All(char.IsAsciiLetter) || !InternalRules.ValidCurrency(currency))
            return InternalResult<InternalItemWrite>.Fail("invalid_request");
        return InternalResult<InternalItemWrite>.Ok(value with { Sku = sku, Name = name, Currency = currency });
    }

    public static InternalResult<InternalLocationWrite> Location(InternalLocationWrite value) =>
        Text(value.Name, 120, out var name)
            ? InternalResult<InternalLocationWrite>.Ok(value with { Name = name })
            : InternalResult<InternalLocationWrite>.Fail("invalid_request");

    public static InternalResult<InternalPartyWrite> Party(InternalPartyWrite value)
    {
        var kind = value.Kind?.Trim().ToLowerInvariant();
        if (kind is not ("customer" or "supplier") || !Text(value.Name, 200, out var name) ||
            !Email(value.Email, out var email) || !Phone(value.Phone, out var phone))
            return InternalResult<InternalPartyWrite>.Fail("invalid_request");
        return InternalResult<InternalPartyWrite>.Ok(value with { Kind = kind, Name = name, Email = email, Phone = phone });
    }

    public static bool Query(string? query, int skip, int take, out string? normalized)
    {
        normalized = null;
        if (skip < 0 || skip > 100_000 || take < 1 || take > 100) return false;
        if (query is null or "") return true;
        return Text(query, 200, out normalized);
    }

    private static bool Text(string? value, int maxLength, out string? normalized)
    {
        normalized = null;
        if (value is null || value.Length > maxLength || value.Any(Forbidden)) return false;
        try { normalized = value.Trim().Normalize(NormalizationForm.FormC); }
        catch (ArgumentException) { return false; }
        return normalized.Length is >= 1 && normalized.Length <= maxLength;
    }

    private static bool Forbidden(char c) => char.IsControl(c) ||
        char.GetUnicodeCategory(c) is UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator ||
        c is >= '\u202a' and <= '\u202e' or >= '\u2066' and <= '\u2069';

    private static bool Email(string? value, out string? normalized)
    {
        normalized = null;
        if (value is null) return true;
        if (value.Any(Forbidden)) return false;
        if (string.IsNullOrWhiteSpace(value)) return true;
        var candidate = value.Trim();
        if (value.Length > 254 || !MailAddress.TryCreate(candidate, out var address) ||
            !string.Equals(address.Address, candidate, StringComparison.Ordinal)) return false;
        // Case-fold only the DNS domain, never the potentially case-sensitive local
        // part. Do not remove plus tags, periods or accents and do not deduplicate.
        var at = candidate!.LastIndexOf('@');
        if (at <= 0 || at == candidate.Length - 1) return false;
        normalized = candidate[..(at + 1)] + candidate[(at + 1)..].ToLowerInvariant();
        return true;
    }

    private static bool Phone(string? value, out string? normalized)
    {
        normalized = null;
        if (value is null) return true;
        if (value.Any(Forbidden)) return false;
        if (string.IsNullOrWhiteSpace(value)) return true;
        if (!Text(value, 32, out normalized) ||
            !normalized!.All(c => char.IsAsciiDigit(c) || c is '+' or '-' or '(' or ')' or ' ' or '.') ||
            !normalized!.Any(char.IsAsciiDigit)) return false;
        // Preserve country prefix/format; never infer a country or numeric identity.
        return true;
    }
}
