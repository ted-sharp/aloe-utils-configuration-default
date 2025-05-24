# Aloe.Utils.Configuration.Default

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![日本語](https://img.shields.io/badge/言語-日本語-blue)](./README.ja.md)

[![NuGet Version](https://img.shields.io/nuget/v/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Aloe.Utils.Configuration.Default.svg)](https://www.nuget.org/packages/Aloe.Utils.Configuration.Default)
[![License](https://img.shields.io/github/license/ted-sharp/aloe-utils-configuration-default.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/download/dotnet/9.0)

`Aloe.Utils.Configuration.Default` is a lightweight utility that provides a standardized way to load configuration files, environment variables, command-line arguments, and development secrets in .NET applications.

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
* Used in conjunction with Microsoft.Extensions.Configuration

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
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Aloe.Utils.Configuration.Default;

// Create a minimal host builder
var builder = Host.CreateApplicationBuilder(args);

// Configure with a single line
builder.Configuration
    .SetBasePath(AppContext.BaseDirectory)
    .AddDefault<Program>(args, reloadOnChange: true);

// Build and use the host
using var host = builder.Build();
var config = host.Services.GetRequiredService<IConfiguration>();

// Access configuration values
var connectionString = config.GetConnectionString("DefaultConnection");
var appName = config["Application:Name"];
```

## License

MIT License

## Contributing

Bug reports and feature requests are welcome on GitHub Issues. Pull requests are also appreciated. 
