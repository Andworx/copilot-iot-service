<#
.SYNOPSIS
    Deploy Raspberry Pi monitor updates over SCP and restart the service.
.DESCRIPTION
    Copies either raspberry-pi/main.py or the full raspberry-pi directory to the
    remote Pi host, optionally backing up the remote main.py first. Then restarts
    iot-monitor and shows recent logs for quick verification.
.PARAMETER SshHost
    SSH target in user@host form. Defaults to pi@iotpanel.
.PARAMETER RemoteDir
    Remote Raspberry Pi app directory. Defaults to /opt/iot-monitor/raspberry-pi.
.PARAMETER CopyAll
    If set, copies all files under local raspberry-pi/ to the remote directory.
    If not set, copies only raspberry-pi/main.py.
.PARAMETER SkipBackup
    If set, skips creating a timestamped backup of remote main.py.
.EXAMPLE
    .\scripts\deploy-pi-update.ps1
    Copies main.py, restarts iot-monitor, and prints recent logs.
.EXAMPLE
    .\scripts\deploy-pi-update.ps1 -CopyAll
    Copies the full raspberry-pi folder, restarts service, and prints logs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SshHost = 'pi@iotpanel',

    [Parameter(Mandatory = $false)]
    [string]$RemoteDir = '/opt/iot-monitor/raspberry-pi',

    [Parameter(Mandatory = $false)]
    [switch]$CopyAll,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
    param([string]$Message)
    Write-Host "[Deploy] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[Deploy] $Message" -ForegroundColor Green
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

function Invoke-RemoteSudo {
    param(
        [Parameter(Mandatory = $true)][string]$SshTarget,
        [Parameter(Mandatory = $true)][string]$Command
    )

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    $remoteCommand = "echo $encoded | base64 -d | sudo bash"
    Invoke-External -Command 'ssh' -Arguments @($SshTarget, $remoteCommand)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$mainPyLocal = Join-Path $repoRoot 'raspberry-pi/main.py'
$piFolderLocal = Join-Path $repoRoot 'raspberry-pi/*'

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    throw 'ssh is not available in PATH.'
}
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    throw 'scp is not available in PATH.'
}

if (-not (Test-Path $mainPyLocal)) {
    throw "Local file not found: $mainPyLocal"
}

Write-Info "Target host: $SshHost"
Write-Info "Remote path: $RemoteDir"

if (-not $SkipBackup) {
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $backupPath = "$RemoteDir/main.py.bak.$timestamp"
    $backupCmd = "if [ -f '$RemoteDir/main.py' ]; then cp '$RemoteDir/main.py' '$backupPath'; fi"
    Write-Info "Creating remote backup: $backupPath"
    Invoke-RemoteSudo -SshTarget $SshHost -Command $backupCmd
}

if ($CopyAll) {
    $stageDir = '/tmp/pi-update'
    Write-Info 'Staging full raspberry-pi directory in /tmp on remote host...'
    Invoke-External -Command 'ssh' -Arguments @($SshHost, "rm -rf $stageDir && mkdir -p $stageDir")
    Invoke-External -Command 'scp' -Arguments @('-r', $piFolderLocal, "$SshHost`:$stageDir/")
    Write-Info 'Applying staged files to target directory with sudo...'
    Invoke-RemoteSudo -SshTarget $SshHost -Command "cp -r '$stageDir'/* '$RemoteDir/'"
}
else {
    $stageMain = '/tmp/main.py.update'
    Write-Info 'Staging raspberry-pi/main.py in /tmp on remote host...'
    Invoke-External -Command 'scp' -Arguments @($mainPyLocal, "$SshHost`:$stageMain")
    Write-Info 'Applying staged file to target directory with sudo...'
    Invoke-RemoteSudo -SshTarget $SshHost -Command "cp '$stageMain' '$RemoteDir/main.py'"
}

Write-Info 'Restarting iot-monitor service...'
Invoke-External -Command 'ssh' -Arguments @($SshHost, 'sudo systemctl restart iot-monitor && sudo systemctl is-active iot-monitor')

Write-Info 'Showing latest iot-monitor logs...'
Invoke-External -Command 'ssh' -Arguments @($SshHost, 'sudo journalctl -u iot-monitor -n 40 --no-pager')

Write-Success 'Deploy completed successfully.'
