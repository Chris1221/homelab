#!/bin/bash

# Sync the .env file to 1Password
FIELDS=$(grep -v '^\s*#' .env | grep -v '^\s*$' | \
  while IFS='=' read -r key val; do
    # Remove any inline comments after the value
    val=$(echo "$val" | sed 's/\s*#.*$//')
    # Strip surrounding quotes if present
    val=$(echo "$val" | sed -e 's/^["'\'']//' -e 's/["'\'']$//')
    echo "$key=\"$val\""
  done | xargs)

op item create \
  --category "secureNote" \
  --title "homelab_env" \
  $FIELDS \
  --tags "homelab" \
  --vault "homelab"