<#
.SYNOPSIS
    Writes zero-touch provisioning files to a Raspberry Pi SD card boot partition.

.DESCRIPTION
    After flashing Raspberry Pi OS with Raspberry Pi Imager, this script writes two files
    to the FAT32 boot partition (accessible from Windows):

      iot-credentials.env  — IoT Hub connection string (read by firstrun.sh on first boot)
      firstrun.sh          — First boot automation script that installs the IoT service

    On first boot the Pi:
      1. Detects iot-credentials.env on the boot partition
      2. Downloads and runs the unattended bootstrap from GitHub
      3. Connects to IoT Hub and fetches Device Twin config
      4. Securely deletes the credentials from the boot partition
      5. Reboots fully configured

.PARAMETER DriveLetter
    Drive letter of the SD card boot partition (FAT32), e.g. "E" or "E:".
    The boot partition is the small FAT32 partition visible in Windows Explorer.
    Typically the first partition on the SD card.

.PARAMETER ConnectionString
    Azure IoT Hub device connection string.
    Format: HostName=<hub>.azure-devices.net;DeviceId=raspberry-pi-iotpanel;SharedAccessKey=<key>
    Retrieve from Azure Portal: IoT Hub → Devices → raspberry-pi-iotpanel → Primary Connection String
    Or via CLI: az iot hub device-identity connection-string show --hub-name <hub> --device-id raspberry-pi-iotpanel

.PARAMETER DeviceId
    IoT Hub device ID. Defaults to "raspberry-pi-iotpanel".

.PARAMETER Force
    Overwrite existing files on the boot partition without prompting.

.EXAMPLE
    .\New-PiBootConfig.ps1 -DriveLetter E -ConnectionString "HostName=myhub.azure-devices.net;DeviceId=raspberry-pi-iotpanel;SharedAccessKey=abc123=="

.EXAMPLE
    # Get the connection string from Azure CLI and pipe directly
    $conn = az iot hub device-identity connection-string show --hub-name myhub --device-id raspberry-pi-iotpanel --query connectionString -o tsv
    .\New-PiBootConfig.ps1 -DriveLetter E -ConnectionString $conn

.NOTES
    SECURITY:
    - The connection string is written to the SD card (iot-credentials.env)
    - On first boot, firstrun.sh reads the file, runs the bootstrap, then shreds the file
    - The connection string is NOT stored anywhere in the repo or in any committed file
    - Keep the SD card physically secure until provisioning is complete

    PREREQUISITES:
    - Raspberry Pi OS Lite (64-bit) flashed with Raspberry Pi Imager
    - Imager advanced options set: SSH enabled, user created, WiFi configured
    - SD card inserted and boot partition visible in Windows Explorer
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z]:?$')]
    [string] $DriveLetter,

    [Parameter(Mandatory)]
    [ValidateScript({
        if ($_ -match '^HostName=.+;DeviceId=.+;SharedAccessKey=.+$') { $true }
        else { throw "ConnectionString must be in the format: HostName=...;DeviceId=...;SharedAccessKey=..." }
    })]
    [string] $ConnectionString,

    [string] $DeviceId = "raspberry-pi-iotpanel",

    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Resolve drive root ───────────────────────────────────────────────────────
$drive = $DriveLetter.TrimEnd(':').ToUpper()
$bootRoot = "${drive}:\"

if (-not (Test-Path $bootRoot)) {
    Write-Error "Drive ${drive}: not found. Ensure the SD card is inserted and the boot partition is mounted."
}

# Validate this looks like a Pi boot partition
$piMarkers = @("cmdline.txt", "config.txt", "bootcode.bin", "start.elf", "kernel8.img")
$isBootPartition = $piMarkers | Where-Object { Test-Path (Join-Path $bootRoot $_) }
if (-not $isBootPartition -and -not $Force) {
    Write-Warning "Drive ${drive}: does not look like a Raspberry Pi boot partition (no cmdline.txt, config.txt, etc.)."
    $confirm = Read-Host "Continue anyway? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# ─── Paths ────────────────────────────────────────────────────────────────────
$credsFile    = Join-Path $bootRoot "iot-credentials.env"
$firstrunFile = Join-Path $bootRoot "firstrun.sh"
$sshFile      = Join-Path $bootRoot "ssh"

# ─── Check for existing files ─────────────────────────────────────────────────
foreach ($file in @($credsFile, $firstrunFile)) {
    if ((Test-Path $file) -and -not $Force) {
        Write-Warning "$(Split-Path $file -Leaf) already exists on ${drive}:."
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
            Write-Host "Aborted. Use -Force to skip this prompt." -ForegroundColor Yellow
            exit 0
        }
    }
}

