# Aloe.Utils.Configuration.Default

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![日本語](https://img.shields.io/badge/言語-日本語-blue)](./README.ja.md)

[![NuGet Version](https://img.shields.io/nuget/v/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![License](https://img.shields.io/github/license/ted-sharp/aloe-utils-configuration-default.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/download/dotnet/9.0)

`Aloe.Utils.Configuration.Default` は、`ConfigurationBuilder` を単独で使う場合でも `HostBuilder` でデフォルトで読み込まれる、設定ファイル、環境変数、コマンドライン引数、開発用シークレットを標準的な方法で読み込むための軽量なユーティリティです。

## 主な機能

* `AddDefault<T>`メソッドによる1行での設定
* 以下の自動読み込み:
  * 基本設定ファイル（`appsettings.json`）
  * 環境別設定ファイル（例：`appsettings.Development.json`）
  * 開発環境でのUser Secrets
  * 環境変数
  * コマンドライン引数
* ファイル変更の監視と自動再読み込みのサポート

## 対応環境

* .NET 9以降
* Microsoft.Extensions.Configuration.ConfigurationBuilderと組み合わせて使用

## インストール

NuGetパッケージマネージャーを使用してインストール:

```cmd
Install-Package Aloe.Utils.Configuration.Default
```

または.NET CLIを使用:

```cmd
dotnet add package Aloe.Utils.Configuration.Default
```

## 使用方法

```csharp
using Microsoft.Extensions.Configuration;
using Aloe.Utils.Configuration.Default;

// ConfigurationBuilderを作成
var configurationBuilder = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    // ConfigurationBuilder ではなく Host.CreateApplicationBuilder(args); を使う場合は不要です。
    .AddDefault<Program>(args, reloadOnChange: true);

// ホストをビルドして使用
using var host = builder.Build();
var config = host.Services.GetRequiredService<IConfiguration>();

// 設定値にアクセス
var connectionString = config.GetConnectionString("DefaultConnection");
var appName = config["Application:Name"];
```

## 注意

### 汎用ホストを使う場合は不要

`ConfigurationBuilder` を単独で使う場合を想定しているため、汎用ホストを使う場合は不要です。
汎用ホストの場合は宣言時に同様の項目がデフォルトで読み込まれています。

```csharp
// ASP.NET Core 2.1 から利用可能になった Web ホスト構築方式
IWebHostBuilder webHostBuilder2_1 = WebHost.CreateDefaultBuilder(args);

// .NET Core 3.0 から利用可能になった汎用ホスト構築方式
// この時は ASP.NET Core 側とインターフェースが共通化されておらず、さらに記述方法がバラバラで混乱の元だった
IHostBuilder hostBuilder3_0 = Microsoft.Extensions.Hosting.Host.CreateDefaultBuilder(args);

// .NET 6 から導入された Minimal API 兼用のホスト構築方式
// インターフェース共通化へのASP.NET Core側の対応
WebApplicationBuilder webAppBuilder6 = Microsoft.AspNetCore.Builder.WebApplication.CreateBuilder(args);

// .NET 7 から導入された汎用ホスト構築方式
// インターフェースが共通化され、ある程度共通で記述できるようになった
HostApplicationBuilder hostAppBuilder7 = Microsoft.Extensions.Hosting.Host.CreateApplicationBuilder(args);

// .NET 8（プレビュー）で追加された、より軽量な最小構成版
// Minimal API向け、設定ファイルは読み込まない
//WebApplicationBuilder slimBuilder8 = Microsoft.AspNetCore.Builder.WebApplication.CreateSlimBuilder(args);
```

### `reloadOnChange: true` を設定する場合は1回だけビルドする

`ConfigurationBuilder` では、`reloadOnChange: true` にすると、監視が有効になるため GC で解放されなくなります。
そのため、読み込む場合はアプリケーションの開始時に一度だけ行います。

## ライセンス

MIT License

## 貢献

バグ報告や機能リクエストはGitHub Issuesで受け付けています。プルリクエストも歓迎します。
