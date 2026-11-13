namespace Savia.Contracts;

// HTTP contract of the SAVIA API, version 1. Clients are generated from the OpenAPI document.
// Money is always in minor units (centavos). Ids are created by the client so a retry is safe.
// One file per module; this one holds what every module shares.

/// <summary>Body of every error response.</summary>
public sealed record ProblemResponse(string Code, string Message, string? TraceId);
