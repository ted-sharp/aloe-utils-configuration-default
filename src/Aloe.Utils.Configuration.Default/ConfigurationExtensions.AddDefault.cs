// <copyright file="ConfigurationExtensions.AddDefault.cs" company="ted-sharp">
// Copyright (c) ted-sharp. All rights reserved.
// </copyright>

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;

// ReSharper disable ArrangeStaticMemberQualifier
namespace Aloe.Utils.Configuration.Default;

/// <summary>
/// ConfigurationBuilderの拡張メソッドを提供します。
/// </summary>
public static partial class ConfigurationExtensions
{
    /// <summary>
    /// IConfigurationBuilder に対して、標準的な設定ファイル・環境変数・コマンドライン引数・
    /// 開発用シークレットの読み込みを一括で追加します。
    /// </summary>
    /// <typeparam name="T">
    /// UserSecrets を使用する際の識別用型。この型が属するアセンブリの .csproj に
    /// UserSecretsId が設定されている必要があります。
    /// </typeparam>
    /// <param name="builder">構成ビルダーインスタンス</param>
    /// <param name="args">Main メソッドのコマンドライン引数</param>
    /// <param name="reloadOnChange">
    /// 設定ファイルの変更時に自動で再読み込みを行うかどうか。デフォルトは true。
    /// </param>
    /// <returns>構成ソースが追加された構成ビルダー（チェーン呼び出し可能）</returns>
    public static IConfigurationBuilder AddDefault<T>(
        this IConfigurationBuilder builder,
        string[] args,
        bool reloadOnChange = true)
        where T : class
    {
        var env = GetEnvironmentName();

        // appsettings.json を追加（ベース設定ファイル）
        _ = builder.AddJsonFile("appsettings.json", optional: true, reloadOnChange);

        // 環境ごとの設定ファイル（例：appsettings.Development.json）を追加
        if (!String.IsNullOrWhiteSpace(env))
        {
            _ = builder.AddJsonFile($"appsettings.{env}.json", optional: true, reloadOnChange);

            // 開発環境の場合は UserSecrets を追加
            if (IsDevelopment(env))
            {
                _ = builder.AddUserSecrets<T>(reloadOnChange);
            }
        }

        // 環境変数（DOTNET_ や ASPNETCORE_ プレフィックスなど）を読み込み
        _ = builder.AddEnvironmentVariables();

        // コマンドライン引数からの構成を追加
        _ = builder.AddCommandLine(args ?? Array.Empty<string>());

        return builder;
    }

    /// <summary>
    /// IConfigurationBuilder に対して、標準的な設定ファイル・環境変数・コマンドライン引数・
    /// 開発用シークレットの読み込みを一括で追加します。
    /// </summary>
    /// <typeparam name="T">
    /// UserSecrets を使用する際の識別用型。この型が属するアセンブリの .csproj に
    /// UserSecretsId が設定されている必要があります。
    /// </typeparam>
    /// <param name="builder">構成ビルダーインスタンス</param>
    /// <param name="args">Main メソッドのコマンドライン引数</param>
    /// <param name="provider">ファイルプロバイダー</param>
    /// <param name="reloadOnChange">
    /// 設定ファイルの変更時に自動で再読み込みを行うかどうか。デフォルトは true。
    /// </param>
    /// <returns>構成ソースが追加された構成ビルダー（チェーン呼び出し可能）</returns>
    public static IConfigurationBuilder AddDefault<T>(
        this IConfigurationBuilder builder,
        string[] args,
        IFileProvider provider,
        bool reloadOnChange = true)
        where T : class
    {
        // 実行環境名（Development / Staging / Production など）を取得
        // DOTNET_ENVIRONMENT を優先し、なければ ASPNETCORE_ENVIRONMENT を参照
        var env = GetEnvironmentName();

        // appsettings.json を追加（ベース設定ファイル）
        _ = builder.AddJsonFile(provider, "appsettings.json", optional: true, reloadOnChange);

        // 環境ごとの設定ファイル（例：appsettings.Development.json）を追加
        if (!String.IsNullOrWhiteSpace(env))
        {
            _ = builder.AddJsonFile(provider, $"appsettings.{env}.json", optional: true, reloadOnChange);

            // 開発環境の場合は UserSecrets を追加
            if (IsDevelopment(env))
            {
                _ = builder.AddUserSecrets<T>(reloadOnChange);
            }
        }

        // 環境変数（DOTNET_ や ASPNETCORE_ プレフィックスなど）を読み込み
        _ = builder.AddEnvironmentVariables();

        // コマンドライン引数からの構成を追加
        _ = builder.AddCommandLine(args ?? Array.Empty<string>());

        return builder;
    }

    /// <summary>
    /// 実行環境名（Development / Staging / Production など）を取得
    /// DOTNET_ENVIRONMENT を優先し、なければ ASPNETCORE_ENVIRONMENT を参照
    /// </summary>
    /// <returns>実行環境名</returns>
    private static string? GetEnvironmentName()
    {
        return (Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ??
                Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"))?.Trim();
    }

    /// <summary>
    /// 開発環境かどうか判定します。
    /// </summary>
    /// <param name="env">実行環境名</param>
    /// <returns>Development が指定されていた場合は true</returns>
    private static bool IsDevelopment(string? env)
    {
        return String.Equals(env, "Development", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// 指定された型 <typeparamref name="T"/> に基づいて UserSecrets を構成に追加します。
    /// 開発環境でのみ有効であり、例外が発生しても安全にスキップされます。
    /// </summary>
    /// <typeparam name="T">
    /// UserSecretsId 属性が付加された型。通常は Program クラスなど、構成情報を管理するクラスを指定します。
    /// </typeparam>
    /// <param name="builder">拡張対象の <see cref="IConfigurationBuilder"/>。</param>
    /// <param name="reloadOnChange">
    /// secrets.json の変更を自動的に検出して再読み込みするかどうか。通常は true。
    /// </param>
    /// <returns>
    /// 自身を返します。メソッドチェーンが可能です。
    /// </returns>
    private static IConfigurationBuilder AddUserSecrets<T>(
        this IConfigurationBuilder builder,
        bool reloadOnChange)
        where T : class
    {
        try
        {
            // 指定された型 T のアセンブリに UserSecretsId 属性がある場合に secrets.json を読み込む
            _ = builder.AddUserSecrets<T>(optional: true, reloadOnChange);
        }
        catch (Exception ex) when (
            ex is FileNotFoundException
            or InvalidOperationException
            or PlatformNotSupportedException)
        {
            // UserSecrets の使用条件を満たさない場合は安全にスキップ
        }

        return builder;
    }
}
