# Phase 2: Meh Pilot Migration - Deployment Guide

This guide covers the deployment steps for migrating meh from 1Password SSH agent to filesystem-owned SSH keys with automated rotation.

## Status: Ready for Deployment

✅ Keys generated
✅ Configuration updated
✅ 1Password agent references removed

## What Has Been Done

### 1. SSH Keys Generated

**Location:** `~/.ssh/`

- Auth key: `id_auth_ed25519_new`
  - Fingerprint: `SHA256:rS3gvApAkf8d3xw5QPmFMXLHdIioS5Un4cCBbz3nBQk`
  - Public: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIH57HkgLJYRhgkZGBs+/LBmiBrZtIr08INS2zQkEJoS`

- Signing key: `id_signing_ed25519_new`
  - Fingerprint: `SHA256:gm+rTenCKo2d+1Hinntjd76AJ7m+0f2KkBl9QzQifDA`
  - Public: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuaVJD7BbkXTN0dYCT6HURZZ8kGS/WbmS+nd+B8KtMY`

### 2. Configuration Updates

**Modified files:**
- `home-manager/_mixins/users/gburd/hosts/meh.nix`
  - Added ssh-management module import
  - Added sops secrets for ssh-keys/auth and ssh-keys/signing
  - Enabled ssh-management service with quarterly rotation
  - Removed manual git signing configuration (now handled by module)

- `home-manager/_mixins/users/gburd/default.nix`
  - Removed `SSH_AUTH_SOCK = "$HOME/.1password/agent.sock"`
  - Removed 1Password directory creation
  - Removed `identityAgent = "~/.1password/agent.sock"` from SSH config

- `home-manager/_mixins/cli/ssh.nix`
  - Removed 1Password agent socket forwarding from meh remote forwards

### 3. Helper Scripts Created

- `scripts/ssh-key-rotation/manual-add-keys-to-sops.sh`
  - Interactive script to add generated keys to sops secrets

## Deployment Steps

### Step 1: Add Keys to Sops Secrets

The generated SSH keys need to be added to the encrypted secrets file.

```bash
cd ~/ws/nix-config
./scripts/ssh-key-rotation/manual-add-keys-to-sops.sh
```

This script will:
1. Decrypt the existing secrets file
2. Add the `ssh-keys` section with auth and signing keys
3. Add metadata (fingerprints, creation dates, rotation dates)
4. Re-encrypt the secrets file

**Troubleshooting:**
If sops decryption fails, you may need to:
- Import your PGP key: `gpg --import ~/.gnupg/private-key.asc`
- Or set age key file: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`
- Or ensure `~/.ssh/id_ed25519` exists (used to derive age key)

### Step 2: Verify Secrets File

```bash
cd ~/ws/nix-config
sops -d nixos/workstation/meh/secrets.yaml | grep -A 10 "ssh-keys"
```

You should see:
```yaml
ssh-keys:
  auth: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
  auth-metadata:
    fingerprint: SHA256:rS3gvApAkf8d3xw5QPmFMXLHdIioS5Un4cCBbz3nBQk
    ...
  signing: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
  signing-metadata:
    fingerprint: SHA256:gm+rTenCKo2d+1Hinntjd76AJ7m+0f2KkBl9QzQifDA
    ...
```

### Step 3: Commit Changes

```bash
cd ~/ws/nix-config
git status
git add nixos/workstation/meh/secrets.yaml
git add home-manager/_mixins/users/gburd/hosts/meh.nix
git add home-manager/_mixins/users/gburd/default.nix
git add home-manager/_mixins/cli/ssh.nix

git commit -m "feat(security): migrate meh to filesystem-owned SSH keys

- Add ssh-management module for meh
- Generate new auth and signing keys (ed25519)
- Remove 1Password SSH agent dependency
- Configure quarterly key rotation
- Enable 1Password sync for backup

This is the Phase 2 pilot migration. Once verified on meh, will roll out
to other hosts (floki, arnold, darwin).

