#!/usr/bin/env bash
#
# SSH Key Rotation Orchestration Script
#
# Usage:
#   ./rotate.sh <key-type> [--dry-run] [--force] [--emergency]
#
# Arguments:
#   key-type: auth, signing, or host
#   --dry-run: Show what would happen without making changes
#   --force: Skip confirmation prompts
#   --emergency: Emergency rotation (no dual-key period)
#
# Examples:
#   ./rotate.sh auth --dry-run         # Preview auth key rotation
#   ./rotate.sh signing                # Rotate signing key
#   ./rotate.sh host --force           # Rotate host key (dangerous!)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
KEY_TYPE="${1:-}"
DRY_RUN=false
FORCE=false
EMERGENCY=false

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --force)
      FORCE=true
      ;;
    --emergency)
      EMERGENCY=true
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
  shift
done

# Validate key type
if [[ ! "$KEY_TYPE" =~ ^(auth|signing|host)$ ]]; then
  echo "Usage: $0 <key-type> [--dry-run] [--force] [--emergency]"
  echo ""
  echo "Key types:"
  echo "  auth     - Authentication key (SSH connections)"
  echo "  signing  - Signing key (git commits/tags)"
  echo "  host     - Host key (SSH daemon, sops-nix) [DANGEROUS]"
  echo ""
  echo "Options:"
  echo "  --dry-run   Show what would happen without making changes"
  echo "  --force     Skip confirmation prompts"
  echo "  --emergency Emergency rotation (no dual-key period)"
  exit 1
fi

# Warning for host key rotation
if [[ "$KEY_TYPE" == "host" ]]; then
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}⚠️  CRITICAL WARNING: HOST KEY ROTATION${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Host key rotation affects sops-nix encryption!"
  echo "This operation requires careful execution to avoid losing access to secrets."
  echo ""
  echo "You should:"
  echo "  1. Have a backup of all secrets"
  echo "  2. Follow the 9-phase rotation procedure in ~/.ssh/ROTATION.md"
  echo "  3. Test thoroughly before removing old keys"
  echo ""
  if [[ "$FORCE" != "true" ]]; then
    read -p "Are you ABSOLUTELY SURE you want to rotate the host key? (type 'yes'): " confirm
    if [[ "$confirm" != "yes" ]]; then
      echo "Host key rotation cancelled."
      exit 1
    fi
  fi
fi

# Print header
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}SSH Key Rotation: ${KEY_TYPE}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configuration Root: $CONFIG_ROOT"
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Dry Run: $DRY_RUN"
echo "Emergency Mode: $EMERGENCY"
echo ""

# Step 1: Validation
echo -e "${BLUE}[Step 1/7]${NC} Running pre-rotation validation..."
if ! "$SCRIPT_DIR/validate.sh" "$KEY_TYPE"; then
  echo -e "${RED}✗ Validation failed. Fix issues before rotating.${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Validation passed${NC}"
echo ""

# Step 2: Generate new key
echo -e "${BLUE}[Step 2/7]${NC} Generating new ${KEY_TYPE} key..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would generate new key with: $SCRIPT_DIR/generate-keys.sh $KEY_TYPE"
else
  if ! "$SCRIPT_DIR/generate-keys.sh" "$KEY_TYPE"; then
    echo -e "${RED}✗ Key generation failed${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✓ New key generated${NC}"
echo ""

# Step 3: Encrypt with sops
echo -e "${BLUE}[Step 3/7]${NC} Encrypting new key with sops..."
HOSTNAME=$(hostname)
SECRETS_FILE="$CONFIG_ROOT/nixos/workstation/$HOSTNAME/secrets.yaml"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo -e "${RED}✗ Secrets file not found: $SECRETS_FILE${NC}"
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would encrypt key and add to: $SECRETS_FILE"
else
  # Encrypt the new key (details in sops-rekey.sh)
  if ! "$SCRIPT_DIR/sops-rekey.sh" "$KEY_TYPE" "add"; then
    echo -e "${RED}✗ Failed to encrypt and add key${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✓ Key encrypted and added to secrets${NC}"
