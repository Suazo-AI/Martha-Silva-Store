using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace Savia.Infrastructure;

/// <summary>Procedures that answer one JSON column, and the JSON options every store uses. Written once.</summary>
internal static class SqlJson
{
    public static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    public static async Task<JsonElement> ReadElement(this SqlGateway sql, string proc, CancellationToken ct, params SqlParameter[] args)
    {
        var rows = await sql.QueryProcAsync(proc, r => r.IsDBNull(0) ? "[]" : r.GetString(0), ct, args);
        using var document = JsonDocument.Parse(rows.Single());
        return document.RootElement.Clone();
    }

    public static async Task<T?> ReadJson<T>(this SqlGateway sql, string proc, CancellationToken ct, params SqlParameter[] args) where T : class
    {
        var rows = await sql.QueryProcAsync(proc, r => r.IsDBNull(0) ? null : r.GetString(0), ct, args);
        return rows.FirstOrDefault() is { Length: > 0 } text ? JsonSerializer.Deserialize<T>(text, Web) : null;
    }
}
