<#
.SYNOPSIS
    Writes zero-touch DPS provisioning files to a Raspberry Pi SD card boot partition.

.DESCRIPTION
    After flashing Raspberry Pi OS with Raspberry Pi Imager, this script writes two files
    to the FAT32 boot partition (accessible from Windows):

      iot-credentials.env  — DPS fleet credentials (read by firstrun.sh on first boot)
      firstrun.sh          — First boot automation script that installs the IoT service

    On first boot the Pi:
      1. Reads DPS_ID_SCOPE + DPS_GROUP_KEY from iot-credentials.env
      2. Derives its own per-device symmetric key (HMAC-SHA256)
      3. Registers with Azure DPS → receives assigned IoT Hub + connection string
      4. Writes connection string to /opt/iot-monitor/.env
      5. Securely deletes the credentials from the boot partition
      6. Reboots fully configured

    The SD card contains only FLEET credentials (same for all devices), not per-device secrets.
    A compromised SD card does not expose any specific device's IoT Hub key.

.PARAMETER DriveLetter
    Drive letter of the SD card boot partition (FAT32), e.g. "E" or "E:".
    The boot partition is the small FAT32 partition visible in Windows Explorer.

.PARAMETER IdScope
    DPS ID Scope for your Device Provisioning Service instance.
    Format: 0ne########  (11-character alphanumeric starting with 0ne)
    Retrieve from: Azure Portal → DPS → Overview  OR
    CLI: az iot dps show --name dps-aw-iot-copilot --query properties.idScope -o tsv

.PARAMETER GroupKey
    DPS group enrollment primary key (base64-encoded symmetric key).
    Retrieve from: Azure Portal → DPS → Manage enrollments → iotpanel-fleet → Primary Key  OR
    CLI: az iot dps enrollment-group show --dps-name dps-aw-iot-copilot --enrollment-id iotpanel-fleet --show-keys --query attestation.symmetricKey.primaryKey -o tsv

.PARAMETER DeviceId
    IoT Hub device ID. Defaults to "raspberry-pi-iotpanel".
    For fleet deployments, use a unique ID per device (e.g. based on MAC address).

.PARAMETER Force
    Overwrite existing files on the boot partition without prompting.

.EXAMPLE
    .\New-PiBootConfig.ps1 -DriveLetter E -IdScope "YOUR_DPS_ID_SCOPE" -GroupKey "abc123=="

.EXAMPLE
    # Fetch DPS values from Azure CLI and pipe directly
    $scope = az iot dps show --name dps-aw-iot-copilot --query properties.idScope -o tsv
    $key   = az iot dps enrollment-group show --dps-name dps-aw-iot-copilot --enrollment-id iotpanel-fleet --show-keys --query attestation.symmetricKey.primaryKey -o tsv
    .\New-PiBootConfig.ps1 -DriveLetter E -IdScope $scope -GroupKey $key

.NOTES
    SECURITY:
    - The SD card contains fleet credentials (DPS_ID_SCOPE + DPS_GROUP_KEY), not per-device secrets
    - Per-device keys are derived at first boot and never written to the SD card
    - On first boot, firstrun.sh reads iot-credentials.env, runs bootstrap, then shreds the file
    - Keep the SD card physically secure until provisioning is complete

    PREREQUISITES:
    - Raspberry Pi OS Lite (64-bit) flashed with Raspberry Pi Imager
    - Imager advanced options set: SSH enabled, user created, WiFi configured
    - SD card inserted and boot partition visible in Windows Explorer
    - DPS + IoT Hub provisioned (run New-AzureIotInfrastructure.ps1 first)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z]:?$')]
    [string] $DriveLetter,

    [Parameter(Mandatory)]
    [ValidatePattern('^0ne[A-Za-z0-9]{8}$')]
    [string] $IdScope,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $GroupKey,

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
Write-Host "AgenticIoT — Writing Pi Zero-Touch Config (DPS)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Boot partition : ${drive}:\" -ForegroundColor Gray
Write-Host "  Device ID      : $DeviceId" -ForegroundColor Gray
Write-Host "  DPS ID Scope   : $IdScope" -ForegroundColor Gray
Write-Host ""

# ─── Write iot-credentials.env ───────────────────────────────────────────────
Write-Host "Writing iot-credentials.env..." -ForegroundColor Yellow

$credsContent = @"
# AgenticIoT DPS fleet credentials
# Written by New-PiBootConfig.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# This file is read once by firstrun.sh on first boot, then securely deleted.
# Contains FLEET credentials — the same file works for any Pi in the fleet.
# DO NOT commit this file or copy it elsewhere.
DPS_ID_SCOPE=$IdScope
DPS_GROUP_KEY=$GroupKey
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
[ -z "$DPS_ID_SCOPE" ] && exit 0
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
Write-Host "✅ Boot partition configured for zero-touch DPS provisioning." -ForegroundColor Green
Write-Host ""
Write-Host "What happens on first boot:" -ForegroundColor Cyan
Write-Host "  1. Pi reads DPS fleet credentials from iot-credentials.env"
Write-Host "  2. Derives its own per-device key (HMAC-SHA256)"
Write-Host "  3. Registers with Azure DPS → receives IoT Hub connection string"
Write-Host "  4. Installs iot-monitor service"
Write-Host "  5. Shreds credentials from SD card, reboots"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Safely eject the SD card from Windows"
Write-Host "  2. Insert into the Raspberry Pi"
Write-Host "  3. Power on"
Write-Host "  4. Wait ~5 minutes for first boot"
Write-Host "  5. The Pi will reboot once automatically when done"
Write-Host ""
Write-Host "Monitor progress (after Pi has an IP):" -ForegroundColor Cyan
Write-Host "  ssh pi@iotpanel.local"
Write-Host "  cat /var/log/iot-firstrun.log"
Write-Host "  sudo journalctl -u iot-monitor -f"
Write-Host ""
Write-Host "Verify in Azure:" -ForegroundColor Cyan
Write-Host "  az iot hub device-identity list --hub-name iothub-aw-iot-copilot --output table"
Write-Host "  az iot hub monitor-events --hub-name iothub-aw-iot-copilot --device-id $DeviceId"
Write-Host ""
Write-Host "REMINDER: Push Device Twin config if not already done:" -ForegroundColor Yellow
Write-Host "  See raspberry-pi/SETUP.md — Device Twin configuration section"
Write-Host ""
