# Enhanced Code Quality Fix & Verification
# 高性能な並列実行・キャッシュ機能付きコード品質改善スクリプト

param(
    [switch]$CheckOnly = $false,
    [switch]$SkipSonar = $false,
    [switch]$SkipReSharper = $false,
    [switch]$Fast = $false,
    [switch]$NoCache = $false,
    [string]$SonarUrl = $env:SONAR_HOST_URL,
    [string]$SonarToken = $env:SONAR_TOKEN,
    [string]$ProjectKey = "",
    [string]$ProjectName = "",
    [string]$ConfigFile = "quality-config.json"
)

# ===========================================
# Configuration Loading
# ===========================================
function Load-QualityConfig {
    param([string]$configPath)

    $defaultConfig = @{
        general = @{
            maxParallelJobs = 3
            enableCache = $true
            cacheDirectory = ".quality-cache"
            reportDirectory = "quality-reports"
        }
        sonar = @{
            url = "http://localhost:9000"
            timeout = 300
            skipOnFailure = $false
            enableLocalReports = $true
        }
        resharper = @{
            cleanupProfile = "Default"
            inspectionSeverity = "WARNING"
            enableCleanup = $true
            enableInspection = $true
        }
        build = @{
            configuration = "Release"
            verbosity = "quiet"
            showTopWarningsCount = 5
        }
        cache = @{
            enabled = $true
            hashAlgorithm = "SHA256"
            excludePatterns = @("**/obj/**", "**/bin/**", "**/.vs/**")
        }
    }

    if (Test-Path $configPath) {
        try {
            $fileConfig = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            # Merge with defaults
            return Merge-Hashtables $defaultConfig $fileConfig
        } catch {
            Write-Host "  ⚠ Failed to load config file, using defaults: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    return $defaultConfig
}

function Merge-Hashtables($default, $custom) {
    $result = $default.Clone()
    foreach ($key in $custom.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $custom[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtables $result[$key] $custom[$key]
        } else {
            $result[$key] = $custom[$key]
        }
    }
    return $result
}

# ===========================================
# Cache System
# ===========================================
function Get-ProjectHash {
    param($config)

    $files = Get-ChildItem -Path . -Recurse -Include *.cs, *.csproj, *.sln |
             Where-Object {
                 $exclude = $false
                 foreach ($pattern in $config.cache.excludePatterns) {
                     if ($_.FullName -like $pattern) {
                         $exclude = $true
                         break
                     }
                 }
                 -not $exclude
             }

    $hashInput = ($files | ForEach-Object {
        "$($_.FullName):$($_.LastWriteTime.Ticks)"
    }) -join "|"

    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($config.cache.hashAlgorithm)
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
    return [System.BitConverter]::ToString($hashBytes) -replace '-', ''
}

function Test-CacheValid {
    param($cacheDir, $currentHash)

    $hashFile = Join-Path $cacheDir "project.hash"
    $resultFile = Join-Path $cacheDir "last-result.json"

    if (-not (Test-Path $hashFile) -or -not (Test-Path $resultFile)) {
        return $false
    }

    $cachedHash = Get-Content $hashFile -ErrorAction SilentlyContinue
    return $cachedHash -eq $currentHash
}

function Save-CacheResult {
    param($cacheDir, $hash, $result)

    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    $hash | Out-File -FilePath (Join-Path $cacheDir "project.hash") -Encoding UTF8
    $result | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $cacheDir "last-result.json") -Encoding UTF8
}

# ===========================================
# Parallel Task Runner
# ===========================================
function Invoke-ParallelTasks {
    param(
        [array]$Tasks,
        [int]$MaxJobs = 3,
        [int]$TimeoutSeconds = 600
    )

    $jobs = @()
    $results = @{}

    try {
        # Start jobs
        foreach ($task in $Tasks) {
            if ($jobs.Count -ge $MaxJobs) {
                # Wait for a job to complete
                $completed = $jobs | Wait-Job -Any -Timeout 1
                if ($completed) {
                    $results[$completed.Name] = Receive-Job $completed
                    Remove-Job $completed
                    $jobs = $jobs | Where-Object { $_.Id -ne $completed.Id }
                }
            }

            $job = Start-Job -Name $task.Name -ScriptBlock $task.ScriptBlock -ArgumentList $task.Arguments
            $jobs += $job
        }

        # Wait for remaining jobs
        if ($jobs.Count -gt 0) {
            $completed = $jobs | Wait-Job -Timeout $TimeoutSeconds
            foreach ($job in $jobs) {
                $results[$job.Name] = Receive-Job $job
                Remove-Job $job
            }
        }

        return $results
    } catch {
        # Cleanup on error
        $jobs | Stop-Job -PassThru | Remove-Job
        throw
    }
}

# ===========================================
# Enhanced Task Definitions
# ===========================================
function Get-TaskDefinitions {
    param($config, $solutionName, $solutionBaseName, $checkOnly, $skipReSharper, $skipSonar)

    $tasks = @()

    # Task 1: ReSharper Cleanup
    if (-not $skipReSharper -and -not $checkOnly -and $config.resharper.enableCleanup) {
        $tasks += @{
            Name = "ReSharperCleanup"
            ScriptBlock = {
                param($solution, $baseName, $profile)

                $cleanupCode = Get-Command cleanupcode -ErrorAction SilentlyContinue
                if (-not $cleanupCode) {
                    return @{ Success = $false; Message = "ReSharper CLI not found" }
                }

                # Create settings if not exists
                $settingsFile = "$baseName.sln.DotSettings"
                if (-not (Test-Path $settingsFile)) {
                    $defaultSettings = @"
<wpf:ResourceDictionary xml:space="preserve" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" xmlns:s="clr-namespace:System;assembly=mscorlib" xmlns:ss="urn:shemas-jetbrains-com:settings-storage-xaml" xmlns:wpf="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
	<s:String x:Key="/Default/CodeStyle/CodeCleanup/Profiles/=Default/@EntryIndexedValue">&lt;?xml version="1.0" encoding="utf-16"?&gt;&lt;Profile name="Default"&gt;&lt;CSReorderTypeMembers&gt;True&lt;/CSReorderTypeMembers&gt;&lt;CSUpdateFileHeader&gt;True&lt;/CSUpdateFileHeader&gt;&lt;CSOptimizeUsings&gt;&lt;OptimizeUsings&gt;True&lt;/OptimizeUsings&gt;&lt;/CSOptimizeUsings&gt;&lt;CSArrangeThisQualifier&gt;True&lt;/CSArrangeThisQualifier&gt;&lt;CSUseAutoProperty&gt;True&lt;/CSUseAutoProperty&gt;&lt;CSMakeFieldReadonly&gt;True&lt;/CSMakeFieldReadonly&gt;&lt;CSArrangeQualifiers&gt;True&lt;/CSArrangeQualifiers&gt;&lt;/Profile&gt;</s:String>
	<s:String x:Key="/Default/CodeStyle/CodeCleanup/SilentCleanupProfile/@EntryValue">Default</s:String>
</wpf:ResourceDictionary>
"@
                    $defaultSettings | Out-File -FilePath $settingsFile -Encoding UTF8
                }

                cleanupcode $solution --profile=$profile 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    $gitStatus = git status --short 2>$null | Where-Object { $_ -match '\.cs$' }
                    $fixedCount = ($gitStatus | Measure-Object).Count
                    return @{ Success = $true; Message = "Cleanup completed"; FixedFiles = $fixedCount }
                } else {
                    return @{ Success = $false; Message = "Cleanup failed"; ExitCode = $LASTEXITCODE }
                }
            }
            Arguments = @($solutionName, $solutionBaseName, $config.resharper.cleanupProfile)
        }
    }

    # Task 2: dotnet format
    $tasks += @{
        Name = "DotNetFormat"
        ScriptBlock = {
            param($solution, $checkOnly, $verbosity)

            if ($checkOnly) {
                dotnet format $solution --verify-no-changes --verbosity $verbosity 2>&1 | Out-Null
                $result = $LASTEXITCODE
                return @{ Success = ($result -eq 0); Message = "Format verification"; ExitCode = $result }
            } else {
                dotnet format $solution --verbosity $verbosity 2>&1 | Out-Null
                return @{ Success = ($LASTEXITCODE -eq 0); Message = "Format completed"; ExitCode = $LASTEXITCODE }
            }
        }
        Arguments = @($solutionName, $checkOnly, $config.build.verbosity)
    }

    # Task 3: Build
    $tasks += @{
        Name = "Build"
        ScriptBlock = {
            param($solution, $configuration, $verbosity)

            $buildOutput = dotnet build $solution --configuration $configuration --verbosity $verbosity 2>&1
            $buildResult = $LASTEXITCODE

            $warnings = ($buildOutput | Select-String -Pattern "warning" -AllMatches).Matches.Count

            return @{
                Success = ($buildResult -eq 0)
                Message = "Build completed"
                ExitCode = $buildResult
                Warnings = $warnings
                Output = $buildOutput
            }
        }
        Arguments = @($solutionName, $config.build.configuration, $config.build.verbosity)
    }

    return $tasks
}

