using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Savia.Application;
using Savia.Domain;

namespace Savia.Infrastructure;

/// <summary>
/// Local OCR on this PC: a long-lived RapidOCR (Python, onnxruntime, CPU) process spoken to over stdin/stdout.
/// No port, no network: the sidecar refuses sockets (tools/ocr/tag_ocr_sidecar.py). One photo at a time.
/// The image is sent in memory and never written to disk. A failed or timed-out read kills the process; the next
/// request starts a fresh one. Startup (about 11-14 s: Python, onnxruntime, models) has its own limit and is not
/// cut by a photo's timeout; a photo that times out while the reader starts leaves the startup running for the next.
/// </summary>
public sealed class RapidOcrSidecarExtractor(string python, string script) : ITagExtractor, IDisposable
{
    private static readonly TimeSpan StartupLimit = TimeSpan.FromSeconds(90);
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly object _sync = new();
    private Process? _process;
    private Task<Process>? _starting;
    public string Engine => "rapidocr-onnxruntime 1.4.4 (local CPU)";

    /// <summary>Starts the reader in the background so the first photo does not wait for it.</summary>
    public Task WarmUpAsync() => Starting();

    public async Task<OcrResult> ReadAsync(ReadOnlyMemory<byte> image, CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var process = await Starting().WaitAsync(ct);
            var id = Guid.NewGuid().ToString("N");
            var request = JsonSerializer.Serialize(new { id, image = Convert.ToBase64String(image.Span) });
            try
            {
                await process.StandardInput.WriteLineAsync(request.AsMemory(), ct);
                await process.StandardInput.FlushAsync(ct);
                var answer = await process.StandardOutput.ReadLineAsync(ct)
                    ?? throw new InvalidOperationException("El lector de etiquetas se cerró.");
                return ParseAnswer(answer, id, Engine);
            }
            catch
            {
                Stop();
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>Maps one sidecar JSON answer to lines with axis-aligned boxes. Public for tests.</summary>
    public static OcrResult ParseAnswer(string json, string expectedId, string engine)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        if (!root.TryGetProperty("id", out var id) || id.ValueKind != JsonValueKind.String || id.GetString() != expectedId)
            throw new InvalidOperationException("Respuesta de OCR fuera de orden.");
        if (root.TryGetProperty("error", out var error))
            throw new InvalidOperationException("OCR: " + error.GetString());
        var lines = new List<OcrLine>();
        if (root.TryGetProperty("lines", out var array))
            foreach (var line in array.EnumerateArray())
            {
                var text = line.GetProperty("text").GetString() ?? "";
                var score = line.TryGetProperty("score", out var s) ? s.GetDouble() : 0;
                double left = double.MaxValue, top = double.MaxValue, right = double.MinValue, bottom = double.MinValue;
                if (line.TryGetProperty("box", out var box))
                    foreach (var point in box.EnumerateArray())
                    {
                        double x = point[0].GetDouble(), y = point[1].GetDouble();
                        left = Math.Min(left, x); right = Math.Max(right, x); top = Math.Min(top, y); bottom = Math.Max(bottom, y);
                    }
                if (left == double.MaxValue) { left = top = 0; right = bottom = 1; }
                lines.Add(new OcrLine(text, score, left, top, right, bottom));
            }
        return new OcrResult(lines, engine);
    }

    private Task<Process> Starting()
    {
        lock (_sync)
        {
            if (_process is { HasExited: false } running) return Task.FromResult(running);
            if (_starting is { IsCompleted: false }) return _starting;
            Stop();
            if (!File.Exists(python) || !File.Exists(script))
                throw new SaviaException(new SaviaError("tag.ocr_missing", ErrorKind.Unavailable,
                    "El lector local de etiquetas no está instalado. Ejecute: python savia/tools/ocr/setup_ocr.py"));
            return _starting = StartAsync();
        }
    }

    private async Task<Process> StartAsync()
    {
        using var limit = new CancellationTokenSource(StartupLimit);
        var ct = limit.Token;
        var info = new ProcessStartInfo(python)
        {
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = false,
            UseShellExecute = false, CreateNoWindow = true,
            StandardOutputEncoding = new UTF8Encoding(false), StandardInputEncoding = new UTF8Encoding(false),
        };
        info.ArgumentList.Add("-I");          // isolated: ignore PYTHONPATH and the user site
        info.ArgumentList.Add(script);
        info.Environment["PYTHONIOENCODING"] = "utf-8";
        var process = Process.Start(info) ?? throw new InvalidOperationException("No se pudo iniciar el lector local.");
        string? ready = null;
        try { ready = await process.StandardOutput.ReadLineAsync(ct); }
        catch (OperationCanceledException) { }
        if (ready is null || !ready.Contains("\"ready\": true", StringComparison.Ordinal))
        {
            Kill(process);
            throw new InvalidOperationException("El lector local de etiquetas no arrancó.");
        }
        lock (_sync) _process = process;   // published only after the ready line is consumed
        return process;
    }

    private void Stop()
    {
        lock (_sync)
        {
            Kill(_process);
            _process = null;
        }
    }

    private static void Kill(Process? process)
    {
        try { if (process is { HasExited: false }) process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { }
        process?.Dispose();
    }

    public void Dispose()
    {
        Stop();
        _gate.Dispose();
    }
}

public static class TagRegistration
{
    /// <summary>
    /// Tag OCR for /inventory/tag-extract. Keys: <c>Savia:Tags:Python</c> (default savia/.ocr/venv python),
    /// <c>Savia:Tags:Sidecar</c> (default savia/tools/ocr/tag_ocr_sidecar.py), <c>Savia:Tags:OcrTimeoutSeconds</c> (12),
    /// <c>Savia:Tags:KeepPhotos</c> (false: the photo is discarded after extraction),
    /// <c>Savia:Tags:WarmUp</c> (false; pilot.py sets true: start the reader when the API starts).
    /// </summary>
    public static IServiceCollection AddSaviaTags(this IServiceCollection services)
    {
        services.AddHostedService<TagOcrWarmUp>();
        services.AddSingleton(sp =>
        {
            var config = sp.GetRequiredService<IConfiguration>();
            return new TagExtractionOptions { OcrTimeout = TimeSpan.FromSeconds(config.GetValue("Savia:Tags:OcrTimeoutSeconds", 12)) };
        });
        services.AddSingleton<ITagExtractor>(sp =>
        {
            var config = sp.GetRequiredService<IConfiguration>();
            var root = SaviaRoot();
            var python = config["Savia:Tags:Python"] ?? Path.Combine(root, ".ocr", "venv",
                OperatingSystem.IsWindows() ? "Scripts" : "bin", OperatingSystem.IsWindows() ? "python.exe" : "python");
            var script = config["Savia:Tags:Sidecar"] ?? Path.Combine(root, "tools", "ocr", "tag_ocr_sidecar.py");
            return new RapidOcrSidecarExtractor(python, script);
        });
        services.AddSingleton<TagExtractionService>();
        return services;
    }

    private sealed class TagOcrWarmUp(IConfiguration config, ITagExtractor extractor) : Microsoft.Extensions.Hosting.IHostedService
    {
        public Task StartAsync(CancellationToken ct)
        {
            if (config.GetValue("Savia:Tags:WarmUp", false) && extractor is RapidOcrSidecarExtractor reader)
                _ = Task.Run(async () => { try { await reader.WarmUpAsync(); } catch (Exception) { /* the next photo reports it */ } });
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
    }

    private static string SaviaRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
            if (File.Exists(Path.Combine(dir.FullName, "tools", "ocr", "tag_ocr_sidecar.py"))) return dir.FullName;
        return AppContext.BaseDirectory;
    }
}
