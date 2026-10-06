using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using TaskLite.Web.Data;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers().AddJsonOptions(options =>
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter(allowIntegerValues: false)));
builder.Services.AddProblemDetails();
var connection = builder.Configuration.GetConnectionString("TaskLite")
    ?? throw new InvalidOperationException("Set ConnectionStrings__TaskLite before starting the application.");
builder.Services.AddDbContext<TaskLiteDbContext>(options => options.UseSqlServer(connection));
var app = builder.Build();
app.UseExceptionHandler();
if (args.Contains("--migrate"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<TaskLiteDbContext>().Database.MigrateAsync();
    return;
}
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapControllers();
app.MapGet("/health", async (TaskLiteDbContext db, CancellationToken ct) =>
    await db.Database.CanConnectAsync(ct) ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503));
app.Run();