# ===========================================
# Main Script
# ===========================================

# Load configuration
$configPath = if (Test-Path $ConfigFile) { $ConfigFile } else { Join-Path $PSScriptRoot $ConfigFile }
$config = Load-QualityConfig $configPath

# Override with parameters
if ($NoCache) { $config.general.enableCache = $false }
if ($Fast) {
    $SkipReSharper = $true
    $SkipSonar = $true
}

# Solution detection
$solutionFile = Get-ChildItem -Path . -Filter *.sln | Select-Object -First 1
if (-not $solutionFile) {
    Write-Host "✗ Error: No solution file (.sln) found in current directory" -ForegroundColor Red
    exit 1
}

$solutionName = $solutionFile.Name
$solutionBaseName = $solutionFile.BaseName

# Project key/name auto-generation
if ([string]::IsNullOrEmpty($ProjectKey)) {
    $ProjectKey = $solutionBaseName.ToLower() -replace '\s+', '-'
}
if ([string]::IsNullOrEmpty($ProjectName)) {
    $ProjectName = $solutionBaseName
}

# Default SonarQube URL
if ([string]::IsNullOrEmpty($SonarUrl)) {
    $SonarUrl = $config.sonar.url
}

# Statistics
$script:ErrorCount = 0
$script:WarningCount = 0
$script:FixedFileCount = 0
$script:TaskResults = @{}

