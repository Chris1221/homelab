#!/usr/bin/env bash
# Push the restic GCS service-account key into 1Password.
#
# 1Password is the source of truth for this credential (it is deliberately not
# in Terraform state). Run this once after the key is first created, and again
# whenever the key is rotated.
#
# Usage: scripts/push_sa_key.sh [path-to-key.json]
set -euo pipefail

KEY_FILE="${1:-$HOME/.config/gcloud/backrest-sa.json}"
VAULT="homelab"
ITEM="backrest-sa-key"

if [[ ! -r "$KEY_FILE" ]]; then
  echo "❌ Key file not found or unreadable: $KEY_FILE" >&2
  exit 1
fi

KEY_JSON="$(cat "$KEY_FILE")"
SA_EMAIL="$(jq -r '.client_email' <<<"$KEY_JSON")"
PROJECT_ID="$(jq -r '.project_id' <<<"$KEY_JSON")"

eval "$(op signin)"

if op item get "$ITEM" --vault "$VAULT" >/dev/null 2>&1; then
  echo "Updating existing item '$ITEM' in vault '$VAULT'..."
  op item edit "$ITEM" --vault "$VAULT" \
    "credential[password]=$KEY_JSON" \
    "service_account_email[text]=$SA_EMAIL" \
    "project_id[text]=$PROJECT_ID" >/dev/null
else
  echo "Creating item '$ITEM' in vault '$VAULT'..."
  op item create \
    --category "API Credential" \
    --title "$ITEM" \
    --vault "$VAULT" \
    --tags "homelab,backrest" \
    "credential[password]=$KEY_JSON" \
    "service_account_email[text]=$SA_EMAIL" \
    "project_id[text]=$PROJECT_ID" >/dev/null
fi

echo "✅ Stored key for $SA_EMAIL at op://$VAULT/$ITEM/credential"
