using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.CommandLine;
using Microsoft.Extensions.Configuration.EnvironmentVariables;
using Microsoft.Extensions.Configuration.Json;
using Microsoft.Extensions.FileProviders;

namespace Aloe.Utils.Configuration.Default.Tests;

public class AddDefaultTests
{
    [Fact(DisplayName = "AddDefault: JsonConfigurationSource が正しく追加される")]
    public void AddDefault_AddsJsonConfigurationSources()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var args = new[] { "--commandLineKey=value" };

        // Act
        var result = builder.AddDefault<AddDefaultTests>(args, reloadOnChange: false);

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
        Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Development");
        var builder = new ConfigurationBuilder();
        var args = Array.Empty<string>();

        // Act
        var ex = Record.Exception(() => builder.AddDefault<AddDefaultTests>(args));

        // Assert
        Assert.Null(ex);
    }

    [Fact(DisplayName = "AddDefault: provider指定バージョンで JsonConfigurationSource が追加される")]
    public void AddDefault_WithProvider_AddsJsonSourcesWithProvider()
    {
        // Arrange
        var builder = new ConfigurationBuilder();
        var provider = new NullFileProvider();
        var args = Array.Empty<string>();

        // Act
        var result = builder.AddDefault<AddDefaultTests>(args, provider, reloadOnChange: false);

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
        Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "");
        Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "");

        var builder = new ConfigurationBuilder();
        var args = Array.Empty<string>();

        // Act
        var ex = Record.Exception(() => builder.AddDefault<AddDefaultTests>(args));

        // Assert
        Assert.Null(ex);
    }
}