# Cache check
$cacheDir = $config.general.cacheDirectory
$useCache = $config.general.enableCache -and -not $CheckOnly -and -not $NoCache

if ($useCache) {
    $projectHash = Get-ProjectHash $config
    if (Test-CacheValid $cacheDir $projectHash) {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  ✓ NO CHANGES DETECTED" -ForegroundColor Green
        Write-Host "  Using cached results" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan

        $cachedResult = Get-Content (Join-Path $cacheDir "last-result.json") | ConvertFrom-Json
        Write-Host "Previous run results:" -ForegroundColor Cyan
        Write-Host "  Errors: $($cachedResult.ErrorCount)" -ForegroundColor Gray
        Write-Host "  Warnings: $($cachedResult.WarningCount)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Use -NoCache to force re-analysis" -ForegroundColor Yellow
        exit $cachedResult.ExitCode
    }
}

# Header
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Enhanced Code Quality Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Solution: $solutionName" -ForegroundColor Cyan
Write-Host "Project Key: $ProjectKey" -ForegroundColor Gray
Write-Host "Project Name: $ProjectName" -ForegroundColor Gray
Write-Host "Config: $configPath" -ForegroundColor Gray
Write-Host ""

if ($CheckOnly) {
    Write-Host "Mode: VERIFICATION ONLY (CI/PR Gate)" -ForegroundColor Yellow
} else {
    Write-Host "Mode: AUTO-FIX (Parallel Execution)" -ForegroundColor Green
}

if ($SkipReSharper) { Write-Host "  - Skip ReSharper tools" -ForegroundColor Gray }
if ($SkipSonar) { Write-Host "  - Skip SonarQube analysis" -ForegroundColor Gray }
if ($useCache) { Write-Host "  - Cache enabled" -ForegroundColor Gray }
Write-Host ""

