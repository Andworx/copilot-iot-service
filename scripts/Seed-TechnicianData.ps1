<#
.SYNOPSIS
    Seeds andy_technician and andy_iot_sensor tables with realistic simulated data for US East.
.DESCRIPTION
    Creates 25 field technician records and 12 IoT sensor records spread across the US East
    corridor (NYC to Charlotte). Run after Import-Choices, Import-Tables, and Import-Relationships.
    Idempotent — skips records that already exist (matched by andy_name for techs,
    andy_device_id for sensors).
.PARAMETER Environment
    Target environment: dev, test, prod.
.PARAMETER DryRun
    Preview mode — logs what would be created without making API calls.
.EXAMPLE
    .\Seed-TechnicianData.ps1 -Environment dev
.EXAMPLE
    .\Seed-TechnicianData.ps1 -Environment dev -DryRun
#>
param(
    [Parameter(Mandatory)][ValidateSet('dev', 'test', 'prod')] [string]$Environment,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $scriptDir 'Connect-Dataverse.ps1')
. (Join-Path $scriptDir 'Invoke-DataverseApi.ps1')

$configPath = Join-Path $scriptDir "config-$Environment.json"
$conn = Connect-Dataverse -ConfigPath $configPath

Write-Host "`n=== Seed Technician Data ($Environment) ===" -ForegroundColor Cyan
if ($DryRun) { Write-Host "[DRY-RUN] No records will be created." -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Choice value constants
# ---------------------------------------------------------------------------
$AV_AVAILABLE  = 756150000
$AV_ON_JOB     = 756150001
$AV_OFF_SHIFT  = 756150002

$SK_JUNIOR  = 756150000
$SK_MID     = 756150001
$SK_SENIOR  = 756150002

# ---------------------------------------------------------------------------
# Technician seed data — 25 records across US East
# ---------------------------------------------------------------------------
$technicians = @(
    @{ name='James Carter';    availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=40.7128;  lon=-74.0060;  location='Manhattan, NYC – Lower East Side' },
    @{ name='Maria Santos';    availability=$AV_AVAILABLE; skill=$SK_MID;    lat=40.6501;  lon=-73.9496;  location='Brooklyn, NYC – Flatbush' },
    @{ name='David Kim';       availability=$AV_ON_JOB;    skill=$SK_SENIOR; lat=40.7282;  lon=-73.7949;  location='Queens, NYC – Jamaica' },
    @{ name='Sarah Mitchell';  availability=$AV_AVAILABLE; skill=$SK_MID;    lat=40.7357;  lon=-74.1724;  location='Newark, NJ – Downtown' },
    @{ name='Robert Chen';     availability=$AV_AVAILABLE; skill=$SK_JUNIOR; lat=40.7178;  lon=-74.0431;  location='Jersey City, NJ – Exchange Place' },
    @{ name='Lisa Thompson';   availability=$AV_OFF_SHIFT; skill=$SK_MID;    lat=40.9312;  lon=-73.7879;  location='White Plains, NY – Downtown' },
    @{ name='Michael Rivera';  availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=41.0534;  lon=-73.5387;  location='Stamford, CT – South End' },
    @{ name='Jennifer Walsh';  availability=$AV_AVAILABLE; skill=$SK_MID;    lat=41.7658;  lon=-72.6851;  location='Hartford, CT – Frog Hollow' },
    @{ name='Kevin O''Brien';  availability=$AV_AVAILABLE; skill=$SK_JUNIOR; lat=41.3083;  lon=-72.9279;  location='New Haven, CT – East Rock' },
    @{ name='Amanda Price';    availability=$AV_OFF_SHIFT; skill=$SK_SENIOR; lat=41.8240;  lon=-71.4128;  location='Providence, RI – Federal Hill' },
    @{ name='Thomas Grant';    availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=42.3601;  lon=-71.0589;  location='Boston, MA – Back Bay' },
    @{ name='Rachel Adams';    availability=$AV_AVAILABLE; skill=$SK_MID;    lat=42.2626;  lon=-71.8023;  location='Worcester, MA – Main South' },
    @{ name='Steven Brooks';   availability=$AV_ON_JOB;    skill=$SK_MID;    lat=42.1015;  lon=-72.5898;  location='Springfield, MA – Indian Orchard' },
    @{ name='Nicole Evans';    availability=$AV_AVAILABLE; skill=$SK_JUNIOR; lat=40.2206;  lon=-74.0121;  location='Long Branch, NJ – West End' },
    @{ name='Brian Foster';    availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=40.3573;  lon=-74.6672;  location='Trenton, NJ – Mill Hill' },
    @{ name='Melissa Hart';    availability=$AV_AVAILABLE; skill=$SK_MID;    lat=39.7447;  lon=-75.5484;  location='Wilmington, DE – Trolley Square' },
    @{ name='Anthony Young';   availability=$AV_OFF_SHIFT; skill=$SK_MID;    lat=39.2904;  lon=-76.6122;  location='Baltimore, MD – Fells Point' },
    @{ name='Patricia Moore';  availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=38.9072;  lon=-77.0369;  location='Washington, DC – Capitol Hill' },
    @{ name='Christopher Lee'; availability=$AV_AVAILABLE; skill=$SK_MID;    lat=38.8816;  lon=-77.0910;  location='Arlington, VA – Clarendon' },
    @{ name='Stephanie King';  availability=$AV_AVAILABLE; skill=$SK_JUNIOR; lat=38.8048;  lon=-77.0469;  location='Alexandria, VA – Old Town' },
    @{ name='Daniel Scott';    availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=37.5407;  lon=-77.4360;  location='Richmond, VA – Church Hill' },
    @{ name='Jessica Turner';  availability=$AV_OFF_SHIFT; skill=$SK_MID;    lat=36.8508;  lon=-76.2859;  location='Norfolk, VA – Ghent' },
    @{ name='Matthew Harris';  availability=$AV_AVAILABLE; skill=$SK_MID;    lat=35.2271;  lon=-80.8431;  location='Charlotte, NC – South End' },
    @{ name='Ashley Johnson';  availability=$AV_AVAILABLE; skill=$SK_JUNIOR; lat=35.7796;  lon=-78.6382;  location='Raleigh, NC – Glenwood South' },
    @{ name='Ryan Martinez';   availability=$AV_AVAILABLE; skill=$SK_SENIOR; lat=34.0007;  lon=-81.0348;  location='Columbia, SC – Vista District' }
)

# ---------------------------------------------------------------------------
# IoT Sensor seed data — 12 records across US East
# ---------------------------------------------------------------------------
$DT_POWER   = 756150000  # Power Panel
$ST_ONLINE  = 756150000  # Online

$sensors = @(
    @{ deviceId='raspberry-pi-iotpanel';         site='Manhattan DC Panel Room';       type=$DT_POWER; lat=40.7128;  lon=-74.0060 },
    @{ deviceId='panel-brooklyn-fleet';          site='Brooklyn Fleet Maintenance Hub'; type=$DT_POWER; lat=40.6501;  lon=-73.9496 },
    @{ deviceId='panel-newark-transit';          site='Newark Transit Control Room';   type=$DT_POWER; lat=40.7357;  lon=-74.1724 },
    @{ deviceId='panel-stamford-datacenter';     site='Stamford Data Center – Pod 3';  type=$DT_POWER; lat=41.0534;  lon=-73.5387 },
    @{ deviceId='panel-hartford-utilities';      site='Hartford Utilities Substation'; type=$DT_POWER; lat=41.7658;  lon=-72.6851 },
    @{ deviceId='panel-boston-financial';        site='Boston Financial District Hub'; type=$DT_POWER; lat=42.3601;  lon=-71.0589 },
    @{ deviceId='panel-trenton-municipal';       site='Trenton Municipal Works';       type=$DT_POWER; lat=40.3573;  lon=-74.6672 },
    @{ deviceId='panel-wilmington-logistics';    site='Wilmington Logistics Center';   type=$DT_POWER; lat=39.7447;  lon=-75.5484 },
    @{ deviceId='panel-baltimore-harbor';        site='Baltimore Inner Harbor Ops';    type=$DT_POWER; lat=39.2904;  lon=-76.6122 },
    @{ deviceId='panel-dc-federal';              site='Washington DC Federal Bldg B';  type=$DT_POWER; lat=38.9072;  lon=-77.0369 },
    @{ deviceId='panel-richmond-campus';         site='Richmond Tech Campus – Ring 2'; type=$DT_POWER; lat=37.5407;  lon=-77.4360 },
    @{ deviceId='panel-charlotte-southend';      site='Charlotte South End Plant';     type=$DT_POWER; lat=35.2271;  lon=-80.8431 }
)

# ---------------------------------------------------------------------------
# Helper: check record exists by filter
# ---------------------------------------------------------------------------
function Test-RecordExists {
    param([hashtable]$Connection, [string]$EntitySet, [string]$Filter)
    $result = Invoke-DataverseApi -Connection $Connection `
        -Endpoint "${EntitySet}?`$filter=${Filter}&`$select=createdon&`$top=1" `
        -Method GET
    return ($result.value.Count -gt 0)
}

# ---------------------------------------------------------------------------
# Seed technicians
# ---------------------------------------------------------------------------
Write-Host "`n--- Technicians (${($technicians.Count)}) ---" -ForegroundColor White
$techCreated = 0; $techSkipped = 0

foreach ($t in $technicians) {
    $filterName = [System.Uri]::EscapeDataString($t.name)
    $exists = $false
    if (-not $DryRun) {
        $exists = Test-RecordExists -Connection $conn `
            -EntitySet 'andy_technicians' `
            -Filter "andy_name eq '$($t.name)'"
    }

    if ($exists) {
        Write-Host "  [SKIP] $($t.name) — already exists" -ForegroundColor DarkGray
        $techSkipped++
        continue
    }

    $body = @{
        andy_name         = $t.name
        andy_availability = $t.availability
        andy_skill_level  = $t.skill
        andy_latitude     = $t.lat
        andy_longitude    = $t.lon
        andy_location_label = $t.location
    }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would create: $($t.name) ($($t.location))" -ForegroundColor Yellow
    }
    else {
        try {
            Invoke-DataverseApi -Connection $conn -Endpoint 'andy_technicians' -Method POST -Body $body | Out-Null
            Write-Host "  [NEW] $($t.name)" -ForegroundColor Green
            $techCreated++
        }
        catch {
            Write-Warning "  [FAIL] $($t.name): $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Seed sensors
# ---------------------------------------------------------------------------
Write-Host "`n--- IoT Sensors (${($sensors.Count)}) ---" -ForegroundColor White
$sensorCreated = 0; $sensorSkipped = 0

foreach ($s in $sensors) {
    $exists = $false
    if (-not $DryRun) {
        $exists = Test-RecordExists -Connection $conn `
            -EntitySet 'andy_iot_sensors' `
            -Filter "andy_device_id eq '$($s.deviceId)'"
    }

    if ($exists) {
        Write-Host "  [SKIP] $($s.deviceId) — already exists" -ForegroundColor DarkGray
        $sensorSkipped++
        continue
    }

    $body = @{
        andy_device_id  = $s.deviceId
        andy_site_name  = $s.site
        andy_device_type = $s.type
        andy_status     = $ST_ONLINE
        andy_latitude   = $s.lat
        andy_longitude  = $s.lon
    }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would create: $($s.deviceId) @ $($s.site)" -ForegroundColor Yellow
    }
    else {
        try {
            Invoke-DataverseApi -Connection $conn -Endpoint 'andy_iot_sensors' -Method POST -Body $body | Out-Null
            Write-Host "  [NEW] $($s.deviceId)" -ForegroundColor Green
            $sensorCreated++
        }
        catch {
            Write-Warning "  [FAIL] $($s.deviceId): $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Seed Complete ===" -ForegroundColor Cyan
Write-Host "Technicians: $techCreated created, $techSkipped skipped" -ForegroundColor White
Write-Host "Sensors:     $sensorCreated created, $sensorSkipped skipped" -ForegroundColor White
