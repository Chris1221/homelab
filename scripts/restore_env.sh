ITEM_TITLE=homelab_env
VAULT_NAME=homelab
OUTPUT_FILE="${1:-.env}"  # default to .env if not specified

if [[ -z "$VAULT_NAME" ]]; then
  echo "Usage: $0 <vault_name> [item_title] [output_file]"
  exit 1
fi

ITEM_ID=$(op item list --vault "$VAULT_NAME" --format json | \
  jq -r --arg title "$ITEM_TITLE" '[.[] | select(.title==$title)] | sort_by(.updatedAt) | last | .id')

if [[ -z "$ITEM_ID" ]]; then
  echo "❌ No matching item titled '$TITLE' found in vault '$VAULT_NAME'"
  exit 2
fi

op item get "$ITEM_ID" --vault "$VAULT_NAME" --format json | \
  jq -r '.fields[] | "\(.label)=\(.value)"' > "$OUTPUT_FILE"
