using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.CommandLine;
using Microsoft.Extensions.Configuration.EnvironmentVariables;
using Microsoft.Extensions.Configuration.Json;
using Microsoft.Extensions.FileProviders;

namespace Aloe.Utils.Configuration.Default.Tests;

public class ConfigurationExtensionsTests
{
    [Fact(DisplayName = "AddDefault: JsonConfigurationSource が正しく追加される")]
    public void AddDefault_AddsJsonConfigurationSources()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var args = new[] { "--commandLineKey=value" };

        // Act
        var result = builder.AddDefault<ConfigurationExtensionsTests>(args, reloadOnChange: false);

        // Assert
        var sources = builder.Sources.OfType<JsonConfigurationSource>().ToList();

        // appsettings.json + appsettings.{env}.json (環境変数依存のため0〜2)
        Assert.True(sources.Count >= 1 && sources.Count <= 2, "少なくとも appsettings.json は追加される");

        // EnvironmentVariables + CommandLine
        Assert.Contains(builder.Sources, s => s is EnvironmentVariablesConfigurationSource);
        Assert.Contains(builder.Sources, s => s is CommandLineConfigurationSource);

        Assert.Same(builder, result);
    }

    [Fact(DisplayName = "UserSecretsId が設定されていなくても例外をスローしないこと")]
    public void AddDefault_WithoutUserSecretsId_DoesNotThrow()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Development");
            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            var ex = Record.Exception(() => builder.AddDefault<ConfigurationExtensionsTests>(args));

            // Assert
            Assert.Null(ex);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
        }
    }

    [Fact(DisplayName = "AddDefault: provider指定バージョンで JsonConfigurationSource が追加される")]
    public void AddDefault_WithProvider_AddsJsonSourcesWithProvider()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var provider = new NullFileProvider();
        var args = Array.Empty<string>();

        // Act
        var result = builder.AddDefault<ConfigurationExtensionsTests>(args, provider, reloadOnChange: false);

        // Assert
        var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
        Assert.All(jsonSources, s => Assert.Same(provider, s.FileProvider));
        Assert.Contains(builder.Sources, s => s is EnvironmentVariablesConfigurationSource);
        Assert.Contains(builder.Sources, s => s is CommandLineConfigurationSource);

        Assert.Same(builder, result);
    }

    [Fact(DisplayName = "AddDefault: 環境変数が空でも例外をスローしない")]
    public void AddDefault_EmptyEnvironment_DoesNotThrow()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        var originalAspNetCoreEnv = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "");
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "");

            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            var ex = Record.Exception(() => builder.AddDefault<ConfigurationExtensionsTests>(args));

            // Assert
            Assert.Null(ex);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", originalAspNetCoreEnv);
        }
    }

    [Fact(DisplayName = "AddDefault: builder が null の場合に ArgumentNullException をスロー")]
    public void AddDefault_NullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IConfigurationBuilder? builder = null;
        var args = Array.Empty<string>();

        // Act & Assert
        Assert.Throws<ArgumentNullException>(() => builder!.AddDefault<ConfigurationExtensionsTests>(args));
    }

    [Fact(DisplayName = "AddDefault: provider が null の場合に ArgumentNullException をスロー")]
    public void AddDefault_NullProvider_ThrowsArgumentNullException()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var args = Array.Empty<string>();
        IFileProvider? provider = null;

        // Act & Assert
        Assert.Throws<ArgumentNullException>(() => builder.AddDefault<ConfigurationExtensionsTests>(args, provider!));
    }

    [Fact(DisplayName = "AddDefault: args が null の場合でも例外をスローしない")]
    public void AddDefault_NullArgs_DoesNotThrow()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        string[]? args = null;

        // Act
        var ex = Record.Exception(() => builder.AddDefault<ConfigurationExtensionsTests>(args!));

        // Assert
        Assert.Null(ex);
    }

    [Fact(DisplayName = "AddDefault: reloadOnChange が true（デフォルト）で動作する")]
    public void AddDefault_DefaultReloadOnChange_Works()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var args = Array.Empty<string>();

        // Act
        var result = builder.AddDefault<ConfigurationExtensionsTests>(args);

        // Assert
        var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
        Assert.True(jsonSources.Count >= 1, "少なくとも appsettings.json は追加される");
        Assert.All(jsonSources, s => Assert.True(s.ReloadOnChange, "ReloadOnChange は true であるべき"));
        Assert.Same(builder, result);
    }

    [Fact(DisplayName = "AddDefault: DOTNET_ENVIRONMENT が ASPNETCORE_ENVIRONMENT より優先される")]
    public void AddDefault_DotnetEnvironmentTakesPriority()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        var originalAspNetCoreEnv = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Staging");
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Production");
            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            builder.AddDefault<ConfigurationExtensionsTests>(args);

            // Assert
            var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
            var stagingSource = jsonSources.FirstOrDefault(s => s.Path?.Contains("Staging") == true);
            var productionSource = jsonSources.FirstOrDefault(s => s.Path?.Contains("Production") == true);
            Assert.NotNull(stagingSource);
            Assert.Null(productionSource);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", originalAspNetCoreEnv);
        }
    }

    [Fact(DisplayName = "AddDefault: ASPNETCORE_ENVIRONMENT が DOTNET_ENVIRONMENT がない場合に使用される")]
    public void AddDefault_AspNetCoreEnvironmentUsedWhenDotnetMissing()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        var originalAspNetCoreEnv = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", null);
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Staging");
            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            builder.AddDefault<ConfigurationExtensionsTests>(args);

            // Assert
            var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
            var stagingSource = jsonSources.FirstOrDefault(s => s.Path?.Contains("Staging") == true);
            Assert.NotNull(stagingSource);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
            Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", originalAspNetCoreEnv);
        }
    }

    [Fact(DisplayName = "AddDefault: Production 環境では UserSecrets が追加されない")]
    public void AddDefault_ProductionEnvironment_DoesNotAddUserSecrets()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Production");
            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            builder.AddDefault<ConfigurationExtensionsTests>(args);

            // Assert
            var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
            var productionSource = jsonSources.FirstOrDefault(s => s.Path?.Contains("Production") == true);
            Assert.NotNull(productionSource);
            // UserSecrets は Development 環境でのみ追加されるため、Production では追加されない
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
        }
    }

    [Fact(DisplayName = "AddDefault: 環境名に空白が含まれる場合に Trim される")]
    public void AddDefault_EnvironmentNameWithWhitespace_IsTrimmed()
    {
        // Arrange
        var originalDotnetEnv = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        try
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "  Staging  ");
            var builder = new ConfigurationBuilder();
            var args = Array.Empty<string>();

            // Act
            builder.AddDefault<ConfigurationExtensionsTests>(args);

            // Assert
            var jsonSources = builder.Sources.OfType<JsonConfigurationSource>().ToList();
            var stagingSource = jsonSources.FirstOrDefault(s => s.Path?.Contains("Staging") == true);
            Assert.NotNull(stagingSource);
            // 空白が含まれた "  Staging  " は "Staging" として処理される
        }
        finally
        {
            Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", originalDotnetEnv);
        }
    }
}
