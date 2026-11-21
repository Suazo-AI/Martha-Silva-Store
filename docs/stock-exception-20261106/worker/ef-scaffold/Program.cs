using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.EntityFrameworkCore.Design.Internal;
using Microsoft.EntityFrameworkCore.Migrations.Design;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using var db = new InternalDbContextFactory().CreateDbContext([]);
if(args.Contains("script")) { File.WriteAllText("backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql", db.GetService<IMigrator>().GenerateScript(options:MigrationsSqlGenerationOptions.Idempotent).TrimEnd()+Environment.NewLine); return; }
var reporter = new OperationReporter(new OperationReportHandler(Console.Error.WriteLine, Console.Error.WriteLine, Console.WriteLine, _=>{}));
var assembly=typeof(InternalDbContext).Assembly;
var services=new DesignTimeServicesBuilder(assembly,assembly,reporter,[]).Build(db);
var scaffolder=services.GetRequiredService<IMigrationsScaffolder>();
var migration=scaffolder.ScaffoldMigration("PhysicalStockException", "Martha.Store.Api", "Internal.Migrations");
scaffolder.Save(Path.GetFullPath("backend/src/Martha.Store.Api"), migration, Path.GetFullPath("backend/src/Martha.Store.Api/Internal/Migrations"));
Console.WriteLine(migration.MigrationId);
