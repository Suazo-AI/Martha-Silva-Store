using Savia.Domain;

namespace Savia.Application;

/// <summary>One page of a long list and the key that continues it; <see cref="NextAfter"/> is null on the last page.</summary>
public sealed record Page<T>(IReadOnlyList<T> Items, string? NextAfter);

/// <summary>D-041: a list endpoint answers at most 500 rows, so no response grows with the catalog.</summary>
public static class Paging
{
    public const int MaxRows = 500;

    public static int Limit(int? limit) => Math.Clamp(limit ?? MaxRows, 1, MaxRows);

    public static SaviaException BadAfter() => Errors.Invalid("page.after", "La clave para continuar la lista no es válida.");
}
