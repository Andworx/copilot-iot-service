<#
.SYNOPSIS
    Generates a strong-name key file for the plugin project.
.DESCRIPTION
    Creates DataversePluginTemplate.snk using sn.exe if the key file does not exist.
    Run this script before first Release build after copying the template.
.PARAMETER KeyFile
    Output key file path. Defaults to DataversePluginTemplate.snk in this folder.
.EXAMPLE
    .\Generate-StrongNameKey.ps1
#>

[CmdletBinding()]
param(
    [string]$KeyFile = "DataversePluginTemplate.snk"
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$keyPath = Join-Path $projectRoot $KeyFile

if (Test-Path $keyPath) {
    Write-Host "[Plugin] Strong-name key already exists: $keyPath" -ForegroundColor Green
    exit 0
}

$snPath = $null
$snCommand = Get-Command sn.exe -ErrorAction SilentlyContinue
if ($snCommand) {
    $snPath = $snCommand.Source
}

if (-not $snPath) {
    $programFilesX86 = ${env:ProgramFiles(x86)}
    $programFiles = $env:ProgramFiles

    $candidatePaths = @(
        (Join-Path $programFilesX86 "Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\sn.exe"),
        (Join-Path $programFilesX86 "Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.2 Tools\sn.exe"),
        (Join-Path $programFilesX86 "Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\sn.exe"),
        (Join-Path $programFiles "Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\sn.exe"),
        (Join-Path $programFiles "Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.2 Tools\sn.exe")
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            $snPath = $candidate
            break
        }
    }
}

if (-not $snPath) {
    throw "sn.exe was not found in PATH or common SDK locations. Install Visual Studio Build Tools (or Visual Studio) with .NET Framework tooling, then rerun this script."
}

Write-Host "[Plugin] Using sn.exe at: $snPath" -ForegroundColor DarkGray
Write-Host "[Plugin] Generating strong-name key: $keyPath" -ForegroundColor Yellow
& $snPath -k $keyPath | Out-Null

if (-not (Test-Path $keyPath)) {
    throw "Failed to generate strong-name key at $keyPath"
}

Write-Host "[Plugin] Strong-name key generated successfully." -ForegroundColor Green
