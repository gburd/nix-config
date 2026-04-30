#!/usr/bin/env bash
#
# Host Key Rotation Helper Script
#
# This script guides you through the 9-phase host key rotation process.
# It automates tedious tasks while keeping critical decisions manual.
#
# ⚠️ WARNING: Read docs/HOST-KEY-ROTATION.md before using this script
#
# Usage:
#   ./host-key-rotation-helper.sh <phase>
#
# Phases:
#   A - Generate new host key
#   B - Derive age keys
#   C - Update .sops.yaml (manual editing required)
#   D - Re-encrypt all secrets
#   E - Deploy and verify
#   F - Cutover to new key
#   G - Verify decryption
#   H - Safety period check
#   I - Remove old key
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PHASE="${1:-}"
HOSTNAME=$(hostname)
CONFIG_ROOT="$HOME/ws/nix-config"
STATE_FILE="$CONFIG_ROOT/.host-key-rotation-state"

# Banner
show_banner() {
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}⚠️  HOST KEY ROTATION - CRITICAL OPERATION${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Hostname: $HOSTNAME"
  echo "Phase: $PHASE"
  echo ""
}

# Save state
save_state() {
  local key="$1"
  local value="$2"
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$key=$value" >> "$STATE_FILE"
}

# Load state
load_state() {
  local key="$1"
  if [[ -f "$STATE_FILE" ]]; then
    grep "^${key}=" "$STATE_FILE" | tail -1 | cut -d= -f2
  fi
}

# Validate phase argument
if [[ ! "$PHASE" =~ ^[A-I]$ ]]; then
  echo "Usage: $0 <phase>"
  echo ""
  echo "Phases:"
  echo "  A - Generate new host key"
  echo "  B - Derive age keys"
  echo "  C - Update .sops.yaml"
  echo "  D - Re-encrypt all secrets"
  echo "  E - Deploy and verify"
  echo "  F - Cutover to new key"
  echo "  G - Verify decryption"
  echo "  H - Safety period check"
  echo "  I - Remove old key"
  echo ""
  echo "⚠️  Read docs/HOST-KEY-ROTATION.md first!"
  exit 1
fi

