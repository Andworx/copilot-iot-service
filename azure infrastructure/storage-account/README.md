# Storage Account — AgenticIoT

## Purpose

Azure Storage Account (`stfuncawiotcopilot`) is a mandatory backing store for the Azure Function App. Azure Functions on the Consumption plan require a Storage Account to store function code, host configuration, execution logs, and distributed lock state. This storage account is an infrastructure dependency — it is not used directly by the application code.

## Resource Type & SKU

| Property | Value |
|----------|-------|
| Resource type | `Microsoft.Storage/storageAccounts` |
| Name | `stfuncawiotcopilot` |
| SKU | Standard_LRS |
| Kind | StorageV2 |
| Blob public access | Disabled |
| Resource group | `rg-aw-azcom-iot-copilot` |

> **Naming constraint:** Azure Storage Account names must be globally unique, lowercase, 3–24 characters, no hyphens. The name `stfuncawiotcopilot` follows the convention `st` + abbreviated project scope.

## Configuration

Key settings are stored in [`config.json`](./config.json). Do not hardcode these values in scripts.

```json
{
  "name": "stfuncawiotcopilot",
  "sku": "Standard_LRS",
  "kind": "StorageV2",
  "allowBlobPublicAccess": false
}
```

## Connections

| Component | Direction | How |
|-----------|-----------|-----|
| Azure Function App (`func-aw-iot-copilot`) | → Storage | `AzureWebJobsStorage` connection string injected by `New-AzureMiddleware.ps1` |

## Deployment

Provisioned by:

```powershell
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

The script:
1. Creates the Storage Account with Standard_LRS SKU
2. Retrieves the connection string
3. Injects it into the Function App as the `AzureWebJobsStorage` app setting

Config is read from `azure infrastructure/storage-account/config.json`.

> **Secret:** The storage connection string contains an access key and must not be committed to source control. The script reads it at deploy time and writes it directly to Function App settings.

## Updating

- **SKU change**: Update `sku` in `config.json` and re-run `New-AzureMiddleware.ps1`.
- **Key rotation**: Use `az storage account keys renew` then re-run the script to push the new connection string to Function App settings.

## Updating This README

Update when:
- Storage account name or SKU changes
- Access policy changes (e.g., enabling/restricting public blob access)
- The Function App deployment process changes
