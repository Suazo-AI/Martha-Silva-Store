using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace Martha.Store.Api;

public static partial class StoreDatabaseGuard
{
    public static void Validate(string connection)
    {
        SqlConnectionStringBuilder parsed;
        try { parsed = new SqlConnectionStringBuilder(connection); }
        catch (ArgumentException) { throw new StorageUnavailableException(); }
        // Naming is an accidental-target safeguard, not proof that the host is isolated or authorized.
        if (!SyntheticDatabaseName().IsMatch(parsed.InitialCatalog)) throw new StorageUnavailableException();
    }

    [GeneratedRegex(@"\AMarthaSynthetic_[A-Za-z0-9_]{1,64}\z", RegexOptions.CultureInvariant)]
    private static partial Regex SyntheticDatabaseName();
}