# ===========================================
# Parallel Task Execution
# ===========================================
Write-Host "Executing tasks in parallel..." -ForegroundColor Yellow
Write-Host ""

$tasks = Get-TaskDefinitions $config $solutionName $solutionBaseName $CheckOnly $SkipReSharper $SkipSonar

if ($tasks.Count -gt 0) {
    try {
        $taskResults = Invoke-ParallelTasks -Tasks $tasks -MaxJobs $config.general.maxParallelJobs

        # Process results
        foreach ($taskName in $taskResults.Keys) {
            $result = $taskResults[$taskName]
            $script:TaskResults[$taskName] = $result

            switch ($taskName) {
                "ReSharperCleanup" {
                    Write-Host "[1/6] ReSharper Cleanup..." -ForegroundColor Yellow
                    if ($result.Success) {
                        Write-Host "  ✓ $($result.Message)" -ForegroundColor Green
                        if ($result.FixedFiles -gt 0) {
                            $script:FixedFileCount += $result.FixedFiles
                            Write-Host "    Fixed $($result.FixedFiles) file(s)" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "  ✗ $($result.Message)" -ForegroundColor Red
                        $script:ErrorCount++
                    }
                }
                "DotNetFormat" {
                    Write-Host "[2/6] dotnet format..." -ForegroundColor Yellow
                    if ($result.Success) {
                        Write-Host "  ✓ $($result.Message)" -ForegroundColor Green
                    } else {
                        if ($CheckOnly) {
                            Write-Host "  ✗ Format issues found" -ForegroundColor Red
                        } else {
                            Write-Host "  ⚠ Some files could not be formatted" -ForegroundColor Yellow
                            $script:WarningCount++
                        }
                        $script:ErrorCount++
                    }
                }
                "Build" {
                    Write-Host "[3/6] Build & Warnings..." -ForegroundColor Yellow
                    if ($result.Success) {
                        Write-Host "  ✓ Build succeeded" -ForegroundColor Green
                        if ($result.Warnings -eq 0) {
                            Write-Host "  ✓ No warnings" -ForegroundColor Green
                        } else {
                            Write-Host "  ⚠ $($result.Warnings) warning(s) found" -ForegroundColor Yellow
                            $script:WarningCount += $result.Warnings

                            # Show top warnings
                            $topWarnings = $result.Output | Select-String -Pattern "warning" | Select-Object -First $config.build.showTopWarningsCount
                            if ($topWarnings) {
                                Write-Host "    Top warnings:" -ForegroundColor Gray
                                $topWarnings | ForEach-Object {
                                    $line = $_.Line -replace '.*\\([^\\]+\.cs)\((\d+),\d+\): warning ([^:]+):.*', '$1:$2 - $3'
                                    Write-Host "      $line" -ForegroundColor DarkGray
                                }
                            }
                        }
                    } else {
                        Write-Host "  ✗ Build failed" -ForegroundColor Red
                        $script:ErrorCount++
                    }
                }
            }
            Write-Host ""
        }
    } catch {
        Write-Host "✗ Error during parallel execution: $($_.Exception.Message)" -ForegroundColor Red
        $script:ErrorCount++
    }
}

# ===========================================
# Sequential Tasks (ReSharper Inspection & SonarQube)
# ===========================================

# Step 4: ReSharper Inspection
if (-not $SkipReSharper -and $config.resharper.enableInspection) {
    Write-Host "[4/6] ReSharper Inspection..." -ForegroundColor Yellow

    $inspectCode = Get-Command inspectcode -ErrorAction SilentlyContinue
    if (-not $inspectCode) {
        Write-Host "  ⚠ ReSharper CLI not found (skipping)" -ForegroundColor Yellow
        Write-Host "    Install: dotnet tool install -g JetBrains.ReSharper.GlobalTools" -ForegroundColor Gray
    } else {
        $outputDir = Join-Path $config.general.reportDirectory "resharper"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $outputFile = Join-Path $outputDir "inspection-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"

        Write-Host "  Running inspection..." -ForegroundColor Gray
        inspectcode $solutionName --output=$outputFile --format=Xml --no-build --severity=$($config.resharper.inspectionSeverity) 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0 -and (Test-Path $outputFile)) {
            [xml]$results = Get-Content $outputFile
            $issues = $results.Report.Issues.Project.Issue

            if ($issues) {
                $errorCount = ($issues | Where-Object { $_.Severity -eq "ERROR" }).Count
                $warningCount = ($issues | Where-Object { $_.Severity -eq "WARNING" }).Count

                if ($errorCount -gt 0) {
                    Write-Host "  ✗ $errorCount error(s) found" -ForegroundColor Red
                    $script:ErrorCount += $errorCount
                } else {
                    Write-Host "  ✓ No errors" -ForegroundColor Green
                }

                if ($warningCount -gt 0) {
                    Write-Host "  ⚠ $warningCount warning(s) found" -ForegroundColor Yellow
                    $script:WarningCount += $warningCount
                }

                Write-Host "  Report: $outputFile" -ForegroundColor Gray
            } else {
                Write-Host "  ✓ No issues found" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ Inspection failed" -ForegroundColor Red
            $script:ErrorCount++
        }
    }
    Write-Host ""
} else {
    Write-Host "[4/6] ReSharper Inspection (skipped)" -ForegroundColor Gray
    Write-Host ""
}

# Step 5: SonarQube Analysis
if (-not $SkipSonar) {
    Write-Host "[5/6] SonarQube Analysis..." -ForegroundColor Yellow

    if ([string]::IsNullOrEmpty($SonarToken)) {
        Write-Host "  ⚠ SONAR_TOKEN not set (skipping)" -ForegroundColor Yellow
        Write-Host '    Set: $env:SONAR_TOKEN = "your-token"' -ForegroundColor Gray
    } else {
        # SonarScanner installation check
        $scannerCheck = dotnet tool list --global | Select-String "dotnet-sonarscanner"
        if ($null -eq $scannerCheck) {
            Write-Host "  Installing SonarScanner..." -ForegroundColor Gray
            dotnet tool install --global dotnet-sonarscanner 2>&1 | Out-Null
        }

        Write-Host "  Running analysis..." -ForegroundColor Gray

        # Begin analysis
        dotnet sonarscanner begin `
            /k:$ProjectKey `
            /n:$ProjectName `
            /d:sonar.host.url=$SonarUrl `
            /d:sonar.token=$SonarToken `
            2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ Failed to start analysis" -ForegroundColor Red
            $script:ErrorCount++
        } else {
            # Build for SonarQube
            dotnet build $solutionName --configuration $($config.build.configuration) --no-restore 2>&1 | Out-Null

            # End analysis
            dotnet sonarscanner end /d:sonar.token=$SonarToken 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Analysis completed" -ForegroundColor Green
                Write-Host "  Dashboard: $SonarUrl/dashboard?id=$ProjectKey" -ForegroundColor Cyan

                # Generate local reports if enabled
                if ($config.sonar.enableLocalReports) {
                    Start-Sleep -Seconds 5
                    try {
                        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${SonarToken}:"))
                        $headers = @{ Authorization = "Basic $base64AuthInfo" }

                        # Get metrics
                        $metricsKeys = $config.sonar.metricsToCollect -join ","
                        $metricsUrl = "$SonarUrl/api/measures/component?component=$ProjectKey&metricKeys=$metricsKeys"
                        $metricsResponse = Invoke-RestMethod -Uri $metricsUrl -Headers $headers -Method Get -TimeoutSec $config.sonar.timeout

                        $bugs = ($metricsResponse.component.measures | Where-Object { $_.metric -eq "bugs" }).value
                        $vulnerabilities = ($metricsResponse.component.measures | Where-Object { $_.metric -eq "vulnerabilities" }).value
                        $codeSmells = ($metricsResponse.component.measures | Where-Object { $_.metric -eq "code_smells" }).value

                        Write-Host "    Bugs: $bugs | Vulnerabilities: $vulnerabilities | Code Smells: $codeSmells" -ForegroundColor Gray

                        # Save local reports
                        $sonarOutputDir = Join-Path $config.general.reportDirectory "sonarqube"
                        if (-not (Test-Path $sonarOutputDir)) {
                            New-Item -ItemType Directory -Path $sonarOutputDir -Force | Out-Null
                        }

                        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

                        # Save metrics report
                        $metricsFile = Join-Path $sonarOutputDir "metrics-$timestamp.json"
                        $metricsResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsFile -Encoding UTF8

                        # Get and save issues
                        $issuesUrl = "$SonarUrl/api/issues/search?componentKeys=$ProjectKey&resolved=false&ps=500"
                        $issuesResponse = Invoke-RestMethod -Uri $issuesUrl -Headers $headers -Method Get -TimeoutSec $config.sonar.timeout
                        $issuesFile = Join-Path $sonarOutputDir "issues-$timestamp.json"
                        $issuesResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath $issuesFile -Encoding UTF8

                        Write-Host "    Reports saved:" -ForegroundColor Gray
                        Write-Host "      $metricsFile" -ForegroundColor DarkGray
                        Write-Host "      $issuesFile" -ForegroundColor DarkGray
                    } catch {
                        Write-Host "    ⚠ Failed to save local reports: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "  ✗ Analysis failed" -ForegroundColor Red
                $script:ErrorCount++
            }
        }
    }
    Write-Host ""
} else {
    Write-Host "[5/6] SonarQube Analysis (skipped)" -ForegroundColor Gray
    Write-Host ""
}

# ===========================================
# Step 6: Final Summary
# ===========================================
Write-Host "[6/6] Summary" -ForegroundColor Yellow

# Modified files (if not check-only mode)
if (-not $CheckOnly) {
    $gitStatus = git status --short 2>$null | Where-Object { $_ -match '\.cs$' }
    $modifiedCount = ($gitStatus | Measure-Object).Count

    if ($modifiedCount -gt 0) {
        Write-Host "  Modified files: $modifiedCount" -ForegroundColor Cyan
        $gitStatus | Select-Object -First 5 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
        if ($modifiedCount -gt 5) {
            Write-Host "    ... and $($modifiedCount - 5) more" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No files were modified" -ForegroundColor Green
    }
    Write-Host ""
}

# Code statistics
Write-Host "  Code statistics:" -ForegroundColor Cyan
$csFiles = Get-ChildItem -Path . -Recurse -Include *.cs | Where-Object { $_.FullName -notmatch '\\(obj|bin)\\' }
$totalFiles = $csFiles.Count
$totalLines = 0
foreach ($file in $csFiles) {
    $totalLines += (Get-Content $file.FullName -ErrorAction SilentlyContinue).Count
}
Write-Host "    Files: $totalFiles | Lines: $totalLines" -ForegroundColor Gray
Write-Host ""

# Cache result
if ($useCache) {
    $cacheResult = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ErrorCount = $script:ErrorCount
        WarningCount = $script:WarningCount
        ExitCode = if ($script:ErrorCount -gt 0) { 1 } else { 0 }
        Results = $script:TaskResults
    }
    Save-CacheResult $cacheDir $projectHash $cacheResult
    Write-Host "  Cache updated" -ForegroundColor Gray
    Write-Host ""
}

# Final result
Write-Host "========================================" -ForegroundColor Cyan
if ($script:ErrorCount -eq 0 -and $script:WarningCount -eq 0) {
    Write-Host "  ✓ ALL CHECKS PASSED" -ForegroundColor Green
} elseif ($script:ErrorCount -eq 0) {
    Write-Host "  ⚠ COMPLETED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "    Warnings: $($script:WarningCount)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ FAILED" -ForegroundColor Red
    Write-Host "    Errors: $($script:ErrorCount)" -ForegroundColor Red
    Write-Host "    Warnings: $($script:WarningCount)" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $CheckOnly -and $script:ErrorCount -eq 0) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review changes: git diff" -ForegroundColor Gray
    Write-Host "  2. Commit changes: git add . && git commit" -ForegroundColor Gray
    Write-Host ""
}

# Exit code
if ($script:ErrorCount -gt 0) {
    exit 1
} else {
    exit 0
}
