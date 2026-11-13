using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>POST /api/v1/inventory/tag-extract: phone photo of a hanging tag -> editable new-product fields (docs/pilot/ETIQUETA.md).</summary>
public static class TagsEndpoints
{
    public static void Map(RouteGroupBuilder api, WebApplication app)
    {
        var keepPhotos = app.Configuration.GetValue("Savia:Tags:KeepPhotos", false);
        var photoFolder = Path.GetFullPath(app.Configuration["Savia:Tags:PhotoFolder"]
            ?? Path.Combine(app.Environment.ContentRootPath, "..", "..", ".out", "tags"));

        api.MapPost("/inventory/tag-extract", async (HttpContext http, TagExtractionService tags, CancellationToken ct) =>
            {
                // Read the form by hand: bearer-token API (no cookies), so no antiforgery token is involved.
                if (!http.Request.HasFormContentType)
                    throw Errors.Invalid("tag.image_missing", "Envíe la foto como multipart/form-data en el campo 'image'.");
                var form = await http.Request.ReadFormAsync(ct);
                var file = form.Files.GetFile("image") ?? throw Errors.Invalid("tag.image_missing", "Falta la foto de la etiqueta.");
                if (file.Length > TagExtractionOptions.MaxImageBytes)
                    throw Errors.Invalid("tag.image_too_large", "La foto supera 6 MB. Tómela de nuevo.");
                using var buffer = new MemoryStream((int)file.Length);
                await file.CopyToAsync(buffer, ct);
                var image = buffer.GetBuffer().AsMemory(0, (int)buffer.Length);
                var result = await tags.ExtractAsync(http.Actor(), image, form["barcode"].ToString(), ct);
                if (keepPhotos)
                {
                    Directory.CreateDirectory(photoFolder);
                    await File.WriteAllBytesAsync(
                        Path.Combine(photoFolder, $"{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}.img"), image.ToArray(), ct);
                }
                return Results.Ok(result);
            })
            .Accepts<IFormFile>("multipart/form-data")
            .Produces<TagExtractResponse>()
            .WithTags("tags");
    }
}
