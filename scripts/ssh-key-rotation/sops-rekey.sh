#!/usr/bin/env bash
#
# Sops Re-keying Script
#
# Manages encryption and re-encryption of SSH keys with sops.
#
# Usage:
#   ./sops-rekey.sh <key-type> <action>
#
# Actions:
#   add      - Encrypt and add a new key (dual-key period)
#   update   - Re-encrypt all secrets (after .sops.yaml changes)
#   remove   - Remove old key encryption
#
# Arguments:
#   key-type: auth, signing, or host
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_TYPE="${1:-}"
ACTION="${2:-}"
HOSTNAME=$(hostname)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Validate arguments
if [[ ! "$KEY_TYPE" =~ ^(auth|signing|host)$ ]]; then
  echo "Usage: $0 <key-type> <action>"
  echo ""
  echo "Key types: auth, signing, host"
  echo "Actions: add, update, remove"
  exit 1
fi

if [[ ! "$ACTION" =~ ^(add|update|remove)$ ]]; then
  echo "Usage: $0 <key-type> <action>"
  echo ""
  echo "Actions:"
  echo "  add      Encrypt and add new key (dual-key period)"
  echo "  update   Re-encrypt all secrets with new .sops.yaml"
  echo "  remove   Remove old key from secrets"
  exit 1
fi

SECRETS_FILE="$CONFIG_ROOT/nixos/workstation/$HOSTNAME/secrets.yaml"

# Check if sops is available
if ! command -v sops >/dev/null 2>&1; then
  echo -e "${RED}✗ sops not found${NC}"
  echo "Install with: nix-shell -p sops"
  exit 1
fi

# Check if secrets file exists
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo -e "${RED}✗ Secrets file not found: $SECRETS_FILE${NC}"
  exit 1
fi

# Determine key paths
case "$KEY_TYPE" in
  auth)
    NEW_KEY_PATH="$HOME/.ssh/id_auth_ed25519_new"
    OLD_KEY_PATH="$HOME/.ssh/id_auth_ed25519"
    SOPS_PATH="ssh-keys/auth"
    ;;
  signing)
    NEW_KEY_PATH="$HOME/.ssh/id_signing_ed25519_new"
    OLD_KEY_PATH="$HOME/.ssh/id_signing_ed25519"
    SOPS_PATH="ssh-keys/signing"
    ;;
  host)
    NEW_KEY_PATH="/tmp/ssh_host_ed25519_key_new"
    OLD_KEY_PATH="/etc/ssh/ssh_host_ed25519_key"
    SOPS_PATH="host-keys/ssh_host_ed25519"
    ;;
esac

echo -e "${BLUE}Sops re-keying: $KEY_TYPE ($ACTION)${NC}"
echo "  Secrets file: $SECRETS_FILE"
echo ""

# Action: Add new key
if [[ "$ACTION" == "add" ]]; then
  echo "Adding new $KEY_TYPE key to secrets..."

  if [[ ! -f "$NEW_KEY_PATH" ]]; then
    echo -e "${RED}✗ New key not found: $NEW_KEY_PATH${NC}"
    exit 1
  fi

  # Create temporary decrypted file
  TEMP_FILE=$(mktemp)
  trap "rm -f $TEMP_FILE" EXIT

  # Decrypt existing secrets
  echo "  Decrypting existing secrets..."
  if ! sops -d "$SECRETS_FILE" > "$TEMP_FILE"; then
    echo -e "${RED}✗ Failed to decrypt secrets${NC}"
    exit 1
  fi

  # Read the private key
  PRIVATE_KEY=$(cat "$NEW_KEY_PATH")

  # Use yq to add the new key (preserve YAML structure)
  if command -v yq >/dev/null 2>&1; then
    echo "  Adding new key to YAML structure..."

    # Add with -new suffix during dual-key period
    yq -i ".\"${SOPS_PATH}-new\" = \"$PRIVATE_KEY\"" "$TEMP_FILE"

    # Also add metadata
    PUBLIC_KEY=$(cat "${NEW_KEY_PATH}.pub")
    FINGERPRINT=$(ssh-keygen -lf "$NEW_KEY_PATH" | awk '{print $2}')

    yq -i ".\"${SOPS_PATH}-new-metadata\".fingerprint = \"$FINGERPRINT\"" "$TEMP_FILE"
    yq -i ".\"${SOPS_PATH}-new-metadata\".created = \"$(date -Iseconds)\"" "$TEMP_FILE"
    yq -i ".\"${SOPS_PATH}-new-metadata\".public_key = \"$PUBLIC_KEY\"" "$TEMP_FILE"
  else
    echo -e "${YELLOW}⚠  yq not found, using basic append${NC}"
    # Fallback: simple append (not ideal for YAML structure)
    cat >> "$TEMP_FILE" <<EOF
