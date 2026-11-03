using Aviation.Maui.Services;
using Aviation.Shared.Entities;
using Microsoft.Extensions.Logging;
using SyncEngine.Abstractions.Client;
using SyncEngine.Client;
using SyncEngine.Client.Sqlite;

namespace Aviation.Maui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
            });

        var dbPath = Path.Combine(FileSystem.AppDataDirectory, "aviation-sync.db");

        builder.Services.AddHttpClient();
        builder.Services.AddSyncEngineClient(options =>
        {
            options.ServerBaseAddress = "http://localhost:5080";
            options.ClientId = "maui";
            options.EnableSignalR = true;
            options.EnableTelemetryReporting = true;
        });
        builder.Services.AddSyncEngineSqlite(
            options => options.ConnectionString = $"Data Source={dbPath}",
            AviationEntityNames.All);

        builder.Services.AddSingleton<MauiSyncBootstrapper>();
        builder.Services.AddSingleton<FacilityListViewModel>();
        builder.Services.AddTransient<MainPage>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
