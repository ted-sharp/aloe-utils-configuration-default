# Aloe.Utils.Configuration.Default

A lightweight utility that provides a standardized way to load configuration files, environment variables, command-line arguments, and development secrets in .NET applications.

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
