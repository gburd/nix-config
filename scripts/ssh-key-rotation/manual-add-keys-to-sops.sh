#!/usr/bin/env bash
#
# Manual Helper Script: Add SSH Keys to Sops Secrets
#
# This script helps you manually add the generated SSH keys to the sops secrets file.
# Run this interactively when you have proper sops decryption access.
#
# Usage:
#   ./manual-add-keys-to-sops.sh
#

set -euo pipefail

HOSTNAME=$(hostname)
SECRETS_FILE="$HOME/ws/nix-config/nixos/workstation/$HOSTNAME/secrets.yaml"

echo "=========================================="
echo "Add SSH Keys to Sops Secrets"
echo "=========================================="
echo ""
echo "This script will add the newly generated SSH keys to your encrypted secrets file."
echo ""
echo "Generated keys:"
echo "  Auth key:    ~/.ssh/id_auth_ed25519_new"
echo "  Signing key: ~/.ssh/id_signing_ed25519_new"
echo ""
echo "Target secrets file: $SECRETS_FILE"
echo ""

# Check if keys exist
if [[ ! -f ~/.ssh/id_auth_ed25519_new ]]; then
  echo "ERROR: Auth key not found at ~/.ssh/id_auth_ed25519_new"
  echo "Run: ./scripts/ssh-key-rotation/generate-keys.sh auth"
  exit 1
fi

if [[ ! -f ~/.ssh/id_signing_ed25519_new ]]; then
  echo "ERROR: Signing key not found at ~/.ssh/id_signing_ed25519_new"
  echo "Run: ./scripts/ssh-key-rotation/generate-keys.sh signing"
  exit 1
fi

# Read the private keys
AUTH_PRIVATE=$(cat ~/.ssh/id_auth_ed25519_new)
AUTH_PUBLIC=$(cat ~/.ssh/id_auth_ed25519_new.pub)
AUTH_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_auth_ed25519_new | awk '{print $2}')

SIGNING_PRIVATE=$(cat ~/.ssh/id_signing_ed25519_new)
SIGNING_PUBLIC=$(cat ~/.ssh/id_signing_ed25519_new.pub)
SIGNING_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_signing_ed25519_new | awk '{print $2}')

echo "Keys loaded:"
echo "  Auth fingerprint:    $AUTH_FINGERPRINT"
echo "  Signing fingerprint: $SIGNING_FINGERPRINT"
echo ""

# Create temp file with decrypted secrets
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

echo "Decrypting secrets file..."
if ! sops -d "$SECRETS_FILE" > "$TEMP_FILE"; then
  echo "ERROR: Failed to decrypt secrets file"
  echo ""
  echo "Make sure you have access to decrypt the secrets. You may need:"
  echo "  - Your PGP key imported: gpg --import <key>"
  echo "  - Or age key available: export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt"
  echo "  - Or proper SSH key: the key that derives to the age key in .sops.yaml"
  exit 1
fi

echo "✓ Secrets decrypted"
echo ""

# Check if yq is available
if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required but not found"
  echo "Install with: nix-shell -p yq-go"
  exit 1
fi

# Add ssh-keys section with yq
echo "Adding SSH keys to YAML structure..."

# Auth key
yq -i ".\"ssh-keys\".auth = \"$AUTH_PRIVATE\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"auth-metadata\".fingerprint = \"$AUTH_FINGERPRINT\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"auth-metadata\".created = \"$(date -Iseconds)\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"auth-metadata\".public_key = \"$AUTH_PUBLIC\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"auth-metadata\".rotation_due = \"$(date -d '+90 days' -Iseconds 2>/dev/null || date -v +90d -Iseconds)\"" "$TEMP_FILE"

# Signing key
yq -i ".\"ssh-keys\".signing = \"$SIGNING_PRIVATE\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"signing-metadata\".fingerprint = \"$SIGNING_FINGERPRINT\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"signing-metadata\".created = \"$(date -Iseconds)\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"signing-metadata\".public_key = \"$SIGNING_PUBLIC\"" "$TEMP_FILE"
yq -i ".\"ssh-keys\".\"signing-metadata\".rotation_due = \"$(date -d '+90 days' -Iseconds 2>/dev/null || date -v +90d -Iseconds)\"" "$TEMP_FILE"

echo "✓ Keys added to YAML"
echo ""

# Re-encrypt with sops
echo "Re-encrypting secrets file..."
if ! sops -e "$TEMP_FILE" > "${SECRETS_FILE}.new"; then
  echo "ERROR: Failed to re-encrypt secrets"
  exit 1
fi

# Backup original and replace
cp "$SECRETS_FILE" "${SECRETS_FILE}.backup"
mv "${SECRETS_FILE}.new" "$SECRETS_FILE"

echo "✓ Secrets re-encrypted"
echo ""
echo "=========================================="
echo "SUCCESS!"
echo "=========================================="
echo ""
echo "SSH keys have been added to: $SECRETS_FILE"
echo "Backup saved to: ${SECRETS_FILE}.backup"
echo ""
echo "Next steps:"
echo "  1. Verify the secrets file: sops -d $SECRETS_FILE | grep -A 5 ssh-keys"
echo "  2. Commit changes: git add $SECRETS_FILE && git commit -m 'feat(security): add SSH keys for meh'"
echo "  3. Deploy: home-manager switch --flake ~/ws/nix-config#$HOSTNAME"
echo "  4. Test SSH auth: ssh -T git@github.com"
echo "  5. Test git signing: git commit --allow-empty -S -m 'Test'"
echo ""
