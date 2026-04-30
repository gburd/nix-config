#!/usr/bin/env bash
#
# SSH Key Rotation Validation Script
#
# Performs pre-rotation checks to ensure safe key rotation:
#   - Current keys work (SSH, git, sops)
#   - GitHub/Codeberg API access
#   - All hosts reachable
#   - sops-nix can decrypt secrets
#   - Sufficient entropy for key generation
#   - Git repository is clean
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_TYPE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ERRORS=0
WARNINGS=0

# Validation functions
check_ssh_auth() {
  echo -n "  Checking SSH authentication... "

  # Test GitHub
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${GREEN}✓${NC} (GitHub)"
  else
    echo -e "${RED}✗${NC} GitHub authentication failed"
    ((ERRORS++))
    return
  fi

  # Test Codeberg (optional)
  if command -v tea >/dev/null 2>&1; then
    if ssh -T git@codeberg.org 2>&1 | grep -q "Hi there"; then
      echo "    ${GREEN}✓${NC} Codeberg authentication works"
    else
      echo "    ${YELLOW}⚠${NC} Codeberg authentication failed (non-critical)"
      ((WARNINGS++))
    fi
  fi
}

check_git_signing() {
  echo -n "  Checking git signing... "

  # Test if we can create a signed commit
  cd "$CONFIG_ROOT"

  # Create a temporary test commit
  if git commit --allow-empty -S -m "Test signature (validation)" --no-verify >/dev/null 2>&1; then
    # Verify the signature
    if git verify-commit HEAD >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC}"
      # Remove test commit
      git reset --soft HEAD~1 >/dev/null 2>&1
    else
      echo -e "${RED}✗${NC} Signature verification failed"
      git reset --soft HEAD~1 >/dev/null 2>&1
      ((ERRORS++))
    fi
  else
    echo -e "${RED}✗${NC} Cannot create signed commit"
    ((ERRORS++))
  fi
}

check_sops_decryption() {
  echo -n "  Checking sops decryption... "

  HOSTNAME=$(hostname)
  SECRETS_FILE="$CONFIG_ROOT/nixos/workstation/$HOSTNAME/secrets.yaml"

  if [[ ! -f "$SECRETS_FILE" ]]; then
    echo -e "${RED}✗${NC} Secrets file not found: $SECRETS_FILE"
    ((ERRORS++))
    return
  fi

  # Try to decrypt the secrets file
  if sops -d "$SECRETS_FILE" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC} Cannot decrypt secrets file"
    ((ERRORS++))
  fi
}

check_git_hosting_api() {
  echo -n "  Checking git hosting API access... "

  # Check GitHub CLI
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} (gh CLI)"
    else
      echo -e "${RED}✗${NC} GitHub CLI not authenticated"
      echo "    Run: gh auth login"
      ((ERRORS++))
    fi
  else
    echo -e "${YELLOW}⚠${NC} gh CLI not installed (will skip GitHub updates)"
    ((WARNINGS++))
  fi

  # Check Codeberg CLI (optional)
  if command -v tea >/dev/null 2>&1; then
    if tea login --list >/dev/null 2>&1; then
      echo "    ${GREEN}✓${NC} tea CLI authenticated"
    else
      echo "    ${YELLOW}⚠${NC} tea CLI not authenticated (will skip Codeberg)"
      ((WARNINGS++))
    fi
  fi
}

check_entropy() {
  echo -n "  Checking system entropy... "

  if [[ -f /proc/sys/kernel/random/entropy_avail ]]; then
    ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail)
    if [[ $ENTROPY -gt 1000 ]]; then
      echo -e "${GREEN}✓${NC} ($ENTROPY bits)"
    else
      echo -e "${YELLOW}⚠${NC} Low entropy ($ENTROPY bits)"
      echo "    Consider running: sudo haveged or wait for more entropy"
      ((WARNINGS++))
    fi
  else
    echo -e "${BLUE}ℹ${NC} Cannot check (not Linux)"
  fi
}