${SOPS_PATH}-new: |
  $PRIVATE_KEY
${SOPS_PATH}-new-metadata:
  fingerprint: $(ssh-keygen -lf "$NEW_KEY_PATH" | awk '{print $2}')
  created: $(date -Iseconds)
  public_key: $(cat "${NEW_KEY_PATH}.pub")
EOF
  fi

  # Re-encrypt with sops
  echo "  Re-encrypting secrets..."
  if ! sops -e "$TEMP_FILE" > "${SECRETS_FILE}.new"; then
    echo -e "${RED}✗ Failed to encrypt secrets${NC}"
    exit 1
  fi

  # Replace original file
  mv "${SECRETS_FILE}.new" "$SECRETS_FILE"

  echo -e "${GREEN}✓ New key added to secrets${NC}"
  echo "  Path in secrets: ${SOPS_PATH}-new"

# Action: Update (re-encrypt all secrets)
elif [[ "$ACTION" == "update" ]]; then
  echo "Re-encrypting all secrets with current .sops.yaml..."

  # Update keys for the specific secrets file
  if ! sops updatekeys "$SECRETS_FILE"; then
    echo -e "${RED}✗ Failed to update keys${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Secrets re-encrypted${NC}"

  # If this is for all secrets files, do them all
  read -p "Re-encrypt ALL secrets files? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Finding all secrets files..."
    find "$CONFIG_ROOT" -name "secrets.yaml" -type f | while read -r file; do
      echo "  Updating: $file"
      if sops updatekeys "$file"; then
        echo "    ${GREEN}✓${NC}"
      else
        echo "    ${RED}✗${NC}"
      fi
    done
  fi

# Action: Remove old key
elif [[ "$ACTION" == "remove" ]]; then
  echo "Removing old $KEY_TYPE key from secrets..."

  # Create temporary decrypted file
  TEMP_FILE=$(mktemp)
  trap "rm -f $TEMP_FILE" EXIT

  # Decrypt existing secrets
  echo "  Decrypting existing secrets..."
  if ! sops -d "$SECRETS_FILE" > "$TEMP_FILE"; then
    echo -e "${RED}✗ Failed to decrypt secrets${NC}"
    exit 1
  fi

  # Remove the old key path
  if command -v yq >/dev/null 2>&1; then
    echo "  Removing old key from YAML structure..."
    yq -i "del(.\"${SOPS_PATH}\")" "$TEMP_FILE"
    yq -i "del(.\"${SOPS_PATH}-metadata\")" "$TEMP_FILE"
  else
    echo -e "${YELLOW}⚠  yq not found, manual removal required${NC}"
    echo "Edit $SECRETS_FILE and remove: ${SOPS_PATH}"
    exit 1
  fi

  # Re-encrypt with sops
  echo "  Re-encrypting secrets..."
  if ! sops -e "$TEMP_FILE" > "${SECRETS_FILE}.new"; then
    echo -e "${RED}✗ Failed to encrypt secrets${NC}"
    exit 1
  fi

  # Replace original file
  mv "${SECRETS_FILE}.new" "$SECRETS_FILE"

  echo -e "${GREEN}✓ Old key removed from secrets${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Sops operation completed${NC}"
echo ""
echo "Next steps:"
case "$ACTION" in
  add)
    echo "  1. Commit changes: git add $SECRETS_FILE && git commit -m 'feat: add new $KEY_TYPE key'"
    echo "  2. Deploy: home-manager switch"
    echo "  3. Wait for dual-key period (7 days)"
    echo "  4. Cutover: move new key to primary position"
    ;;
  update)
    echo "  1. Verify decryption: sops -d $SECRETS_FILE"
    echo "  2. Commit changes: git add . && git commit -m 'chore: re-encrypt secrets'"
    ;;
  remove)
    echo "  1. Verify old key is not in use"
    echo "  2. Commit changes: git add $SECRETS_FILE && git commit -m 'chore: remove old $KEY_TYPE key'"
    ;;
esac
echo ""

exit 0