Write-Host ""
Write-Host "AgenticIoT — Writing Pi Zero-Touch Config" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Boot partition : ${drive}:\" -ForegroundColor Gray
Write-Host "  Device ID      : $DeviceId" -ForegroundColor Gray
Write-Host ""

# ─── Write iot-credentials.env ───────────────────────────────────────────────
Write-Host "Writing iot-credentials.env..." -ForegroundColor Yellow

$credsContent = @"
# AgenticIoT IoT Hub credentials
# Written by New-PiBootConfig.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# This file is read once by firstrun.sh on first boot, then securely deleted.
# DO NOT commit this file or copy it elsewhere.
IOT_HUB_CONNECTION_STRING=$ConnectionString
DEVICE_ID=$DeviceId
"@

[System.IO.File]::WriteAllText($credsFile, $credsContent.Replace("`r`n", "`n"))
Write-Host "  ✅ $credsFile" -ForegroundColor Green

# ─── Fetch and write firstrun.sh ─────────────────────────────────────────────
Write-Host "Fetching firstrun.sh from GitHub..." -ForegroundColor Yellow

$firstrunUrl = "https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/raspberry-pi/firstrun.sh"

try {
    $firstrunContent = (Invoke-WebRequest -Uri $firstrunUrl -UseBasicParsing).Content
    # Ensure Unix line endings
    $firstrunContent = $firstrunContent.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($firstrunFile, $firstrunContent)
    Write-Host "  ✅ $firstrunFile (downloaded from GitHub)" -ForegroundColor Green
} catch {
    # Fall back to generating a minimal firstrun.sh inline
    Write-Warning "Could not download firstrun.sh from GitHub: $_"
    Write-Warning "Writing a minimal firstrun.sh that will download the full script on boot..."

    $fallbackFirstrun = @'
#!/bin/bash
set +e
exec > /var/log/iot-firstrun.log 2>&1
echo "[$(date)] Waiting for network..."
for i in $(seq 1 30); do
    curl -s --max-time 5 https://github.com > /dev/null 2>&1 && break
    sleep 5
done
BOOT_CREDS=""
for c in /boot/firmware/iot-credentials.env /boot/iot-credentials.env; do
    [ -f "$c" ] && BOOT_CREDS="$c" && break
done
[ -z "$BOOT_CREDS" ] && exit 0
set -a; source "$BOOT_CREDS"; set +a
[ -z "$IOT_HUB_CONNECTION_STRING" ] && exit 0
curl -sSL https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/raspberry-pi/firstrun.sh | bash
'@
    $fallbackFirstrun = $fallbackFirstrun.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($firstrunFile, $fallbackFirstrun)
    Write-Host "  ✅ $firstrunFile (minimal fallback)" -ForegroundColor Yellow
}

# ─── Ensure SSH is enabled ────────────────────────────────────────────────────
if (-not (Test-Path $sshFile)) {
    Write-Host "Creating ssh (enable SSH) file..." -ForegroundColor Yellow
    [System.IO.File]::WriteAllText($sshFile, "")
    Write-Host "  ✅ $sshFile (SSH enabled)" -ForegroundColor Green
} else {
    Write-Host "  ℹ SSH file already present" -ForegroundColor Gray
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "✅ Boot partition configured for zero-touch provisioning." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Safely eject the SD card from Windows"
Write-Host "  2. Insert into the Raspberry Pi"
Write-Host "  3. Power on"
Write-Host "  4. Wait ~5 minutes for first boot (bootstrap downloads and installs)"
Write-Host "  5. The Pi will reboot once automatically when done"
Write-Host ""
Write-Host "Monitor progress (after Pi has an IP):" -ForegroundColor Cyan
Write-Host "  ssh pi@iotpanel.local"
Write-Host "  cat /var/log/iot-firstrun.log"
Write-Host "  sudo journalctl -u iot-monitor -f"
Write-Host ""
Write-Host "Verify in Azure:" -ForegroundColor Cyan
Write-Host "  az iot hub monitor-events --hub-name <hub> --device-id $DeviceId"
Write-Host ""
Write-Host "REMINDER: Push Device Twin config if not already done:" -ForegroundColor Yellow
Write-Host "  See raspberry-pi/SETUP.md Step 5 for the twin JSON"
Write-Host ""
