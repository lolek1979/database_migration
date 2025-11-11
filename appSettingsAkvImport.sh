#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION="NIS.dev1"
TARGET_KV="<target-keyvault-name>"
INPUT_DIR="./kv-secrets"

az account set --subscription "$SUBSCRIPTION"

echo "Importing secrets from $INPUT_DIR into $TARGET_KV"
for file in "$INPUT_DIR"/*.json; do
  [ -e "$file" ] || continue
  secret_name=$(basename "${file%.json}")
  az keyvault secret set \
    --vault-name "$TARGET_KV" \
    --name "$secret_name" \
    --value "$(cat "$file")" \
    >/dev/null
  echo "Imported $secret_name"
done
