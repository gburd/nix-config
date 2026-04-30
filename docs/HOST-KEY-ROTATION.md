# Host Key Rotation Procedure

## ⚠️ CRITICAL WARNING

**Host key rotation is the most dangerous SSH key operation.** Host keys derive the age encryption keys used by sops-nix to decrypt ALL secrets. Incorrect rotation will result in **permanent loss of access to all encrypted secrets**.

**Read this entire document before proceeding.**

## What Are Host Keys?

Host keys serve two critical purposes:

1. **SSH Daemon Identity**: Identifies the host to SSH clients
2. **sops-nix Encryption**: Derives age keys for encrypting/decrypting secrets

The age key derivation is: `SSH host key → age public key → encrypts sops secrets`

**Example:**
```bash
# SSH host key
/etc/ssh/ssh_host_ed25519_key.pub

# Derives to age key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# → age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
```

This age key is in `.sops.yaml` and encrypts all secrets for that host.

## Why Rotate Host Keys?

**Reasons to rotate:**
- Annual security policy (recommended)
- Key compromise (immediate rotation required)
- Cryptographic best practices
- Compliance requirements

**Risks of rotation:**
- Lose access to all encrypted secrets if done incorrectly
- Services fail to start due to missing secrets
- Cannot deploy new configurations
- Requires system reinstall to recover if backups unavailable

**Rotation frequency:** Annually (365 days) or on compromise

## Prerequisites

Before starting host key rotation, ensure:

- [ ] Full backup of all secrets exists
- [ ] Alternative access to secrets (1Password, GPG-encrypted backups)
- [ ] Current host key is working and can decrypt secrets
- [ ] You understand the 9-phase process
- [ ] You have at least 2 hours of uninterrupted time
- [ ] System is stable with no pending updates
- [ ] You can afford 30+ days of dual-key period

## The 9-Phase Rotation Process

### Overview

```
Phase A: Generate new host key
Phase B: Derive new age key
Phase C: Add new age key to .sops.yaml (DUAL-KEY BEGINS)
Phase D: Re-encrypt ALL secrets with both keys
Phase E: Deploy and verify decryption works
Phase F: Cutover to new host key
Phase G: Verify decryption STILL works
Phase H: Wait 30 days (safety period)
Phase I: Remove old age key and re-encrypt (ROTATION COMPLETE)
```

**Critical:** Phases C-G maintain BOTH old and new keys. Never remove the old key until Phase I.

---

## Phase A: Generate New Host Key

**Time:** 5 minutes
**Risk:** Low (no changes to production yet)

### A.1: Generate the Key

```bash
# Generate new host key
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key_NEW -C "root@$(hostname)-$(date +%Y%m)" -N ""

# Set proper permissions
sudo chmod 600 /etc/ssh/ssh_host_ed25519_key_NEW
sudo chmod 644 /etc/ssh/ssh_host_ed25519_key_NEW.pub

# Display fingerprint
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key_NEW
```

**Record:**
- New key fingerprint: ______________________
- Generation date: ______________________

### A.2: Backup Old Key

```bash
# Create backup of current key
sudo cp /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.OLD
sudo cp /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.OLD.pub

# Store fingerprint of old key
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.OLD
```

**Record:**
- Old key fingerprint: ______________________

---

## Phase B: Derive New Age Key

**Time:** 2 minutes
**Risk:** Low (read-only operation)

### B.1: Derive Age Key

```bash
# Install ssh-to-age if not present
nix-shell -p ssh-to-age

# Derive age key from NEW host key
AGE_KEY_NEW=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key_NEW.pub)
echo "New age key: $AGE_KEY_NEW"

# Derive age key from OLD host key (for comparison)
AGE_KEY_OLD=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
echo "Old age key: $AGE_KEY_OLD"
```

**Record:**
- New age key: ______________________
- Old age key: ______________________

### B.2: Verify Age Keys Match .sops.yaml

```bash
cd ~/ws/nix-config

# Check current age key in .sops.yaml
grep -A 10 "$(hostname)" .sops.yaml

# The old age key should match what's in .sops.yaml
```

