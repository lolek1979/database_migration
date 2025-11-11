# App Settings Key Vault Transfer

This repo contains helper scripts for copying JSON-based application settings between Azure Key Vaults and a local workspace, then importing them into another vault.

## Prerequisites

- Azure CLI (`az`) for the Bash scripts.
- PowerShell 7+ or Windows PowerShell with the `Az` module for the PowerShell script.
- Access to the relevant subscriptions and Key Vaults (list/get/set secret permissions).

## Export Secrets From Source Vault

Use `appSettingsAkv.sh` to dump every secret from a source Key Vault into individual JSON files.

```bash
export SOURCE_KV="kv-nis-source"
export SUBSCRIPTION="NIS.dev1"
export OUTPUT_DIR="./kv-secrets"

bash appSettingsAkv.sh
```

Each secret becomes `<secret-name>.json` in `OUTPUT_DIR`. Keep this folder secure because it stores plain-text secrets.

## Import Secrets With Azure CLI

If you want to push the exported JSON files into another Key Vault via CLI, run `appSettingsAkvImport.sh`.

```bash
export TARGET_KV="kv-nis-target"
export SUBSCRIPTION="NIS.dev1"
export INPUT_DIR="./kv-secrets"

bash appSettingsAkvImport.sh
```

The script iterates over `*.json` files in `INPUT_DIR` and recreates each secret in the target vault using the file name as the secret name.

## Import Secrets With PowerShell

`importAppSettings.ps1` can import either an entire folder or a single JSON file (useful when you are already in the directory with `pwd`/`Get-Location`).

```powershell
# Import every JSON file in the default folder (~/Desktop/appSettings/dev1)
pwsh ./importAppSettings.ps1 -KeyVaultName kv-nis-target

# Import a different folder
pwsh ./importAppSettings.ps1 -KeyVaultName kv-nis-target -InputFolder "C:\exported-secrets"

# Import just one file from the current directory
pwsh ./importAppSettings.ps1 -KeyVaultName kv-nis-target -FilePath (Join-Path (Get-Location) 'component-feedback-hub-appsettings.json')
```

The script validates module availability, ensures the Azure context is set to `NIS.dev1`, and logs success/failure per secret.

## Cleanup

After importing, remove or encrypt the local `kv-secrets` folder (and any other export directories) to avoid leaving sensitive configuration files on disk.
