[CmdletBinding()]
param(
    [string]$Subscription = "NIS.dev1",
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    [string]$InputFolder = "$HOME/Desktop/appSettings/dev1"
)

if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
    Write-Error "Az modules not found. Install them with 'Install-Module Az -Scope CurrentUser'."
    exit 1
}

if (-not (Test-Path -Path $InputFolder)) {
    Write-Error "Input folder '$InputFolder' does not exist."
    exit 1
}

try {
    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        Connect-AzAccount -ErrorAction Stop | Out-Null
    }
    Set-AzContext -Subscription $Subscription -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Failed to set Azure context: $($_.Exception.Message)"
    exit 1
}

$files = Get-ChildItem -Path $InputFolder -Filter *.json -File
if (-not $files) {
    Write-Warning "No JSON files found in '$InputFolder'. Nothing to import."
    exit 0
}

foreach ($file in $files) {
    $secretName = $file.BaseName
    $secretValue = Get-Content -Path $file.FullName -Raw
    try {
        Set-AzKeyVaultSecret `
            -VaultName $KeyVaultName `
            -Name $secretName `
            -SecretValue (ConvertTo-SecureString $secretValue -AsPlainText -Force) `
            | Out-Null
        Write-Host "Imported $secretName"
    } catch {
        Write-Warning "Failed to import $secretName: $($_.Exception.Message)"
    }
}
