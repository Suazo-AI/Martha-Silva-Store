using Savia.Api;
using Savia.Infrastructure;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSavia();
builder.Services.AddOpenApi();

var app = builder.Build();
_ = app.Services.GetRequiredService<SqlGateway>();   // fail at start-up, not on the first request, when misconfigured
app.UseSaviaErrors();
app.MapOpenApi();                     // GET /openapi/v1.json: the contract every client is generated from
app.MapGet("/health", () => Results.Ok(new { status = "ok" })).ExcludeFromDescription();
app.MapSaviaEndpoints();
app.Run();

/// <summary>Entry point, public so the integration tests can host the API in memory.</summary>
public partial class Program;
