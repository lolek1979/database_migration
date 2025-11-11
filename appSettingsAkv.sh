#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION="NIS.dev1"
SOURCE_KV="<source-keyvault-name>"
OUTPUT_DIR="./kv-secrets"

az account set --subscription "$SUBSCRIPTION"
mkdir -p "$OUTPUT_DIR"

echo "Exporting secrets from $SOURCE_KV into $OUTPUT_DIR"
az keyvault secret list \
  --vault-name "$SOURCE_KV" \
  --query '[].id' -o tsv |
while read -r secret_id; do
  name=$(basename "$secret_id")
  value=$(az keyvault secret show --id "$secret_id" --query value -o tsv)
  printf '%s\n' "$value" > "$OUTPUT_DIR/$name.json"
done
