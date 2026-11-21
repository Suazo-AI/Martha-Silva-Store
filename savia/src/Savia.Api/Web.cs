using Microsoft.Extensions.FileProviders;

namespace Savia.Api;

public static class SaviaWeb
{
    /// <summary>
    /// Serves the browser client at <c>/</c> with <c>index.html</c> as the default page. The folder is
    /// <c>Savia:Web:Root</c>, or <c>savia/web</c> next to the source tree. A missing folder is not an error:
    /// the API runs without a client. API routes win over files because static files only answer unmatched paths.
    /// </summary>
    public static void UseSaviaWeb(this WebApplication app, string? configuredRoot)
    {
        var root = string.IsNullOrWhiteSpace(configuredRoot)
            ? Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "..", "web"))
            : Path.GetFullPath(configuredRoot);
        if (!Directory.Exists(root)) return;
        var files = new PhysicalFileProvider(root);
        app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = files });
        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = files,
            OnPrepareResponse = c => c.Context.Response.Headers.CacheControl = "no-cache",
        });
    }
}
