#!/usr/bin/env bash
# Restore the restic GCS service-account key from 1Password to disk, where the
# backrest container mounts it (via ${HOME}/.config/gcloud -> /gcloud and
# GOOGLE_APPLICATION_CREDENTIALS=/gcloud/backrest-sa.json in services/backrest.yml).
#
# Run this on a fresh machine before `docker compose up -d backrest`.
#
# Usage: scripts/restore_sa_key.sh [path-to-key.json]
set -euo pipefail

KEY_FILE="${1:-$HOME/.config/gcloud/backrest-sa.json}"
VAULT="homelab"
ITEM="backrest-sa-key"

eval "$(op signin)"

mkdir -p "$(dirname "$KEY_FILE")"
umask 077
op read "op://$VAULT/$ITEM/credential" >"$KEY_FILE"
chmod 600 "$KEY_FILE"

# Sanity check: must be valid JSON with the expected shape.
if ! jq -e '.type == "service_account" and .private_key' "$KEY_FILE" >/dev/null 2>&1; then
  echo "❌ $KEY_FILE does not look like a service-account key" >&2
  exit 1
fi

echo "✅ Wrote $(jq -r '.client_email' "$KEY_FILE") -> $KEY_FILE"