**Verify:** Old age key matches the one in `.sops.yaml`

---

## Phase C: Add New Age Key to .sops.yaml

**Time:** 5 minutes
**Risk:** Low (additive change)
**⚠️ DUAL-KEY PERIOD BEGINS**

### C.1: Update .sops.yaml

Edit `.sops.yaml` to include BOTH age keys:

```bash
cd ~/ws/nix-config
cp .sops.yaml .sops.yaml.backup

# Edit .sops.yaml manually
```

**Before:**
```yaml
keys:
  - &hosts:
    - &meh age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
```

**After:**
```yaml
keys:
  - &hosts:
    - &meh-old age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
    - &meh-new age1abc123... # NEW KEY ADDED - from Phase B
```

### C.2: Update Creation Rules

Update the creation rules to use BOTH keys:

**Before:**
```yaml
creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh
      - *gburd-user
```

**After:**
```yaml
creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh-old  # Old key can still decrypt
      - *meh-new  # New key can also decrypt
      - *gburd-user
```

### C.3: Verify Syntax

```bash
# Verify YAML is valid
yq eval . .sops.yaml > /dev/null && echo "✓ Valid YAML" || echo "✗ Syntax error"
```

### C.4: Commit Changes

```bash
git add .sops.yaml
git commit -m "feat(security): add new age key for $(hostname) (dual-key period)

Old age key: $AGE_KEY_OLD
New age key: $AGE_KEY_NEW

This begins the dual-key period. Both keys can decrypt secrets.
Old key will be removed after 30-day verification period."
```

---

## Phase D: Re-encrypt ALL Secrets with Both Keys

**Time:** 10-15 minutes
**Risk:** MEDIUM (wrong keys will lock you out)
**⚠️ CRITICAL PHASE**

### D.1: Verify Current Decryption Works

**STOP:** Before re-encrypting, verify you can currently decrypt:

```bash
cd ~/ws/nix-config

# Test decryption with OLD key
sops -d nixos/workstation/$(hostname)/secrets.yaml | head -10

# If this fails, DO NOT PROCEED
```

### D.2: Re-encrypt Secrets

Re-encrypt ALL secrets files to include the new age key:

```bash
cd ~/ws/nix-config

# Find all secrets files
find . -name "secrets.yaml" -type f

# Update keys for each file
for file in $(find . -name "secrets.yaml" -type f); do
    echo "Re-encrypting: $file"
    sops updatekeys "$file"

    # Verify re-encryption worked
    if sops -d "$file" >/dev/null 2>&1; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - DECRYPTION FAILED"
        echo "ABORT: Re-encryption failed. Do not proceed."
        exit 1
    fi
done
```

### D.3: Verify Both Keys Can Decrypt

**CRITICAL TEST:** Both old and new age keys should decrypt secrets.

We can't easily test the new key yet (since we haven't activated it), but we can verify the re-encryption metadata:

```bash
# Check that secrets metadata includes both age keys
sops -d nixos/workstation/$(hostname)/secrets.yaml 2>&1 | grep -i "age"

# The file should be encrypted to both keys
```

### D.4: Commit Re-encrypted Secrets

```bash
cd ~/ws/nix-config

git add .
git commit -m "chore(security): re-encrypt secrets with dual age keys for $(hostname)

All secrets now encrypted with both old and new age keys.
This enables safe host key rotation.

Old host key can decrypt: yes
New host key can decrypt: yes (not yet tested, will verify in Phase E)"
```

---

## Phase E: Deploy and Verify Decryption Works

**Time:** 15 minutes
**Risk:** MEDIUM (service disruption if failed)
**⚠️ CRITICAL VERIFICATION PHASE**

### E.1: Deploy Configuration

Push changes to the host:

```bash
cd ~/ws/nix-config
git push

# On the target host (or via SSH):
cd ~/ws/nix-config
git pull
nixos-rebuild switch --flake .#$(hostname)
```

### E.2: Verify Current Secrets Still Work

**CRITICAL:** Ensure services using secrets are still running:

