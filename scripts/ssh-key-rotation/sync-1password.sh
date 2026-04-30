#!/usr/bin/env bash
#
# 1Password SSH Key Sync Script
#
# Bidirectional sync between filesystem SSH keys and 1Password vault.
#
# Usage:
#   ./sync-1password.sh <key-type> <direction>
#
# Arguments:
#   key-type: auth, signing, or both
#   direction: push (to 1Password), pull (from 1Password), or check
#
# Examples:
#   ./sync-1password.sh auth push       # Backup auth key to 1Password
#   ./sync-1password.sh signing pull    # Restore signing key from 1Password
#   ./sync-1password.sh both check      # Check sync status
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_TYPE="${1:-}"
DIRECTION="${2:-}"
HOSTNAME=$(hostname)
VAULT="Private"  # Default 1Password vault

# Validate arguments
if [[ ! "$KEY_TYPE" =~ ^(auth|signing|both)$ ]]; then
  echo "Usage: $0 <key-type> <direction>"
  echo ""
  echo "Key types: auth, signing, both"
  echo "Directions: push, pull, check"
  exit 1
fi

if [[ ! "$DIRECTION" =~ ^(push|pull|check)$ ]]; then
  echo "Usage: $0 <key-type> <direction>"
  echo ""
  echo "Directions:"
  echo "  push   Sync local keys TO 1Password (backup)"
  echo "  pull   Sync keys FROM 1Password (restore)"
  echo "  check  Check sync status (compare timestamps)"
  exit 1
fi

# Check if op CLI is available
if ! command -v op >/dev/null 2>&1; then
  echo -e "${RED}✗ 1Password CLI (op) not found${NC}"
  echo "Install with: nix-shell -p _1password-cli"
  exit 1
fi

# Check if signed in to 1Password
if ! op account list >/dev/null 2>&1; then
  echo -e "${RED}✗ Not signed in to 1Password${NC}"
  echo "Run: eval \$(op signin)"
  exit 1
fi

echo -e "${BLUE}1Password Sync: $KEY_TYPE ($DIRECTION)${NC}"
echo "  Hostname: $HOSTNAME"
echo "  Vault: $VAULT"
echo ""

# Function to sync a key to 1Password (push)
push_key() {
  local key_type="$1"
  local key_path="$2"
  local title="${HOSTNAME}-${key_type}-$(date +%Y%m)"

  echo -n "  Pushing $key_type key... "

  if [[ ! -f "$key_path" ]]; then
    echo -e "${RED}✗${NC} Key not found: $key_path"
    return 1
  fi

  local private_key=$(cat "$key_path")
  local public_key=$(cat "${key_path}.pub" 2>/dev/null || echo "")

  # Check if item already exists
  if op item get "$title" --vault "$VAULT" >/dev/null 2>&1; then
    # Update existing item
    if op item edit "$title" --vault "$VAULT" \
         "private_key[password]=$private_key" \
         "public_key[text]=$public_key" \
         "last_synced[text]=$(date -Iseconds)" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} Updated"
    else
      echo -e "${RED}✗${NC} Update failed"
      return 1
    fi
  else
    # Create new item
    if op item create \
         --category "SSH Key" \
         --title "$title" \
         --vault "$VAULT" \
         "private_key[password]=$private_key" \
         "public_key[text]=$public_key" \
         "hostname[text]=$HOSTNAME" \
         "key_type[text]=$key_type" \
         "created[text]=$(date -Iseconds)" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} Created"
    else
      echo -e "${RED}✗${NC} Creation failed"
      return 1
    fi
  fi
}

# Function to restore a key from 1Password (pull)
pull_key() {
  local key_type="$1"
  local key_path="$2"

  echo -n "  Pulling $key_type key... "

  # Find the most recent key for this host and type
  local title=$(op item list --vault "$VAULT" --categories "SSH Key" --format json 2>/dev/null | \
    jq -r ".[] | select(.title | contains(\"$HOSTNAME-$key_type\")) | .title" | \
    sort -r | head -n1)

  if [[ -z "$title" ]]; then
    echo -e "${RED}✗${NC} No key found in 1Password"
    return 1
  fi

  echo -e "${BLUE}($title)${NC}"

  # Get the private key
  local private_key=$(op item get "$title" --vault "$VAULT" --fields "private_key" 2>/dev/null)
  if [[ -z "$private_key" ]]; then
    echo "    ${RED}✗${NC} Failed to retrieve private key"
    return 1
  fi

  # Backup existing key if present
  if [[ -f "$key_path" ]]; then
    local backup_path="${key_path}.backup.$(date +%s)"
    echo "    Backing up existing key to $backup_path"
    cp "$key_path" "$backup_path"
    if [[ -f "${key_path}.pub" ]]; then
      cp "${key_path}.pub" "${backup_path}.pub"
    fi
  fi

  # Write private key
  echo "$private_key" > "$key_path"
  chmod 600 "$key_path"

  # Get public key
  local public_key=$(op item get "$title" --vault "$VAULT" --fields "public_key" 2>/dev/null)
  if [[ -n "$public_key" ]]; then
    echo "$public_key" > "${key_path}.pub"
    chmod 644 "${key_path}.pub"
  fi

  echo "    ${GREEN}✓${NC} Restored from 1Password"
}

