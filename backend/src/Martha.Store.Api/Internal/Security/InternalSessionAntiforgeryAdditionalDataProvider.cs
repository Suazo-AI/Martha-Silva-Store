using System.Security.Claims;
using Microsoft.AspNetCore.Antiforgery;

namespace Martha.Store.Api.Internal;

// Stateless: the authenticated session is authoritative only for this request.
public sealed class InternalSessionAntiforgeryAdditionalDataProvider : IAntiforgeryAdditionalDataProvider
{
    public string GetAdditionalData(HttpContext context) => TryData(context.User, out var data)
        ? data : throw new InvalidOperationException("Invalid internal session identity.");

    public bool ValidateAdditionalData(HttpContext context, string additionalData) =>
        TryData(context.User, out var expected) && string.Equals(expected, additionalData, StringComparison.Ordinal);

    private static bool TryData(ClaimsPrincipal user, out string data)
    {
        data = "";
        var authenticated = user.Identities.Where(identity => identity.IsAuthenticated).ToArray();
        if (authenticated.Length == 0) return true;
        // Do not accept a session from a secondary or unauthenticated identity.
        if (authenticated.Length != 1 || !ReferenceEquals(user.Identity, authenticated[0])) return false;
        var claims = user.FindAll(InternalSecurityRules.SessionClaim).ToArray();
        if (claims.Length != 1 || !authenticated[0].Claims.Contains(claims[0])) return false;
        var value = claims[0].Value;
        if (!Guid.TryParseExact(value, "D", out var session) || session == Guid.Empty
            || !string.Equals(value, session.ToString("D"), StringComparison.Ordinal)) return false;
        data = "s1:" + value;
        return true;
    }
}