```bash
# Check system secrets are accessible (vary by host)
# For meh:
cat ~/.config/claude-code/.bearer_token
cat ~/.config/JetBrains/clion.key

# Check services that use secrets
systemctl status protonmail-bridge
systemctl status vdirsyncer

# All should be running normally
```

### E.3: Test sops Decryption

```bash
cd ~/ws/nix-config

# Verify we can still decrypt with current (old) key
sops -d nixos/workstation/$(hostname)/secrets.yaml | head -20

# This MUST work - we haven't switched keys yet
```

**Record:** Date when Phase E completed successfully: ______________________

---

## Phase F: Cutover to New Host Key

**Time:** 5 minutes
**Risk:** HIGH (if decryption fails, services break)
**⚠️ POINT OF NO RETURN FOR SSH CLIENTS**

### F.1: Final Backup

```bash
# Backup entire /etc/ssh/ directory
sudo tar -czf /root/ssh-backup-$(date +%Y%m%d-%H%M%S).tar.gz /etc/ssh/

# Verify backup
sudo tar -tzf /root/ssh-backup-*.tar.gz | head -10
```

### F.2: Replace Host Key

```bash
# Stop SSH daemon (CAREFUL - do this at console, not over SSH!)
sudo systemctl stop sshd

# Replace the host key
sudo mv /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.OLD
sudo mv /etc/ssh/ssh_host_ed25519_key_NEW /etc/ssh/ssh_host_ed25519_key

sudo mv /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.OLD.pub
sudo mv /etc/ssh/ssh_host_ed25519_key_NEW.pub /etc/ssh/ssh_host_ed25519_key.pub

# Set permissions
sudo chmod 600 /etc/ssh/ssh_host_ed25519_key
sudo chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

# Restart SSH daemon
sudo systemctl start sshd
```

### F.3: Verify SSH Daemon

```bash
# Check SSH is running
sudo systemctl status sshd

# Display new host key fingerprint
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

# SSH clients will see "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"
# This is expected - host key has changed
```

**⚠️ SSH Clients Warning:**
All SSH clients will get a warning about host key change. This is EXPECTED and NORMAL. Users need to update their `~/.ssh/known_hosts`.

To update known_hosts on client machines:
```bash
ssh-keygen -R <hostname>
ssh <hostname>  # Accept new key
```

---

## Phase G: Verify Decryption STILL Works

**Time:** 10 minutes
**Risk:** HIGH (if this fails, secrets are inaccessible)
**⚠️ CRITICAL VERIFICATION AFTER CUTOVER**

### G.1: Verify Age Key Matches

```bash
# Derive age key from CURRENT (new) host key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# This should match the "meh-new" key from Phase B
# If it doesn't match, something went wrong
```

### G.2: Test sops Decryption

**CRITICAL TEST:**

```bash
cd ~/ws/nix-config

# This should work because secrets are encrypted to BOTH keys
sops -d nixos/workstation/$(hostname)/secrets.yaml | head -20

# If this fails, DO NOT REMOVE OLD KEY
# Rollback to Phase F and restore old key
```

### G.3: Verify Secrets are Accessible

```bash
# Test home-manager secrets
cat ~/.config/claude-code/.bearer_token

# Should output token (not error)
```

### G.4: Rebuild to Refresh Secrets

```bash
cd ~/ws/nix-config
nixos-rebuild switch --flake .#$(hostname)

# All services should start normally
# Check services that depend on secrets
systemctl status protonmail-bridge
```

**CHECKPOINT:**
- [ ] Age key matches meh-new from Phase B
- [ ] sops decryption works
- [ ] Home-manager secrets accessible
- [ ] All services running normally

If ALL checks pass, proceed to Phase H.
If ANY check fails, see Emergency Rollback section.

---

## Phase H: 30-Day Safety Period

**Time:** 30 days
**Risk:** Low (monitoring only)
**⚠️ DO NOT SKIP THIS PHASE**

### H.1: Monitor System

For the next 30 days:

- [ ] Check daily that secrets decrypt: `sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null`
- [ ] Verify services using secrets remain stable
- [ ] Test nixos-rebuild at least once per week
- [ ] Ensure no secret-related errors in logs

