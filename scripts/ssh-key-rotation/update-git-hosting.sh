#!/usr/bin/env bash
#
# Git Hosting Service Update Script
#
# Updates SSH keys on GitHub, Codeberg, and other git hosting services.
#
# Usage:
#   ./update-git-hosting.sh <key-type> [--remove-old]
#
# Arguments:
#   key-type: auth or signing
#   --remove-old: Remove old keys (use after dual-key period)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_TYPE="${1:-}"
REMOVE_OLD=false
HOSTNAME=$(hostname)

# Parse additional arguments
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-old)
      REMOVE_OLD=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Validate key type
if [[ ! "$KEY_TYPE" =~ ^(auth|signing)$ ]]; then
  echo "Usage: $0 <key-type> [--remove-old]"
  echo ""
  echo "Key types:"
  echo "  auth     - Authentication key"
  echo "  signing  - Signing key (git commits)"
  echo ""
  echo "Options:"
  echo "  --remove-old  Remove old keys from hosting services"
  exit 1
fi

# Determine key paths
case "$KEY_TYPE" in
  auth)
    NEW_KEY_PATH="$HOME/.ssh/id_auth_ed25519_new"
    OLD_KEY_PATH="$HOME/.ssh/id_auth_ed25519"
    KEY_TITLE="${HOSTNAME}-auth-$(date +%Y%m)"
    GH_TYPE="authentication"
    ;;
  signing)
    NEW_KEY_PATH="$HOME/.ssh/id_signing_ed25519_new"
    OLD_KEY_PATH="$HOME/.ssh/id_signing_ed25519"
    KEY_TITLE="${HOSTNAME}-signing-$(date +%Y%m)"
    GH_TYPE="signing"
    ;;
esac

echo -e "${BLUE}Updating git hosting services: $KEY_TYPE key${NC}"
echo "  Hostname: $HOSTNAME"
echo "  Key title: $KEY_TITLE"
echo ""

# Check if new key exists
if [[ ! -f "${NEW_KEY_PATH}.pub" ]]; then
  echo -e "${RED}✗ New key not found: ${NEW_KEY_PATH}.pub${NC}"
  echo "Generate key first: ./generate-keys.sh $KEY_TYPE"
  exit 1
fi

# Function to update GitHub
update_github() {
  echo -n "Updating GitHub... "

  if ! command -v gh >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} gh CLI not found"
    echo "  Install with: nix-shell -p gh"
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Not authenticated"
    echo "  Run: gh auth login"
    return 1
  fi

  # Add new key
  if [[ "$KEY_TYPE" == "signing" ]]; then
    if gh ssh-key add "${NEW_KEY_PATH}.pub" --title "$KEY_TITLE" --type signing >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} Added signing key"
    else
      echo -e "${RED}✗${NC} Failed to add signing key"
      return 1
    fi
  else
    if gh ssh-key add "${NEW_KEY_PATH}.pub" --title "$KEY_TITLE" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} Added authentication key"
    else
      echo -e "${RED}✗${NC} Failed to add authentication key"
      return 1
    fi
  fi

  # Remove old keys if requested
  if [[ "$REMOVE_OLD" == "true" ]]; then
    echo "  Searching for old keys to remove..."

    # List keys and find old ones for this host
    OLD_KEYS=$(gh ssh-key list --json id,title | \
      jq -r ".[] | select(.title | contains(\"$HOSTNAME-$KEY_TYPE\") and (contains(\"$(date +%Y%m)\") | not)) | .id")

    if [[ -n "$OLD_KEYS" ]]; then
      echo "$OLD_KEYS" | while read -r key_id; do
        if gh ssh-key delete "$key_id" --confirm >/dev/null 2>&1; then
          echo "    ${GREEN}✓${NC} Removed old key: $key_id"
        else
          echo "    ${YELLOW}⚠${NC} Failed to remove key: $key_id"
        fi
      done
    else
      echo "    No old keys found to remove"
    fi
  fi
}

# Function to update Codeberg
update_codeberg() {
  echo -n "Updating Codeberg... "

  if ! command -v tea >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} tea CLI not found"
    echo "  Install with: nix-shell -p tea"
    return 1
  fi

  if ! tea login --list >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Not authenticated"
    echo "  Run: tea login add"
    return 1
  fi

  # Add new key
  if tea ssh-keys add --title "$KEY_TITLE" "${NEW_KEY_PATH}.pub" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Added key"
  else
    echo -e "${RED}✗${NC} Failed to add key"
    return 1
  fi

  # Remove old keys if requested
  if [[ "$REMOVE_OLD" == "true" ]]; then
    echo "  Searching for old keys to remove..."

    # List keys and find old ones for this host
    tea ssh-keys list --output simple | grep "${HOSTNAME}-${KEY_TYPE}" | \
      grep -v "$(date +%Y%m)" | while read -r line; do
      key_id=$(echo "$line" | awk '{print $1}')
      if tea ssh-keys remove "$key_id" >/dev/null 2>&1; then
        echo "    ${GREEN}✓${NC} Removed old key: $key_id"
      else
        echo "    ${YELLOW}⚠${NC} Failed to remove key: $key_id"
      fi
    done
  fi
}

# Update hosting services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SERVICES_UPDATED=0
SERVICES_FAILED=0

# GitHub
if update_github; then
  ((SERVICES_UPDATED++))
else
  ((SERVICES_FAILED++))
fi

# Codeberg
if update_codeberg; then
  ((SERVICES_UPDATED++))
else
  ((SERVICES_FAILED++))
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $SERVICES_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All hosting services updated ($SERVICES_UPDATED)${NC}"
  exit 0
else
  if [[ $SERVICES_UPDATED -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Partial success: $SERVICES_UPDATED updated, $SERVICES_FAILED failed${NC}"
    exit 0
  else
    echo -e "${RED}✗ All hosting services failed to update${NC}"
    exit 1
  fi
fi