Auth key fingerprint: SHA256:rS3gvApAkf8d3xw5QPmFMXLHdIioS5Un4cCBbz3nBQk
Signing key fingerprint: SHA256:gm+rTenCKo2d+1Hinntjd76AJ7m+0f2KkBl9QzQifDA"
```

### Step 4: Deploy with Home-Manager

```bash
cd ~/ws/nix-config
home-manager switch --flake .#meh
```

**Expected output:**
- ✓ Authentication key deployed to ~/.ssh/id_auth_ed25519
- ✓ Signing key deployed to ~/.ssh/id_signing_ed25519
- ✓ Git SSH signing configured
- ✓ SSH agent service started
- ✓ Key age check timer enabled

**Watch for warnings:**
- If SSH_AUTH_SOCK points to 1Password, you'll see a warning (expected on first deploy)
- Log out and log back in to get the new ssh-agent environment

### Step 5: Log Out and Back In

The SSH agent environment variable needs to be refreshed:

```bash
# Option 1: Full logout/login (recommended)
logout

# Option 2: Start new shell session
exec bash  # or your shell
```

### Step 6: Verify SSH Agent

```bash
echo $SSH_AUTH_SOCK
# Should show: /tmp/ssh-XXX/agent.XXX (NOT ~/.1password/agent.sock)

ssh-add -l
# Should list: id_auth_ed25519 and id_signing_ed25519
```

### Step 7: Test SSH Authentication

```bash
# Test GitHub
ssh -T git@github.com
# Expected: "Hi gburd! You've successfully authenticated..."

# Test Codeberg (if configured)
ssh -T git@codeberg.org
# Expected: "Hi there, gburd!"
```

### Step 8: Test Git Signing

```bash
cd ~/ws/nix-config

# Create test commit
git commit --allow-empty -S -m "test: verify SSH signing works"

# Verify signature
git verify-commit HEAD
# Expected: Good "git" signature with ssh-ed25519 key

# Check signature details
git show --show-signature HEAD
# Should show signing key fingerprint

# Remove test commit
git reset --soft HEAD~1
```

### Step 9: Update Git Hosting Services

Add the new keys to GitHub and Codeberg:

```bash
cd ~/ws/nix-config

# Ensure gh CLI is authenticated
gh auth status

# Add keys to GitHub
gh ssh-key add ~/.ssh/id_auth_ed25519.pub \
  --title "meh-auth-202604" \
  --type authentication

gh ssh-key add ~/.ssh/id_signing_ed25519.pub \
  --title "meh-signing-202604" \
  --type signing

# Verify keys were added
gh ssh-key list | grep meh

# Optional: Codeberg (if tea CLI is configured)
# tea ssh-keys add --title "meh-auth-202604" ~/.ssh/id_auth_ed25519.pub
# tea ssh-keys add --title "meh-signing-202604" ~/.ssh/id_signing_ed25519.pub
```

### Step 10: Sync to 1Password

Backup the keys to 1Password for recovery:

```bash
# Ensure 1Password CLI is authenticated
op account list

# If not authenticated:
eval $(op signin)

# Sync keys to 1Password
~/.local/bin/ssh-sync-to-1password

# Or use the combined script:
~/.local/bin/ssh-sync-1password to
```

### Step 11: Test sops Decryption

Verify that sops-nix can still decrypt secrets:

```bash
# Test a known secret
cat ~/.config/claude-code/.bearer_token
# Should output your token (not an error)

# Try decrypting secrets directly
sops -d ~/ws/nix-config/nixos/workstation/meh/secrets.yaml | head -20
# Should show decrypted secrets
```

### Step 12: Verify Rotation Monitoring

Check that systemd timers are active:

```bash
# Check timer status
systemctl --user status ssh-key-rotation-check.timer

# Check when it will run next
systemctl --user list-timers ssh-key-rotation-check.timer

# Manually trigger check (should report keys are new)
~/.local/bin/ssh-check-rotation
```

### Step 13: Remove Old 1Password Keys (Optional)

If you have old SSH keys in 1Password that are no longer needed:

```bash
# List SSH keys in 1Password
op item list --categories "SSH Key"