# Function to check sync status
check_key() {
  local key_type="$1"
  local key_path="$2"

  echo "  Checking $key_type key:"

  # Local key status
  if [[ -f "$key_path" ]]; then
    local local_mtime=$(stat -c %Y "$key_path" 2>/dev/null || stat -f %m "$key_path" 2>/dev/null)
    local local_date=$(date -d "@$local_mtime" 2>/dev/null || date -r "$local_mtime")
    echo "    Local:     ${GREEN}✓${NC} (modified: $local_date)"
  else
    echo "    Local:     ${RED}✗${NC} Not found"
  fi

  # 1Password status
  local title="${HOSTNAME}-${key_type}-$(date +%Y%m)"
  if op item get "$title" --vault "$VAULT" >/dev/null 2>&1; then
    local op_date=$(op item get "$title" --vault "$VAULT" --fields "last_synced" 2>/dev/null || echo "unknown")
    echo "    1Password: ${GREEN}✓${NC} (synced: $op_date)"

    # Compare fingerprints if both exist
    if [[ -f "$key_path" ]]; then
      local local_fp=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')
      local op_pubkey=$(op item get "$title" --vault "$VAULT" --fields "public_key" 2>/dev/null)

      if [[ -n "$op_pubkey" ]]; then
        local op_fp=$(echo "$op_pubkey" | ssh-keygen -lf /dev/stdin 2>/dev/null | awk '{print $2}')

        if [[ "$local_fp" == "$op_fp" ]]; then
          echo "    Status:    ${GREEN}✓${NC} In sync (fingerprints match)"
        else
          echo "    Status:    ${YELLOW}⚠${NC} Out of sync (fingerprints differ)"
          echo "               Local:  $local_fp"
          echo "               1Pass:  $op_fp"
        fi
      fi
    fi
  else
    echo "    1Password: ${RED}✗${NC} Not found"
  fi
}

# Process based on key type
if [[ "$KEY_TYPE" == "both" ]]; then
  KEY_TYPES=("auth" "signing")
else
  KEY_TYPES=("$KEY_TYPE")
fi

TOTAL_SUCCESS=0
TOTAL_FAILED=0

for type in "${KEY_TYPES[@]}"; do
  case "$type" in
    auth)
      key_path="$HOME/.ssh/id_auth_ed25519"
      ;;
    signing)
      key_path="$HOME/.ssh/id_signing_ed25519"
      ;;
  esac

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$type key:"

  case "$DIRECTION" in
    push)
      if push_key "$type" "$key_path"; then
        ((TOTAL_SUCCESS++))
      else
        ((TOTAL_FAILED++))
      fi
      ;;
    pull)
      if pull_key "$type" "$key_path"; then
        ((TOTAL_SUCCESS++))
      else
        ((TOTAL_FAILED++))
      fi
      ;;
    check)
      check_key "$type" "$key_path"
      ;;
  esac
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$DIRECTION" == "check" ]]; then
  echo -e "${GREEN}✓ Sync status check complete${NC}"
else
  if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All operations successful ($TOTAL_SUCCESS)${NC}"

    if [[ "$DIRECTION" == "pull" ]]; then
      echo ""
      echo "Next steps after restore:"
      echo "  1. Test SSH: ssh -T git@github.com"
      echo "  2. Test git signing: git commit --allow-empty -S -m 'Test'"
      echo "  3. Add to ssh-agent: ssh-add ~/.ssh/id_*_ed25519"
    fi
  else
    echo -e "${YELLOW}⚠ Partial success: $TOTAL_SUCCESS succeeded, $TOTAL_FAILED failed${NC}"
  fi
fi
echo ""

exit 0
