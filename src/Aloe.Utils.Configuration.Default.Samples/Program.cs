using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Aloe.Utils.Configuration.Default;
using Microsoft.Extensions.DependencyInjection;

// 1. .NET 9以降の最小ホスト ビルダーを作成
var builder = Host.CreateApplicationBuilder(args);

// 2. ConfigurationManager に対してベースパスと設定ファイルを設定
builder.Configuration
    .SetBasePath(AppContext.BaseDirectory)
    .AddDefault<Program>(args, reloadOnChange: true);

// 3. ビルドして IHost を生成
using var host = builder.Build();

// 4. IConfiguration を取得
var config = host.Services.GetRequiredService<IConfiguration>();

// 5. 各種設定値を取得
var defaultConn = config.GetConnectionString("DefaultConnection");
var appName = config["Application:Name"];
var appVersion = config["Application:Version"];

// 6. 出力
Console.WriteLine("=== Application Settings ===");
Console.WriteLine($"Name:    {appName}");
Console.WriteLine($"Version: {appVersion}");
Console.WriteLine();

Console.WriteLine("=== ConnectionStrings:DefaultConnection ===");
Console.WriteLine(defaultConn);
Console.WriteLine();
