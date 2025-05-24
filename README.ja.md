# Aloe.Utils.Configuration.Default

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![日本語](https://img.shields.io/badge/言語-日本語-blue)](./README.ja.md)

[![NuGet Version](https://img.shields.io/nuget/v/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![License](https://img.shields.io/github/license/ted-sharp/aloe-utils-configuration-default.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/download/dotnet/9.0)

`Aloe.Utils.Configuration.Default` は、.NETアプリケーションで設定ファイル、環境変数、コマンドライン引数、開発用シークレットを標準的な方法で読み込むための軽量なユーティリティです。

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
* Microsoft.Extensions.Configurationと組み合わせて使用

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
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Aloe.Utils.Configuration.Default;

// 最小限のホストビルダーを作成
var builder = Host.CreateApplicationBuilder(args);

// 1行で設定
builder.Configuration
    .SetBasePath(AppContext.BaseDirectory)
    .AddDefault<Program>(args, reloadOnChange: true);

// ホストをビルドして使用
using var host = builder.Build();
var config = host.Services.GetRequiredService<IConfiguration>();

// 設定値にアクセス
var connectionString = config.GetConnectionString("DefaultConnection");
var appName = config["Application:Name"];
```

## ライセンス

MIT License

## 貢献

バグ報告や機能リクエストはGitHub Issuesで受け付けています。プルリクエストも歓迎します。