# Identify and remove old keys
op item delete "old-key-name"
```

## Verification Checklist

- [ ] SSH keys deployed to ~/.ssh/ with correct permissions
- [ ] SSH_AUTH_SOCK no longer points to 1Password
- [ ] ssh-add -l shows both keys
- [ ] GitHub SSH authentication works
- [ ] Git commit signing works
- [ ] Git signature verification works
- [ ] Keys added to GitHub/Codeberg
- [ ] Keys backed up to 1Password
- [ ] sops decryption still works
- [ ] Systemd rotation timer is active
- [ ] No warnings in home-manager activation

## Rollback Procedure (If Needed)

If something goes wrong:

```bash
cd ~/ws/nix-config

# Revert commits
git log --oneline | head -5
git revert <commit-sha>

# Rebuild home-manager
home-manager switch --flake .#meh

# This will:
# - Restore 1Password SSH agent configuration
# - Remove ssh-management module
# - Restore manual git signing configuration

# Then log out and back in
```

## Post-Deployment

Once everything is verified:

1. **Update rotation_history.yaml:**
   ```bash
   cd ~/ws/nix-config
   cat >> secrets/ssh-keys/rotation_history.yaml <<EOF
   - date: "$(date -Iseconds)"
     hostname: meh
     key_type: auth
     action: initial_deployment
     fingerprint: "SHA256:rS3gvApAkf8d3xw5QPmFMXLHdIioS5Un4cCBbz3nBQk"
     emergency: false
     notes: "Phase 2 pilot migration - initial SSH key deployment"

   - date: "$(date -Iseconds)"
     hostname: meh
     key_type: signing
     action: initial_deployment
     fingerprint: "SHA256:gm+rTenCKo2d+1Hinntjd76AJ7m+0f2KkBl9QzQifDA"
     emergency: false
     notes: "Phase 2 pilot migration - initial SSH key deployment"

   EOF

   git add secrets/ssh-keys/rotation_history.yaml
   git commit -m "docs(security): log initial SSH key deployment for meh"
   ```

2. **Document any issues encountered** for the rollout to other hosts

3. **Wait at least 24 hours** to ensure no issues before proceeding to Phase 3

## Next Steps (Phase 3)

After successful verification on meh:
1. Roll out to floki (convert from GPG to SSH signing)
2. Roll out to arnold (convert from GPG to SSH signing)
3. Roll out to darwin (convert from GPG to SSH signing, macOS keychain)

## Troubleshooting

### Issue: sops decryption fails during deployment

**Symptoms:** Home-manager fails to activate, can't decrypt secrets

**Solution:**
```bash
# Check which keys can decrypt
sops -d ~/ws/nix-config/nixos/workstation/meh/secrets.yaml

# Verify age key derivation
ssh-to-age < ~/.ssh/id_ed25519.pub

# Check if it matches .sops.yaml
grep -A 5 "meh" ~/.sops.yaml
```

### Issue: SSH agent shows 1Password socket

**Symptoms:** `echo $SSH_AUTH_SOCK` shows ~/.1password/agent.sock

**Solution:**
Log out completely and log back in. The environment variable is set at login.

### Issue: Git signing fails

**Symptoms:** `git commit -S` fails with "signing failed"

**Solution:**
```bash
# Check signing key is configured
git config --get gpg.ssh.format
git config --get user.signingkey

# Check allowed_signers file
cat ~/.ssh/allowed_signers

# Test signing directly
echo "test" | ssh-keygen -Y sign -n git -f ~/.ssh/id_signing_ed25519
```

### Issue: Keys not added to ssh-agent

**Symptoms:** `ssh-add -l` shows "The agent has no identities"

**Solution:**
```bash
# Manually add keys
ssh-add ~/.ssh/id_auth_ed25519
ssh-add ~/.ssh/id_signing_ed25519

# Check if ssh-agent is running
systemctl --user status ssh-agent
```

## Success Criteria

Phase 2 is successful when:
1. ✅ All SSH authentication works without 1Password agent
2. ✅ Git signing works with new SSH signing key
3. ✅ sops-nix decryption continues to work
4. ✅ Keys are backed up to 1Password
5. ✅ Rotation monitoring is active
6. ✅ No errors in home-manager activation
7. ✅ System stable for 24+ hours

Once these criteria are met, proceed to Phase 3 (rollout to other hosts).
