using Aloe.Utils.Configuration.Default;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

// 1. ConfigurationBuilderを作成
var configurationBuilder = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    // ConfigurationBuilder ではなく Host.CreateApplicationBuilder(args); を使う場合は不要です。
    .AddDefault<Program>(args, reloadOnChange: true);

// 2. IConfigurationを構築
var configuration = configurationBuilder.Build();

// 3. 各種設定値を取得
var defaultConn = configuration.GetConnectionString("DefaultConnection");
var appName = configuration["Application:Name"];
var appVersion = configuration["Application:Version"];

// 4. 出力
Console.WriteLine("=== Application Settings ===");
Console.WriteLine($"Name:    {appName}");
Console.WriteLine($"Version: {appVersion}");
Console.WriteLine();

Console.WriteLine("=== ConnectionStrings:DefaultConnection ===");
Console.WriteLine(defaultConn);
Console.WriteLine();
