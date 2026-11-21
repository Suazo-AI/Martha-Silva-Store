namespace Martha.Store.Api.Internal;

// Bounded per-process admission protection, not a distributed rate limiter. Account lockout is persisted.
// Do not trust a client-supplied forwarding header; the host must separately configure trusted proxies.
public sealed class InternalLoginLimiter(TimeProvider time)
{
    private readonly object gate = new();
    private readonly Dictionary<string, Bucket> buckets = new(StringComparer.Ordinal);
    private DateTimeOffset globalStart;
    private int globalAttempts;
    private int inFlight;
    public const int MaxBuckets = 4096;
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(1);
    private sealed record Bucket(DateTimeOffset Start, int Attempts);

    public IDisposable? TryEnter(string remoteAddress)
    {
        lock (gate)
        {
            var now = time.GetUtcNow();
            if (now - globalStart >= Window) { globalStart = now; globalAttempts = 0; }
            if (globalAttempts >= 120 || inFlight >= 4) return null;
            // IP strings are bounded by the transport. Never store arbitrary request fields as keys.
            if (remoteAddress.Length > 64) return null;
            if (buckets.TryGetValue(remoteAddress, out var bucket) && now - bucket.Start < Window)
            {
                if (bucket.Attempts >= 10) return null;
                buckets[remoteAddress] = bucket with { Attempts = bucket.Attempts + 1 };
            }
            else
            {
                if (buckets.Count >= MaxBuckets)
                    foreach (var expired in buckets.Where(x => now - x.Value.Start >= Window).Select(x => x.Key).ToArray()) buckets.Remove(expired);
                if (buckets.Count >= MaxBuckets && !buckets.ContainsKey(remoteAddress)) return null;
                buckets[remoteAddress] = new(now, 1);
            }
            globalAttempts++;
            inFlight++;
            return new Lease(this);
        }
    }

    private sealed class Lease(InternalLoginLimiter owner) : IDisposable
    {
        private InternalLoginLimiter? current = owner;
        public void Dispose()
        {
            var limiter = Interlocked.Exchange(ref current, null);
            if (limiter is not null) lock (limiter.gate) limiter.inFlight--;
        }
    }
}