**Safety Calendar:**
- Cutover date (Phase F): ______________________
- Day 7 check: ______________________
- Day 14 check: ______________________
- Day 21 check: ______________________
- Day 30 check (proceed to Phase I): ______________________

### H.2: Keep Old Key Safe

**DO NOT DELETE:**
- `/etc/ssh/ssh_host_ed25519_key.OLD`
- `/etc/ssh/ssh_host_ed25519_key.OLD.pub`
- `meh-old` entry in `.sops.yaml`

These are your recovery path if issues arise.

### H.3: Document Issues

If any problems occur during the 30 days:
- Note the date and symptoms
- DO NOT remove old key
- Investigate root cause
- Consider extending safety period

---

## Phase I: Remove Old Key and Complete Rotation

**Time:** 15 minutes
**Risk:** Medium (old key removed, must verify new key works)
**⚠️ FINAL PHASE - OLD KEY WILL BE REVOKED**

### I.1: Final Verification

Before removing old key, verify 30-day period was successful:

```bash
# Verify current key works
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Should match meh-new from Phase B

# Test decryption
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null
echo $?  # Should output 0 (success)

# Check system has been stable
uptime
# Should show 30+ days uptime ideally
```

### I.2: Update .sops.yaml (Remove Old Key)

```bash
cd ~/ws/nix-config
cp .sops.yaml .sops.yaml.before-removal

# Edit .sops.yaml
```

**Before:**
```yaml
keys:
  - &hosts:
    - &meh-old age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
    - &meh-new age1abc123...
```

**After:**
```yaml
keys:
  - &hosts:
    - &meh age1abc123...  # Only new key remains, rename to remove "-new" suffix
```

Update creation rules:

**Before:**
```yaml
creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh-old
      - *meh-new
      - *gburd-user
```

**After:**
```yaml
creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh  # Only new key
      - *gburd-user
```

### I.3: Re-encrypt to Revoke Old Key

**CRITICAL:** This removes old key's ability to decrypt.

```bash
cd ~/ws/nix-config

# Re-encrypt all secrets (removes old key)
for file in $(find . -name "secrets.yaml" -type f); do
    echo "Revoking old key from: $file"
    sops updatekeys "$file"

    # Verify new key can still decrypt
    if sops -d "$file" >/dev/null 2>&1; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - DECRYPTION FAILED"
        echo "ABORT: Restore .sops.yaml.before-removal"
        cp .sops.yaml.before-removal .sops.yaml
        exit 1
    fi
done
```

### I.4: Verify Old Key Cannot Decrypt

**Safety check:** Confirm old key no longer works.

```bash
# Try to decrypt with old key (should fail)
# This is a theoretical test - in practice, the old key is not accessible

# Just verify current decryption works
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null && echo "✓ New key works"
```

### I.5: Archive Old Key

```bash
# Create encrypted archive of old key
sudo tar -czf /root/old-host-key-$(hostname)-$(date +%Y%m%d).tar.gz \
    /etc/ssh/ssh_host_ed25519_key.OLD \
    /etc/ssh/ssh_host_ed25519_key.OLD.pub

# Store in secure backup location
# DO NOT DELETE - keep for 90 days minimum

# Optionally encrypt with GPG
sudo gpg -e -r greg@burd.me /root/old-host-key-*.tar.gz
```

### I.6: Commit Final Changes

```bash
cd ~/ws/nix-config

git add .sops.yaml
git add .

git commit -m "feat(security): complete host key rotation for $(hostname)

Old age key revoked: $AGE_KEY_OLD
New age key active: $AGE_KEY_NEW

30-day verification period completed successfully.
Old key archived to /root/old-host-key-*.tar.gz

Rotation complete."
```

### I.7: Update Rotation History

```bash
cd ~/ws/nix-config

cat >> secrets/ssh-keys/rotation_history.yaml <<EOF
- date: "$(date -Iseconds)"
  hostname: $(hostname)
  key_type: host
  action: rotation_complete
  old_fingerprint: "$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.OLD | awk '{print $2}')"
  fingerprint: "$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key | awk '{print $2}')"
  emergency: false
  notes: "Annual host key rotation completed. 30-day verification passed. Old key revoked."

EOF

git add secrets/ssh-keys/rotation_history.yaml
git commit -m "docs(security): log host key rotation completion for $(hostname)"
```

