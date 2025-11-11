[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$KeyVaultName,
    [Parameter(Position = 1)]
    [string]$InputFolder = "$HOME/Desktop/appSettings/dev1",
    [string]$FilePath,
    [string]$Subscription = "NIS.dev1"
)

if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
    Write-Error "Az modules not found. Install them with 'Install-Module Az -Scope CurrentUser'."
    exit 1
}

if ($FilePath) {
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        Write-Error "File '$FilePath' does not exist."
        exit 1
    }
} elseif (-not (Test-Path -Path $InputFolder -PathType Container)) {
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

if ($FilePath) {
    $files = Get-Item -LiteralPath $FilePath
} else {
    $files = Get-ChildItem -Path $InputFolder -Filter *.json -File
    if (-not $files) {
        Write-Warning "No JSON files found in '$InputFolder'. Nothing to import."
        exit 0
    }
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
        Write-Warning ("Failed to import {0}: {1}" -f $secretName, $_.Exception.Message)
    }
}
