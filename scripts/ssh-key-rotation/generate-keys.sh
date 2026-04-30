#!/usr/bin/env bash
#
# SSH Key Generation Script
#
# Generates new ed25519 SSH keys with proper entropy and security.
#
# Usage:
#   ./generate-keys.sh <key-type> [--host hostname]
#
# Arguments:
#   key-type: auth, signing, or host
#   --host: Specify hostname (for generating keys for other hosts)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEY_TYPE="${1:-}"
HOSTNAME=$(hostname)
USER_EMAIL="greg@burd.me"

# Parse additional arguments
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOSTNAME="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Validate key type
if [[ ! "$KEY_TYPE" =~ ^(auth|signing|host)$ ]]; then
  echo "Usage: $0 <key-type> [--host hostname]"
  echo ""
  echo "Key types:"
  echo "  auth     - Authentication key (SSH connections)"
  echo "  signing  - Signing key (git commits/tags)"
  echo "  host     - Host key (SSH daemon)"
  exit 1
fi

# Determine key paths and comments
case "$KEY_TYPE" in
  auth)
    KEY_PATH="$HOME/.ssh/id_auth_ed25519_new"
    COMMENT="${USER_EMAIL}-auth-${HOSTNAME}-$(date +%Y%m)"
    ;;
  signing)
    KEY_PATH="$HOME/.ssh/id_signing_ed25519_new"
    COMMENT="${USER_EMAIL}-signing-${HOSTNAME}-$(date +%Y%m)"
    ;;
  host)
    KEY_PATH="/tmp/ssh_host_ed25519_key_new"
    COMMENT="root@${HOSTNAME}-$(date +%Y%m)"
    ;;
esac

echo -e "${BLUE}Generating new $KEY_TYPE key${NC}"
echo "  Comment: $COMMENT"
echo "  Path: $KEY_PATH"
echo ""

# Check entropy before generation
if [[ -f /proc/sys/kernel/random/entropy_avail ]]; then
  ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail)
  echo "System entropy: $ENTROPY bits"
  if [[ $ENTROPY -lt 1000 ]]; then
    echo -e "${YELLOW}⚠️  Low entropy detected. Key generation may be slow.${NC}"
    echo "Consider installing haveged: sudo apt install haveged"
    echo ""
  fi
fi

# Backup existing new key if present
if [[ -f "$KEY_PATH" ]]; then
  echo -e "${YELLOW}⚠️  Key already exists: $KEY_PATH${NC}"
  BACKUP_PATH="${KEY_PATH}.backup.$(date +%s)"
  echo "Creating backup: $BACKUP_PATH"
  mv "$KEY_PATH" "$BACKUP_PATH"
  if [[ -f "${KEY_PATH}.pub" ]]; then
    mv "${KEY_PATH}.pub" "${BACKUP_PATH}.pub"
  fi
fi

# Generate the key
echo "Generating key (this may take a moment)..."
if ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$COMMENT" -N "" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Key generated successfully${NC}"
else
  echo -e "${RED}✗ Key generation failed${NC}"
  exit 1
fi

# Set proper permissions
chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"

# Display key information
echo ""
echo "Key details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Private key: $KEY_PATH"
echo "Public key:  ${KEY_PATH}.pub"
echo ""

# Calculate and display fingerprint
FINGERPRINT=$(ssh-keygen -lf "$KEY_PATH" 2>/dev/null | awk '{print $2}')
echo "Fingerprint: $FINGERPRINT"
echo ""

# Display public key
echo "Public key content:"
cat "${KEY_PATH}.pub"
echo ""

# For host keys, also show the age key
if [[ "$KEY_TYPE" == "host" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${BLUE}Age key (for sops-nix):${NC}"

  if command -v ssh-to-age >/dev/null 2>&1; then
    AGE_KEY=$(ssh-to-age < "${KEY_PATH}.pub")
    echo "$AGE_KEY"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Add this age key to .sops.yaml${NC}"
    echo "Add to the hosts section:"
    echo "  - &${HOSTNAME} $AGE_KEY"
  else
    echo -e "${RED}✗ ssh-to-age not found${NC}"
    echo "Install with: nix-shell -p ssh-to-age"
    exit 1
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Key generation complete${NC}"
echo ""

# Next steps guidance
echo "Next steps:"
case "$KEY_TYPE" in
  auth|signing)
    echo "  1. Encrypt with sops: ./sops-rekey.sh $KEY_TYPE add"
    echo "  2. Commit to git: git add secrets && git commit -m 'feat: add new $KEY_TYPE key'"
    echo "  3. Deploy: home-manager switch"
    echo "  4. Test new key works"
    echo "  5. Update git hosting: ./update-git-hosting.sh $KEY_TYPE"
    ;;
  host)
    echo "  1. Copy to /etc/ssh/: sudo mv $KEY_PATH /etc/ssh/ssh_host_ed25519_key_new"
    echo "  2. Add age key to .sops.yaml (see above)"
    echo "  3. Re-encrypt all secrets: ./sops-rekey.sh host update"
    echo "  4. Follow 9-phase host key rotation procedure in ~/.ssh/ROTATION.md"
    ;;
esac

echo ""

exit 0