show_banner

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE A: Generate New Host Key
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$PHASE" == "A" ]]; then
  echo -e "${BLUE}Phase A: Generate New Host Key${NC}"
  echo ""
  echo "This will generate a new SSH host key alongside the existing one."
  echo "No production changes yet."
  echo ""
  read -p "Continue? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi

  echo ""
  echo "Generating new host key..."

  # Check if new key already exists
  if sudo test -f /etc/ssh/ssh_host_ed25519_key_NEW; then
    echo -e "${YELLOW}⚠️  ssh_host_ed25519_key_NEW already exists${NC}"
    read -p "Overwrite? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
      echo "Keeping existing key."
    else
      sudo rm /etc/ssh/ssh_host_ed25519_key_NEW
    fi
  fi

  # Generate key
  sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key_NEW \
    -C "root@${HOSTNAME}-$(date +%Y%m)" -N ""

  sudo chmod 600 /etc/ssh/ssh_host_ed25519_key_NEW
  sudo chmod 644 /etc/ssh/ssh_host_ed25519_key_NEW.pub

  # Display fingerprint
  echo ""
  echo -e "${GREEN}✓ New host key generated${NC}"
  echo ""
  NEW_FP=$(sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key_NEW | awk '{print $2}')
  echo "New key fingerprint: $NEW_FP"

  # Save state
  save_state "PHASE_A_COMPLETE" "$(date -Iseconds)"
  save_state "NEW_KEY_FINGERPRINT" "$NEW_FP"

  # Backup old key
  if ! sudo test -f /etc/ssh/ssh_host_ed25519_key.OLD; then
    echo ""
    echo "Backing up current key..."
    sudo cp /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.OLD
    sudo cp /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.OLD.pub

    OLD_FP=$(sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.OLD | awk '{print $2}')
    echo "Old key fingerprint: $OLD_FP"
    save_state "OLD_KEY_FINGERPRINT" "$OLD_FP"
  fi

  echo ""
  echo -e "${GREEN}✓ Phase A complete${NC}"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh B' to derive age keys"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE B: Derive Age Keys
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "B" ]]; then
  echo -e "${BLUE}Phase B: Derive Age Keys${NC}"
  echo ""

  # Check Phase A complete
  if [[ -z "$(load_state "PHASE_A_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase A not complete. Run Phase A first.${NC}"
    exit 1
  fi

  # Check ssh-to-age is available
  if ! command -v ssh-to-age >/dev/null 2>&1; then
    echo "Installing ssh-to-age..."
    nix-shell -p ssh-to-age --run "echo 'ssh-to-age installed'"
  fi

  echo "Deriving age keys from host keys..."
  echo ""

  # Derive from new key
  AGE_KEY_NEW=$(sudo ssh-to-age < /etc/ssh/ssh_host_ed25519_key_NEW.pub)
  echo -e "${GREEN}New age key:${NC}"
  echo "  $AGE_KEY_NEW"
  save_state "AGE_KEY_NEW" "$AGE_KEY_NEW"

  # Derive from old key
  AGE_KEY_OLD=$(sudo ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
  echo ""
  echo -e "${YELLOW}Old age key:${NC}"
  echo "  $AGE_KEY_OLD"
  save_state "AGE_KEY_OLD" "$AGE_KEY_OLD"

  # Check if old key matches .sops.yaml
  echo ""
  echo "Checking .sops.yaml..."
  cd "$CONFIG_ROOT"

  if grep -q "$AGE_KEY_OLD" .sops.yaml; then
    echo -e "${GREEN}✓ Old age key matches .sops.yaml${NC}"
  else
    echo -e "${RED}✗ Old age key does NOT match .sops.yaml${NC}"
    echo "This is a problem. Expected to find:"
    echo "  $AGE_KEY_OLD"
    echo ""
    echo "Found in .sops.yaml:"
    grep -A 5 "$HOSTNAME" .sops.yaml || echo "  (hostname not found)"
    echo ""
    echo "DO NOT PROCEED until this is resolved."
    exit 1
  fi

  save_state "PHASE_B_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase B complete${NC}"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh C' to update .sops.yaml"
  echo ""
  echo "You will need to add this age key to .sops.yaml:"
  echo "  $AGE_KEY_NEW"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE C: Update .sops.yaml
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "C" ]]; then
  echo -e "${BLUE}Phase C: Update .sops.yaml${NC}"
  echo ""

  # Check Phase B complete
  if [[ -z "$(load_state "PHASE_B_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase B not complete. Run Phase B first.${NC}"
    exit 1
  fi

  AGE_KEY_NEW=$(load_state "AGE_KEY_NEW")
  AGE_KEY_OLD=$(load_state "AGE_KEY_OLD")

  echo "This phase requires manual editing of .sops.yaml"
  echo ""
  echo "You need to:"
  echo "  1. Rename current key to '${HOSTNAME}-old'"
  echo "  2. Add new key as '${HOSTNAME}-new'"
  echo "  3. Update creation rules to use BOTH keys"
  echo ""
  echo "Old key (rename to ${HOSTNAME}-old):"
  echo "  $AGE_KEY_OLD"
  echo ""
  echo "New key (add as ${HOSTNAME}-new):"
  echo "  $AGE_KEY_NEW"
  echo ""

  # Backup .sops.yaml
  cd "$CONFIG_ROOT"
  cp .sops.yaml .sops.yaml.before-phase-c

  echo "Backup created: .sops.yaml.before-phase-c"
  echo ""
  read -p "Open .sops.yaml for editing? (yes/no): " confirm

  if [[ "$confirm" == "yes" ]]; then
    ${EDITOR:-nano} .sops.yaml
  fi

  echo ""
  echo "Verify your changes:"
  echo ""
  echo "Should see both keys:"
  grep -A 10 "$HOSTNAME" .sops.yaml || echo "Error: hostname not found"
  echo ""

  read -p "Is .sops.yaml correct? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Fix .sops.yaml and run Phase C again"
    exit 1
  fi

  # Commit .sops.yaml
  echo ""
  read -p "Commit .sops.yaml to git? (yes/no): " confirm
  if [[ "$confirm" == "yes" ]]; then
    git add .sops.yaml
    git commit -m "feat(security): add new age key for $HOSTNAME (dual-key period)

Old age key: $AGE_KEY_OLD
New age key: $AGE_KEY_NEW

This begins the dual-key period. Both keys can decrypt secrets."
    echo -e "${GREEN}✓ Committed to git${NC}"
  fi

  save_state "PHASE_C_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase C complete${NC}"
  echo ""
  echo "⚠️  DUAL-KEY PERIOD HAS BEGUN"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh D' to re-encrypt secrets"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE D: Re-encrypt All Secrets
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "D" ]]; then
  echo -e "${BLUE}Phase D: Re-encrypt All Secrets${NC}"
  echo ""
  echo -e "${RED}⚠️  CRITICAL PHASE${NC}"
  echo ""
  echo "This will re-encrypt ALL secrets with both old and new age keys."
  echo "If this fails, you may lose access to secrets."
  echo ""

  # Check Phase C complete
  if [[ -z "$(load_state "PHASE_C_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase C not complete. Run Phase C first.${NC}"
    exit 1
  fi

  cd "$CONFIG_ROOT"

  # Test current decryption BEFORE re-encrypting
  echo "Testing current decryption..."
  if ! sops -d "nixos/workstation/$HOSTNAME/secrets.yaml" >/dev/null 2>&1; then
    echo -e "${RED}✗ Cannot decrypt secrets with current key${NC}"
    echo "DO NOT PROCEED. Fix decryption first."
    exit 1
  fi
  echo -e "${GREEN}✓ Current decryption works${NC}"
  echo ""

  read -p "Proceed with re-encryption? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi

  # Find all secrets files
  echo ""
  echo "Finding all secrets files..."
  SECRETS_FILES=$(find . -name "secrets.yaml" -type f)
  echo "$SECRETS_FILES"
  echo ""

  # Re-encrypt each file
  FAILED=0
  for file in $SECRETS_FILES; do
    echo "Re-encrypting: $file"
    if sops updatekeys "$file"; then
      # Verify decryption
      if sops -d "$file" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} $file"
      else
        echo "  ${RED}✗${NC} $file - DECRYPTION FAILED AFTER RE-ENCRYPTION"
        ((FAILED++))
      fi
    else
      echo "  ${RED}✗${NC} $file - RE-ENCRYPTION FAILED"
      ((FAILED++))
    fi
  done

  if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}✗ Re-encryption failed for $FAILED file(s)${NC}"
    echo ""
    echo "ROLLBACK:"
    echo "  cp .sops.yaml.before-phase-c .sops.yaml"
    echo "  git reset --hard HEAD~1"
    exit 1
  fi

  echo ""
  echo -e "${GREEN}✓ All secrets re-encrypted successfully${NC}"

  # Commit
  echo ""
  read -p "Commit re-encrypted secrets? (yes/no): " confirm
  if [[ "$confirm" == "yes" ]]; then
    git add .
    git commit -m "chore(security): re-encrypt secrets with dual age keys for $HOSTNAME

All secrets now encrypted with both old and new age keys."
    echo -e "${GREEN}✓ Committed to git${NC}"
  fi

  save_state "PHASE_D_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase D complete${NC}"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh E' to deploy and verify"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE E: Deploy and Verify
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "E" ]]; then
  echo -e "${BLUE}Phase E: Deploy and Verify${NC}"
  echo ""

  # Check Phase D complete
  if [[ -z "$(load_state "PHASE_D_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase D not complete. Run Phase D first.${NC}"
    exit 1
  fi

  cd "$CONFIG_ROOT"

  echo "This will:"
  echo "  1. Push changes to git"
  echo "  2. Run nixos-rebuild switch"
  echo "  3. Verify secrets still decrypt"
  echo ""
  read -p "Continue? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi

  # Push to git
  echo ""
  echo "Pushing to git..."
  git push

  # Rebuild NixOS
  echo ""
  echo "Running nixos-rebuild..."
  if sudo nixos-rebuild switch --flake ".#$HOSTNAME"; then
    echo -e "${GREEN}✓ NixOS rebuild successful${NC}"
  else
    echo -e "${RED}✗ NixOS rebuild failed${NC}"
    exit 1
  fi

  # Verify decryption
  echo ""
  echo "Verifying secrets decryption..."
  if sops -d "nixos/workstation/$HOSTNAME/secrets.yaml" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Secrets decrypt successfully${NC}"
  else
    echo -e "${RED}✗ Cannot decrypt secrets${NC}"
    exit 1
  fi

  # Check example secret
  echo ""
  echo "Checking deployed secrets..."
  if [[ -f ~/.config/claude-code/.bearer_token ]]; then
    echo -e "${GREEN}✓ Bearer token accessible${NC}"
  else
    echo -e "${YELLOW}⚠️  Bearer token not found (may be normal for this host)${NC}"
  fi

  save_state "PHASE_E_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase E complete${NC}"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh F' to cutover to new key"
  echo ""
  echo -e "${RED}⚠️  Phase F is the point of no return for SSH clients${NC}"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE F: Cutover to New Key
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "F" ]]; then
  echo -e "${BLUE}Phase F: Cutover to New Key${NC}"
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}⚠️  HIGH RISK PHASE - POINT OF NO RETURN${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "This will replace the SSH host key."
  echo ""
  echo "After this:"
  echo "  - SSH clients will see 'REMOTE HOST IDENTIFICATION HAS CHANGED'"
  echo "  - You must update ~/.ssh/known_hosts on all clients"
  echo "  - The new age key will be used for decryption"
  echo ""
  echo "⚠️  DO THIS AT THE CONSOLE, NOT OVER SSH"
  echo ""

  # Check Phase E complete
  if [[ -z "$(load_state "PHASE_E_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase E not complete. Run Phase E first.${NC}"
    exit 1
  fi

  read -p "Are you at the console? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Go to the console and run this phase again."
    exit 1
  fi

  read -p "Proceed with cutover? (type 'CUTOVER'): " confirm
  if [[ "$confirm" != "CUTOVER" ]]; then
    echo "Aborted."
    exit 1
  fi

  # Create final backup
  echo ""
  echo "Creating backup..."
  sudo tar -czf /root/ssh-backup-$(date +%Y%m%d-%H%M%S).tar.gz /etc/ssh/
  echo -e "${GREEN}✓ Backup created in /root/${NC}"

  # Replace host key
  echo ""
  echo "Stopping SSH daemon..."
  sudo systemctl stop sshd

  echo "Replacing host key..."
  sudo mv /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.OLD
  sudo mv /etc/ssh/ssh_host_ed25519_key_NEW /etc/ssh/ssh_host_ed25519_key

  sudo mv /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.OLD.pub
  sudo mv /etc/ssh/ssh_host_ed25519_key_NEW.pub /etc/ssh/ssh_host_ed25519_key.pub

  sudo chmod 600 /etc/ssh/ssh_host_ed25519_key
  sudo chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

  echo "Starting SSH daemon..."
  sudo systemctl start sshd

  # Verify
  if sudo systemctl is-active sshd >/dev/null; then
    echo -e "${GREEN}✓ SSH daemon is running${NC}"
  else
    echo -e "${RED}✗ SSH daemon failed to start${NC}"
    echo "EMERGENCY ROLLBACK:"
    echo "  sudo systemctl stop sshd"
    echo "  sudo mv /etc/ssh/ssh_host_ed25519_key.OLD /etc/ssh/ssh_host_ed25519_key"
    echo "  sudo systemctl start sshd"
    exit 1
  fi

  # Show fingerprint
  echo ""
  NEW_FP=$(sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key | awk '{print $2}')
  echo "Active host key fingerprint: $NEW_FP"

  save_state "PHASE_F_COMPLETE" "$(date -Iseconds)"
  save_state "CUTOVER_DATE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase F complete${NC}"
  echo ""
  echo -e "${RED}⚠️  SSH clients will see host key changed warning${NC}"
  echo ""
  echo "On client machines, run:"
  echo "  ssh-keygen -R $HOSTNAME"
  echo "  ssh $HOSTNAME  # Accept new key"
  echo ""
  echo "Next: Run './host-key-rotation-helper.sh G' to verify decryption"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE G: Verify Decryption
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "G" ]]; then
  echo -e "${BLUE}Phase G: Verify Decryption${NC}"
  echo ""
  echo -e "${RED}⚠️  CRITICAL VERIFICATION${NC}"
  echo ""

  # Check Phase F complete
  if [[ -z "$(load_state "PHASE_F_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase F not complete. Run Phase F first.${NC}"
    exit 1
  fi

  cd "$CONFIG_ROOT"

  AGE_KEY_NEW=$(load_state "AGE_KEY_NEW")

  # Verify age key matches
  echo "Verifying age key..."
  CURRENT_AGE=$(sudo ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)

  if [[ "$CURRENT_AGE" == "$AGE_KEY_NEW" ]]; then
    echo -e "${GREEN}✓ Age key matches expected new key${NC}"
    echo "  $CURRENT_AGE"
  else
    echo -e "${RED}✗ Age key does NOT match${NC}"
    echo "Expected: $AGE_KEY_NEW"
    echo "Current:  $CURRENT_AGE"
    echo ""
    echo "CRITICAL: Host key may be wrong. Check /etc/ssh/"
    exit 1
  fi

  # Test decryption
  echo ""
  echo "Testing sops decryption..."
  if sops -d "nixos/workstation/$HOSTNAME/secrets.yaml" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Secrets decrypt successfully${NC}"
  else
    echo -e "${RED}✗ Cannot decrypt secrets${NC}"
    echo ""
    echo "EMERGENCY ROLLBACK REQUIRED"
    echo "See docs/HOST-KEY-ROTATION.md Emergency Rollback section"
    exit 1
  fi

  # Test deployed secrets
  echo ""
  echo "Testing deployed secrets..."
  if [[ -f ~/.config/claude-code/.bearer_token ]]; then
    if cat ~/.config/claude-code/.bearer_token >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Bearer token accessible${NC}"
    else
      echo -e "${RED}✗ Bearer token not readable${NC}"
    fi
  fi

  # Rebuild to refresh secrets
  echo ""
  echo "Rebuilding NixOS to refresh secrets..."
  if sudo nixos-rebuild switch --flake ".#$HOSTNAME"; then
    echo -e "${GREEN}✓ NixOS rebuild successful${NC}"
  else
    echo -e "${YELLOW}⚠️  NixOS rebuild failed (may be non-fatal)${NC}"
  fi

  save_state "PHASE_G_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}✓ Phase G complete${NC}"
  echo ""
  echo "Next: Wait 30 days, then run './host-key-rotation-helper.sh H' for checks"
  echo ""
  CUTOVER_DATE=$(load_state "CUTOVER_DATE")
  echo "Cutover date: $CUTOVER_DATE"
  echo "30-day check due: $(date -d "$CUTOVER_DATE + 30 days" -Iseconds 2>/dev/null || echo "unknown")"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE H: Safety Period Check
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "H" ]]; then
  echo -e "${BLUE}Phase H: Safety Period Check${NC}"
  echo ""

  # Check Phase G complete
  if [[ -z "$(load_state "PHASE_G_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase G not complete. Run Phase G first.${NC}"
    exit 1
  fi

  CUTOVER_DATE=$(load_state "CUTOVER_DATE")
  DAYS_SINCE=$(( ($(date +%s) - $(date -d "$CUTOVER_DATE" +%s 2>/dev/null || echo 0)) / 86400 ))

  echo "Cutover date: $CUTOVER_DATE"
  echo "Days since cutover: $DAYS_SINCE"
  echo ""

  if [[ $DAYS_SINCE -lt 30 ]]; then
    echo -e "${YELLOW}⚠️  Only $DAYS_SINCE days since cutover${NC}"
    echo "Need to wait $((30 - DAYS_SINCE)) more days before Phase I"
    echo ""
  fi

  # Run checks
  cd "$CONFIG_ROOT"

  echo "Running verification checks..."
  echo ""

  # Test decryption
  echo -n "Decryption test: "
  if sops -d "nixos/workstation/$HOSTNAME/secrets.yaml" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗ FAILED${NC}"
    exit 1
  fi

  # Check services
  echo -n "System uptime: "
  uptime | awk '{print $3" "$4}'

  echo -n "Secret access: "
  if [[ -f ~/.config/claude-code/.bearer_token ]]; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${YELLOW}⚠${NC}"
  fi

  echo ""
  if [[ $DAYS_SINCE -ge 30 ]]; then
    echo -e "${GREEN}✓ 30-day safety period complete${NC}"
    echo ""
    echo "You may proceed to Phase I to remove the old key."
    echo ""
    echo "Run: './host-key-rotation-helper.sh I'"
  else
    echo "Continue monitoring. Run this check regularly."
    echo ""
    echo "Recommended check schedule:"
    echo "  Day 7:  $(date -d "$CUTOVER_DATE + 7 days" +%Y-%m-%d 2>/dev/null || echo "unknown")"
    echo "  Day 14: $(date -d "$CUTOVER_DATE + 14 days" +%Y-%m-%d 2>/dev/null || echo "unknown")"
    echo "  Day 21: $(date -d "$CUTOVER_DATE + 21 days" +%Y-%m-%d 2>/dev/null || echo "unknown")"
    echo "  Day 30: $(date -d "$CUTOVER_DATE + 30 days" +%Y-%m-%d 2>/dev/null || echo "unknown")"
  fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE I: Remove Old Key
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

elif [[ "$PHASE" == "I" ]]; then
  echo -e "${BLUE}Phase I: Remove Old Key${NC}"
  echo ""
  echo -e "${RED}⚠️  OLD KEY WILL BE REVOKED${NC}"
  echo ""

  # Check Phase G complete
  if [[ -z "$(load_state "PHASE_G_COMPLETE")" ]]; then
    echo -e "${RED}✗ Phase G not complete. Run Phase G first.${NC}"
    exit 1
  fi

  # Check 30 days passed
  CUTOVER_DATE=$(load_state "CUTOVER_DATE")
  DAYS_SINCE=$(( ($(date +%s) - $(date -d "$CUTOVER_DATE" +%s 2>/dev/null || echo 0)) / 86400 ))

  if [[ $DAYS_SINCE -lt 30 ]]; then
    echo -e "${RED}✗ Only $DAYS_SINCE days since cutover${NC}"
    echo "Must wait 30 days. Do not skip the safety period."
    exit 1
  fi

  echo "30-day safety period complete."
  echo ""
  echo "This will:"
  echo "  1. Remove old age key from .sops.yaml"
  echo "  2. Re-encrypt all secrets (revokes old key)"
  echo "  3. Archive old host key"
  echo ""
  read -p "Proceed? (type 'REMOVE'): " confirm
  if [[ "$confirm" != "REMOVE" ]]; then
    echo "Aborted."
    exit 1
  fi

  cd "$CONFIG_ROOT"

  # Backup .sops.yaml
  cp .sops.yaml .sops.yaml.before-removal

  AGE_KEY_OLD=$(load_state "AGE_KEY_OLD")
  AGE_KEY_NEW=$(load_state "AGE_KEY_NEW")

  echo ""
  echo "Edit .sops.yaml to remove old key..."
  echo "  Remove: $AGE_KEY_OLD"
  echo "  Keep:   $AGE_KEY_NEW (rename to base name)"
  echo ""
  read -p "Open .sops.yaml for editing? (yes/no): " confirm

  if [[ "$confirm" == "yes" ]]; then
    ${EDITOR:-nano} .sops.yaml
  fi

  # Re-encrypt to revoke old key
  echo ""
  echo "Re-encrypting secrets to revoke old key..."

  FAILED=0
  for file in $(find . -name "secrets.yaml" -type f); do
    echo "Revoking old key from: $file"
    if sops updatekeys "$file"; then
      if sops -d "$file" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} $file"
      else
        echo "  ${RED}✗${NC} $file - DECRYPTION FAILED"
        ((FAILED++))
      fi
    else
      echo "  ${RED}✗${NC} $file - UPDATE FAILED"
      ((FAILED++))
    fi
  done

  if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}✗ Re-encryption failed${NC}"
    echo ""
    echo "ROLLBACK:"
    echo "  cp .sops.yaml.before-removal .sops.yaml"
    exit 1
  fi

  echo ""
  echo -e "${GREEN}✓ All secrets re-encrypted (old key revoked)${NC}"

  # Archive old host key
  echo ""
  echo "Archiving old host key..."
  sudo tar -czf /root/old-host-key-$(date +%Y%m%d).tar.gz \
    /etc/ssh/ssh_host_ed25519_key.OLD \
    /etc/ssh/ssh_host_ed25519_key.OLD.pub

  echo -e "${GREEN}✓ Old key archived to /root/old-host-key-$(date +%Y%m%d).tar.gz${NC}"
  echo "  Keep this file for 90 days minimum"

  # Commit
  echo ""
  read -p "Commit changes? (yes/no): " confirm
  if [[ "$confirm" == "yes" ]]; then
    git add .
    git commit -m "feat(security): complete host key rotation for $HOSTNAME

Old age key revoked: $AGE_KEY_OLD
New age key active: $AGE_KEY_NEW

30-day verification period completed successfully.
Old key archived."

    echo -e "${GREEN}✓ Committed to git${NC}"
  fi

  save_state "PHASE_I_COMPLETE" "$(date -Iseconds)"

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ HOST KEY ROTATION COMPLETE${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Summary:"
  echo "  Old key: $(load_state "OLD_KEY_FINGERPRINT")"
  echo "  New key: $(load_state "NEW_KEY_FINGERPRINT")"
  echo "  Cutover: $CUTOVER_DATE"
  echo "  Complete: $(date -Iseconds)"
  echo ""
  echo "Post-rotation tasks:"
  echo "  [ ] Update rotation_history.yaml"
  echo "  [ ] Schedule next rotation (1 year from now)"
  echo "  [ ] Update SSH clients' known_hosts"
  echo "  [ ] Document any issues encountered"

else
  echo "Unknown phase: $PHASE"
  exit 1
fi
