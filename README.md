# Aloe.Utils.Configuration.Default

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![日本語](https://img.shields.io/badge/言語-日本語-blue)](./README.ja.md)

[![NuGet Version](https://img.shields.io/nuget/v/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![License](https://img.shields.io/github/license/ted-sharp/aloe-utils-configuration-default.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/download/dotnet/9.0)

`Aloe.Utils.Configuration.Default` is a lightweight utility that, even when using ConfigurationBuilder on its own, provides the standard loading of configuration files, environment variables, command-line arguments, and development secrets—just as HostBuilder does by default.

## Main Features

* One-line configuration setup with `AddDefault<T>` method
* Automatic loading of:
  * Base configuration file (`appsettings.json`)
  * Environment-specific configuration files (e.g., `appsettings.Development.json`)
  * User Secrets (in development environment)
  * Environment variables
  * Command-line arguments
* Support for file change monitoring with automatic reload

## Supported Environments

* .NET 9 and later
* Used in conjunction with Microsoft.Extensions.Configuration.ConfigurationBuilder

## Install

Install via NuGet Package Manager:

```cmd
Install-Package Aloe.Utils.Configuration.Default
```

Or using .NET CLI:

```cmd
dotnet add package Aloe.Utils.Configuration.Default
```

## Usage

```csharp
using Microsoft.Extensions.Configuration;
using Aloe.Utils.Configuration.Default;

// Create a ConfigurationBuilder
var configurationBuilder = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    // Not required when using Host.CreateApplicationBuilder(args) instead of ConfigurationBuilder.
    .AddDefault<Program>(args, reloadOnChange: true);

// Build and use the host
using var host = builder.Build();
var config = host.Services.GetRequiredService<IConfiguration>();

// Access configuration values
var connectionString = config.GetConnectionString("DefaultConnection");
var appName = config["Application:Name"];
```

## Notes

### Not Required When Using Generic Host

This utility is designed for use with `ConfigurationBuilder` alone, as the Generic Host already loads these items by default.
When using the Generic Host, these configurations are already loaded by default.

```csharp
// Web host builder available since ASP.NET Core 2.1
IWebHostBuilder webHostBuilder2_1 = WebHost.CreateDefaultBuilder(args);

// Generic host builder available since .NET Core 3.0
// At this time, ASP.NET Core and the interface were not unified, and the writing style was inconsistent
IHostBuilder hostBuilder3_0 = Microsoft.Extensions.Hosting.Host.CreateDefaultBuilder(args);

// Host builder introduced in .NET 6 for Minimal API
// ASP.NET Core side's response to interface unification
WebApplicationBuilder webAppBuilder6 = Microsoft.AspNetCore.Builder.WebApplication.CreateBuilder(args);

// Generic host builder introduced in .NET 7
// Interface unification and more consistent writing style
HostApplicationBuilder hostAppBuilder7 = Microsoft.Extensions.Hosting.Host.CreateApplicationBuilder(args);

// Lighter minimal configuration version added in .NET 8 (preview)
// For Minimal APIs, does not load configuration files
//WebApplicationBuilder slimBuilder8 = Microsoft.AspNetCore.Builder.WebApplication.CreateSlimBuilder(args);
```

### Build Only Once When Using `reloadOnChange: true`

When using `reloadOnChange: true` with `ConfigurationBuilder`, the monitoring becomes active and prevents garbage collection.
Therefore, if you use this setting, you should only build the configuration once at application startup.

## License

MIT License

## Contributing

Bug reports and feature requests are welcome on GitHub Issues. Pull requests are also appreciated. 
