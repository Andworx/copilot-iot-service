# Device Provisioning Service — AgenticIoT

## Purpose

Azure Device Provisioning Service (DPS) automates the zero-touch provisioning of IoT devices into the correct IoT Hub. In this solution it manages a symmetric-key group enrollment (`iotpanel-fleet`) so that any Raspberry Pi IoT Panel with the correct derived key is automatically provisioned to `iothub-aw-iot-copilot` without manual device registration.

## Resource Type & SKU

| Property | Value |
|----------|-------|
| Resource type | `Microsoft.Devices/ProvisioningServices` |
| Name | `dps-aw-iot-copilot` |
| SKU | S1 Standard |
| Resource group | `rg-aw-azcom-iot-copilot` |

## Configuration

Key settings are stored in [`config.json`](./config.json). Do not hardcode these values in scripts.

```json
{
  "name": "dps-aw-iot-copilot",
  "enrollmentGroupId": "iotpanel-fleet",
  "attestationType": "symmetricKey"
}
```

## Connections

| Component | Direction | How |
|-----------|-----------|-----|
| IoT Hub (`iothub-aw-iot-copilot`) | ↔ DPS | Linked hub — DPS assigns new devices here |
| Raspberry Pi | → DPS | Device uses HMAC-SHA256 derived key from the group enrollment to self-provision |

## Deployment

Provisioned by:

```powershell
.\scripts\New-AzureIotInfrastructure.ps1 -Environment dev
```

The script:
1. Creates the DPS resource
2. Links it to the IoT Hub
3. Creates the `iotpanel-fleet` group enrollment with symmetric key attestation

Config is read from `azure infrastructure/device-provisioning-service/config.json`.

> **Security note:** The DPS group enrollment primary key is printed once at the end of the script. Store it in Azure Key Vault immediately. Never commit it to source control. Individual device keys are HMAC-SHA256 derivatives — compromising one device key does not expose the group key.

### Key outputs needed for Pi configuration

After running the script, copy these values for use with `New-PiBootConfig.ps1`:

- **DPS ID Scope** — shown in the script summary
- **DPS Group Key** — shown once; store in Key Vault

## Updating

Re-run `New-AzureIotInfrastructure.ps1 -SkipDpsEnrollment` to reprovision the DPS without regenerating the enrollment key.

To add a new enrollment group, modify the script or use the Azure Portal / CLI directly.

## Updating This README

Update when:
- The DPS name or enrollment group ID changes
- Attestation type changes
- The provisioning flow changes
