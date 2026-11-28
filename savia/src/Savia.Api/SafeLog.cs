using Microsoft.Data.SqlClient;
using Savia.Domain;

namespace Savia.Api;

/// <summary>
/// SEC-46: logs name ids, paths and error codes, never contact details. An exception message can quote row values
/// (a SQL duplicate key names the value, which can be an email), so a logged exception is reduced to its type, stable
/// code, SQL number, procedure and line. The stack trace holds code locations only.
/// </summary>
public static class SafeLog
{
    public static string Describe(Exception ex)
    {
        var self = ex switch
        {
            SaviaException savia => savia.Error.Code,
            SqlException sql => $"SqlException {sql.Number} in {(string.IsNullOrEmpty(sql.Procedure) ? "batch" : sql.Procedure)} line {sql.LineNumber}",
            HttpRequestException http => $"HttpRequestException {http.HttpRequestError}{(http.StatusCode is { } s ? $" {(int)s}" : "")}",
            _ => ex.GetType().Name,
        };
        return ex.InnerException is null ? self : $"{self} <- {Describe(ex.InnerException)}";
    }

    /// <summary>Error with the reduced description and the stack trace, in place of <c>LogError(ex, ...)</c>.</summary>
    public static void Failure(this ILogger log, Exception ex, string what) =>
        log.LogError("{What}: {Error}\n{Stack}", what, Describe(ex), Stack(ex));

    private static string Stack(Exception ex) =>
        ex.InnerException is null ? ex.StackTrace ?? "" : $"{ex.StackTrace}\n--- inner ---\n{Stack(ex.InnerException)}";
}