echo ""

# Step 4: Commit to git (dual-key period begins)
echo -e "${BLUE}[Step 4/7]${NC} Committing new key to git repository..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would commit: feat(security): add new $KEY_TYPE key for rotation"
else
  cd "$CONFIG_ROOT"
  git add "$SECRETS_FILE"
  git commit -m "feat(security): add new $KEY_TYPE key for rotation on $HOSTNAME

This adds a new $KEY_TYPE key alongside the existing key (dual-key period).
The old key will remain active for 7 days before being removed.

Rotation date: $(date -Iseconds)"
  echo -e "${GREEN}✓ Changes committed${NC}"
fi
echo ""

# Step 5: Update git hosting services
if [[ "$KEY_TYPE" != "host" ]]; then
  echo -e "${BLUE}[Step 5/7]${NC} Updating git hosting services..."
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Would update GitHub, Codeberg with new key"
  else
    if ! "$SCRIPT_DIR/update-git-hosting.sh" "$KEY_TYPE"; then
      echo -e "${YELLOW}⚠️  Failed to update git hosting services (non-fatal)${NC}"
      echo "You may need to manually add the key to GitHub/Codeberg"
    else
      echo -e "${GREEN}✓ Git hosting services updated${NC}"
    fi
  fi
  echo ""
else
  echo -e "${BLUE}[Step 5/7]${NC} Skipping git hosting update (host key)"
  echo ""
fi

# Step 6: Sync to 1Password
echo -e "${BLUE}[Step 6/7]${NC} Syncing to 1Password..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would sync key to 1Password"
else
  if ! "$SCRIPT_DIR/sync-1password.sh" "$KEY_TYPE" "push"; then
    echo -e "${YELLOW}⚠️  Failed to sync to 1Password (non-fatal)${NC}"
    echo "You may need to manually sync: ~/.local/bin/ssh-sync-to-1password"
  else
    echo -e "${GREEN}✓ Synced to 1Password${NC}"
  fi
fi
echo ""

# Step 7: Summary and next steps
echo -e "${BLUE}[Step 7/7]${NC} Rotation summary"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${GREEN}✓ Dry run completed successfully${NC}"
  echo ""
  echo "To execute rotation, run:"
  echo "  $0 $KEY_TYPE"
else
  echo -e "${GREEN}✓ Key rotation phase 1 completed successfully${NC}"
  echo ""
  echo "Status: DUAL-KEY PERIOD (7 days)"
  echo "Both old and new keys are now active."
  echo ""
  echo "Next steps:"
  echo "  1. Deploy to host: cd $CONFIG_ROOT && home-manager switch"
  echo "  2. Test new key works alongside old key"
  echo "  3. Wait 7 days for dual-key period"
  echo "  4. Run cutover: $SCRIPT_DIR/cutover.sh $KEY_TYPE"
  echo ""
  if [[ "$EMERGENCY" == "true" ]]; then
    echo -e "${YELLOW}Emergency mode: Consider running cutover immediately after testing${NC}"
  fi
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Log rotation to history
if [[ "$DRY_RUN" != "true" ]]; then
  HISTORY_FILE="$CONFIG_ROOT/secrets/ssh-keys/rotation_history.yaml"
  mkdir -p "$(dirname "$HISTORY_FILE")"

  echo "- date: $(date -Iseconds)" >> "$HISTORY_FILE"
  echo "  hostname: $(hostname)" >> "$HISTORY_FILE"
  echo "  key_type: $KEY_TYPE" >> "$HISTORY_FILE"
  echo "  action: generated_new_key" >> "$HISTORY_FILE"
  echo "  emergency: $EMERGENCY" >> "$HISTORY_FILE"
  echo "" >> "$HISTORY_FILE"
fi

exit 0
