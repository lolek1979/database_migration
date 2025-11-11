az account set --subscription "NIS.dev1"
KV_NAME="kv-vzp-dev1-we-aks-001"
OUTPUT_DIR="./appSettings/dev1"

mkdir -p "$OUTPUT_DIR"

az keyvault secret list \
  --vault-name "$KV_NAME" \
  --query '[].id' -o tsv |
while read -r secret_id; do
  name=$(basename "$secret_id")
  value=$(az keyvault secret show --id "$secret_id" --query value -o tsv)
  printf '%s\n' "$value" > "$OUTPUT_DIR/$name.json"
done
