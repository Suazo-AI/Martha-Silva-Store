using Savia.Api;
using Savia.Infrastructure;

var provision = args.Length > 0 && args[0] == Provisioning.Command;
var builder = WebApplication.CreateBuilder(provision ? args[1..] : args);
builder.Services.AddSavia();
builder.Services.AddSaviaTags();   // tag photo -> product fields, local OCR only (docs/pilot/ETIQUETA.md)
builder.Services.AddOpenApi();
builder.Services.AddSingleton<Savia.Application.SyncStatus>();
builder.Services.AddHostedService<SyncWorker>();   // branch to hub sync, off unless Savia:Sync:HubUrl is set (docs/sync/P9-SPEC.md)
builder.Services.AddSaviaHosting();   // proxy, HTTPS, headers, login limit (savia/docs/deploy/AZURE.md)
builder.Services.AddSaviaWebStore();  // public order path: CORS, limits, Turnstile, payments, expiry (savia/docs/webstore/ORDER-PATH.md)
builder.AddSaviaTelemetry();          // Application Insights, off unless APPLICATIONINSIGHTS_CONNECTION_STRING is set

var app = builder.Build();
_ = app.Services.GetRequiredService<SqlGateway>();   // fail at start-up, not on the first request, when misconfigured
if (provision) return await Provisioning.RunAsync(app.Services, app.Configuration);
_ = app.Services.GetRequiredService<IBotCheck>();    // refuses to start when the bot check is off in Production (SEC-38)

app.UseSaviaHosting();
app.UseSaviaErrors();
app.UseSaviaWeb(builder.Configuration["Savia:Web:Root"]);
// GET /openapi/v1.json: the contract every client is generated from. Not served in Production, where it would list
// every staff route to anyone (SEC-48).
if (!app.Environment.IsProduction()) app.MapOpenApi().RequireRateLimiting(SaviaHosting.StaffPolicy);
app.MapSaviaHealth();
app.MapSaviaEndpoints();
app.Run();
return 0;

/// <summary>Entry point, public so the integration tests can host the API in memory.</summary>
public partial class Program;