check_git_status() {
  echo -n "  Checking git repository status... "

  cd "$CONFIG_ROOT"

  # Check if repo is clean
  if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${GREEN}✓${NC} (clean)"
  else
    echo -e "${YELLOW}⚠${NC} Uncommitted changes"
    echo "    Commit or stash changes before rotation"
    ((WARNINGS++))
  fi
}

check_1password() {
  echo -n "  Checking 1Password CLI... "

  if ! command -v op >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} op CLI not found"
    echo "    1Password sync will be skipped"
    ((WARNINGS++))
    return
  fi

  if op account list >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} (authenticated)"
  else
    echo -e "${YELLOW}⚠${NC} Not signed in"
    echo "    Run: eval \$(op signin)"
    echo "    1Password sync will be skipped"
    ((WARNINGS++))
  fi
}

check_host_key_age() {
  echo -n "  Checking host key (sops-nix age key)... "

  HOST_KEY="/etc/ssh/ssh_host_ed25519_key"

  if [[ ! -f "$HOST_KEY" ]]; then
    echo -e "${RED}✗${NC} Host key not found"
    ((ERRORS++))
    return
  fi

  # Check if we can derive age key
  if command -v ssh-to-age >/dev/null 2>&1; then
    AGE_KEY=$(ssh-to-age < "${HOST_KEY}.pub" 2>/dev/null || true)
    if [[ -n "$AGE_KEY" ]]; then
      echo -e "${GREEN}✓${NC}"
      echo "    Age key: ${AGE_KEY:0:20}..."
    else
      echo -e "${RED}✗${NC} Cannot derive age key"
      ((ERRORS++))
    fi
  else
    echo -e "${YELLOW}⚠${NC} ssh-to-age not installed"
    echo "    Run: nix-shell -p ssh-to-age"
    ((WARNINGS++))
  fi
}

check_current_keys() {
  echo -n "  Checking current $KEY_TYPE key... "

  case "$KEY_TYPE" in
    auth)
      KEY_PATH="$HOME/.ssh/id_auth_ed25519"
      ;;
    signing)
      KEY_PATH="$HOME/.ssh/id_signing_ed25519"
      ;;
    host)
      KEY_PATH="/etc/ssh/ssh_host_ed25519_key"
      ;;
    *)
      echo -e "${RED}✗${NC} Unknown key type: $KEY_TYPE"
      ((ERRORS++))
      return
      ;;
  esac

  if [[ -f "$KEY_PATH" ]]; then
    # Check key age
    KEY_AGE_DAYS=$(( ($(date +%s) - $(stat -c %Y "$KEY_PATH" 2>/dev/null || stat -f %m "$KEY_PATH" 2>/dev/null)) / 86400 ))
    echo -e "${GREEN}✓${NC} (age: $KEY_AGE_DAYS days)"

    if [[ $KEY_AGE_DAYS -lt 30 ]]; then
      echo "    ${YELLOW}⚠${NC} Key is relatively new ($KEY_AGE_DAYS days old)"
      echo "    Consider waiting unless this is emergency rotation"
      ((WARNINGS++))
    fi
  else
    echo -e "${YELLOW}⚠${NC} Current key not found at $KEY_PATH"
    echo "    This appears to be initial key setup"
    ((WARNINGS++))
  fi
}

# Main validation
echo "Pre-rotation validation for: $KEY_TYPE"
echo ""

# Common checks
check_current_keys
check_git_status
check_entropy
check_1password

# Key-specific checks
case "$KEY_TYPE" in
  auth)
    echo ""
    echo "Authentication key checks:"
    check_ssh_auth
    check_git_hosting_api
    ;;
  signing)
    echo ""
    echo "Signing key checks:"
    check_git_signing
    check_git_hosting_api
    ;;
  host)
    echo ""
    echo "Host key checks:"
    check_host_key_age
    check_sops_decryption
    ;;
esac

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $ERRORS -eq 0 ]]; then
  if [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed${NC}"
    exit 0
  else
    echo -e "${YELLOW}✓ Validation passed with $WARNINGS warning(s)${NC}"
    echo "  Warnings are non-critical. You can proceed with rotation."
    exit 0
  fi
else
  echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  echo "  Fix errors before proceeding with rotation."
  exit 1
fi