**✅ ROTATION COMPLETE**

The old host key is now revoked. Only the new key can decrypt secrets.

---

## Emergency Rollback Procedures

### If Phase D Fails (Re-encryption Failed)

```bash
# Restore .sops.yaml backup
cd ~/ws/nix-config
cp .sops.yaml.backup .sops.yaml

# Remove bad commit
git reset --hard HEAD~1

# Old key still works, no damage done
```

### If Phase G Fails (New Key Can't Decrypt)

**CRITICAL: DO NOT REMOVE OLD KEY**

```bash
# Restore old host key
sudo systemctl stop sshd
sudo mv /etc/ssh/ssh_host_ed25519_key.OLD /etc/ssh/ssh_host_ed25519_key
sudo mv /etc/ssh/ssh_host_ed25519_key.OLD.pub /etc/ssh/ssh_host_ed25519_key.pub
sudo systemctl start sshd

# Verify old key works
sops -d nixos/workstation/$(hostname)/secrets.yaml | head -10

# If old key works, secrets are safe
# Investigate why new key failed before retrying
```

### If Phase I Fails (After Old Key Removed)

```bash
# Restore .sops.yaml before removal
cp .sops.yaml.before-removal .sops.yaml

# Re-encrypt to restore old key access
sops updatekeys nixos/workstation/$(hostname)/secrets.yaml

# Restore old host key
sudo cp /root/ssh-backup-*/etc/ssh/ssh_host_ed25519_key.OLD /etc/ssh/ssh_host_ed25519_key
sudo systemctl restart sshd
```

### Complete Disaster Recovery

If all else fails and you cannot decrypt secrets:

1. **Check 1Password Backup:**
   ```bash
   op item list --categories "SSH Key"
   # Restore secrets from 1Password
   ```

2. **Restore from git history:**
   ```bash
   git log --all -- nixos/workstation/*/secrets.yaml
   # Find commit where old key was still valid
   git checkout <commit> -- nixos/workstation/$(hostname)/secrets.yaml
   ```

3. **Nuclear option:**
   - Restore entire system from backup
   - Use backup that includes old host key
   - All secrets should decrypt with old key

---

## Post-Rotation Checklist

After completing Phase I:

- [ ] New host key active and working
- [ ] All secrets decrypt correctly
- [ ] All services using secrets running normally
- [ ] Old host key archived (90-day retention)
- [ ] `.sops.yaml` contains only new key
- [ ] Rotation logged in `rotation_history.yaml`
- [ ] Git commits pushed to remote
- [ ] SSH clients updated their `known_hosts`
- [ ] Documentation updated with new key fingerprint

---

## Rotation Schedule

Maintain a rotation schedule:

| Host   | Current Key Fingerprint | Last Rotated | Next Rotation Due |
|--------|-------------------------|--------------|-------------------|
| meh    | SHA256:...              | 2026-04-30   | 2027-04-30        |
| floki  | SHA256:...              | -            | -                 |
| arnold | SHA256:...              | -            | -                 |

Annual rotation recommended. Set calendar reminders 30 days before due date.

---

## Key Takeaways

1. **Never remove old key until 30+ days after cutover**
2. **Always maintain dual-key period during rotation**
3. **Test decryption at every phase**
4. **Keep multiple backups (old key, 1Password, git history)**
5. **Host key rotation is annual, not quarterly like user keys**
6. **Document everything - you'll need notes when troubleshooting**

---

## Additional Resources

- **sops documentation:** https://github.com/getsops/sops
- **age encryption:** https://github.com/FiloSottile/age
- **SSH key formats:** https://www.openssh.com/txt/release-6.5
- **Nix sops-nix module:** https://github.com/Mic92/sops-nix

---

## Change Log

| Date       | Version | Changes                                    |
|------------|---------|-------------------------------------------|
| 2026-04-30 | 1.0     | Initial documentation (Phase 5 complete)  |
