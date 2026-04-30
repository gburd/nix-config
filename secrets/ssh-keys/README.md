# SSH Keys Secret Management

This directory contains documentation and history for SSH key management with sops-nix.

## Directory Structure

```
secrets/ssh-keys/
├── README.md                  # This file
├── rotation_history.yaml      # Audit log of all rotations
└── hosts/                     # Per-host key storage (reference)
    ├── meh/
    ├── floki/
    ├── arnold/
    └── darwin/
```

## Secrets File Structure

SSH keys are stored in host-specific secrets files:
- `nixos/workstation/meh/secrets.yaml`
- `nixos/workstation/floki/secrets.yaml`
- etc.

### YAML Structure for SSH Keys

Each host's `secrets.yaml` should contain:

```yaml
# Authentication key (SSH connections)
ssh-keys:
  auth: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    [encrypted private key content]
    -----END OPENSSH PRIVATE KEY-----

  auth-metadata:
    fingerprint: "SHA256:..."
    created: "2026-04-30T12:00:00Z"
    public_key: "ssh-ed25519 AAAAC3Nza..."
    rotation_due: "2026-07-30"

  # Signing key (git commits/tags)
  signing: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    [encrypted private key content]
    -----END OPENSSH PRIVATE KEY-----

  signing-metadata:
    fingerprint: "SHA256:..."
    created: "2026-04-30T12:00:00Z"
    public_key: "ssh-ed25519 AAAAC3Nza..."
    rotation_due: "2026-07-30"
```

### During Rotation (Dual-Key Period)

When rotating keys, both old and new keys are present:

```yaml
ssh-keys:
  # Old key (still active)
  auth: |
    [old key content]
  auth-metadata:
    fingerprint: "SHA256:old..."
    created: "2026-01-30T12:00:00Z"

  # New key (dual-key period)
  auth-new: |
    [new key content]
  auth-new-metadata:
    fingerprint: "SHA256:new..."
    created: "2026-04-30T12:00:00Z"
    rotation_state: "dual-key-period"
    cutover_date: "2026-05-07"  # 7 days after generation
```

After the dual-key period (7 days):
1. New key is renamed to primary (`auth-new` → `auth`)
2. Old key is removed
3. Commit and deploy changes

## .sops.yaml Configuration

The `.sops.yaml` file controls encryption. For SSH key secrets:

```yaml
keys:
  # User age keys (for home-manager secrets)
  - &user-keys:
    - &gburd-user age1u09jlepa0p8ul5rghgrg8n2f3ry2z7t4tnmlggsz4e2u4h7lyvmszy53hd

  # Host age keys (derived from SSH host keys)
  - &hosts:
    - &meh age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
    - &floki age1z2x0g05q2erpux006vwhul70d8akj9avrj67s9p27fm4ce32ly8qt8nllz

creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh
      - *gburd-user
```

### Dual-Key Support for Host Key Rotation

During host key rotation, add BOTH old and new age keys:

```yaml
keys:
  - &hosts:
    - &meh-old age150z9ve3g9zkue9rgmchh6gtgc8x8x5lrz7lhyq5n7l8992e8keqqt03yzw
    - &meh-new age1abc123...  # NEW KEY ADDED

creation_rules:
  - path_regex: nixos/workstation/meh/secrets.ya?ml$
    key_groups:
    - age:
      - *meh-old   # Old key can still decrypt
      - *meh-new   # New key can also decrypt
      - *gburd-user
```

After 30 days of verification, remove the old key and re-encrypt secrets.

## Accessing Secrets in Nix Configuration

### home-manager Configuration

```nix
# In hosts/meh.nix or similar
sops = {
  defaultSopsFile = "${inputs.self}/nixos/workstation/meh/secrets.yaml";
  age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

  secrets = {
    "ssh-keys/auth" = {
      path = "${config.home.homeDirectory}/.ssh/id_auth_ed25519";
    };
    "ssh-keys/signing" = {
      path = "${config.home.homeDirectory}/.ssh/id_signing_ed25519";
    };
  };
};
```

### Using ssh-management Module

```nix
services.ssh-management = {
  enable = true;

  authKey = {
    secret = config.sops.secrets."ssh-keys/auth".path;
    publicKey = "ssh-ed25519 AAAAC3Nza...";
  };

  signingKey = {
    secret = config.sops.secrets."ssh-keys/signing".path;
    publicKey = "ssh-ed25519 AAAAC3Nza...";
  };

  rotationInterval = "quarterly";
  sync1Password = true;
};
```

## Key Rotation Workflow

See `scripts/ssh-key-rotation/rotate.sh` for the automated rotation workflow.

### Manual Steps

1. **Generate new key**
   ```bash
   cd ~/ws/nix-config
   ./scripts/ssh-key-rotation/generate-keys.sh auth
   ```

2. **Encrypt with sops**
   ```bash
   ./scripts/ssh-key-rotation/sops-rekey.sh auth add
   ```

3. **Commit to git**
   ```bash
   git add nixos/workstation/meh/secrets.yaml
   git commit -m "feat(security): add new auth key for rotation"
   ```

4. **Deploy**
   ```bash
   home-manager switch
   ```

5. **Test dual-key period** (7 days)
   ```bash
   ssh -i ~/.ssh/id_auth_ed25519 -T git@github.com      # Old key
   ssh -i ~/.ssh/id_auth_ed25519_new -T git@github.com  # New key
   ```

6. **Cutover** (after 7 days)
   ```bash
   ./scripts/ssh-key-rotation/cutover.sh auth
   ```

7. **Remove old key** (after verification)
   ```bash
   ./scripts/ssh-key-rotation/sops-rekey.sh auth remove
   ```

## Security Considerations

### Encryption

- All private keys are encrypted with sops
- Multiple decryption keys (host + user age keys)
- Keys are never stored unencrypted in git

### Rotation Policy

- **Auth keys**: Rotate quarterly (90 days)
- **Signing keys**: Rotate quarterly (90 days)
- **Host keys**: Rotate annually (365 days) - CRITICAL, affects sops-nix

### Dual-Key Period

- New keys are added alongside old keys
- Both keys remain active for 7 days
- Provides time to test new keys before removing old ones
- Allows rollback if issues are discovered

### Host Key Rotation Special Case

Host key rotation is complex because:
1. Host keys derive age keys for sops-nix
2. Rotating without dual-key period will lose access to secrets
3. Must maintain both old and new age keys during transition
4. Requires careful testing before removing old key

**Always follow the 9-phase host key rotation procedure** documented in the plan.

## Audit Trail

All key rotations are logged in `rotation_history.yaml`:

```yaml
- date: "2026-04-30T12:00:00Z"
  hostname: meh
  key_type: auth
  action: generated_new_key
  fingerprint: "SHA256:..."
  emergency: false

- date: "2026-05-07T12:00:00Z"
  hostname: meh
  key_type: auth
  action: cutover_to_new_key
  old_fingerprint: "SHA256:old..."
  new_fingerprint: "SHA256:new..."
```

This provides complete history of all key changes for security auditing.

## Emergency Rotation

If a key is compromised:

```bash
./scripts/ssh-key-rotation/rotate.sh auth --emergency --force
```

This performs immediate rotation:
- Skips dual-key period
- Immediately revokes old key from git hosting services
- Updates all secrets immediately

Use only when a key has been compromised.

## Backup and Recovery

### Backups

Keys are backed up in two places:
1. **Git repository** (sops-encrypted)
2. **1Password vault** (if sync enabled)

### Recovery from 1Password

If you lose local keys but have them in 1Password:

```bash
eval $(op signin)
~/.local/bin/ssh-sync-from-1password
```

Or using the script:

```bash
./scripts/ssh-key-rotation/sync-1password.sh both pull
```

### Recovery from Git

If you have access to another host that can decrypt sops:

```bash
# On working host
sops -d nixos/workstation/meh/secrets.yaml | yq '.ssh-keys.auth' > /tmp/auth_key
scp /tmp/auth_key meh:~/.ssh/id_auth_ed25519
shred -u /tmp/auth_key

# On meh
chmod 600 ~/.ssh/id_auth_ed25519
ssh-add ~/.ssh/id_auth_ed25519
```

## Best Practices

1. **Always use the rotation scripts** - Don't manually rotate keys
2. **Test in dry-run mode first** - `--dry-run` flag available on all scripts
3. **Respect the dual-key period** - Don't rush cutover, use the full 7 days
4. **Log everything** - rotation_history.yaml is your audit trail
5. **Backup before host key rotation** - Host key rotation is high-risk
6. **Verify sops decryption** - After any host key changes, verify secrets decrypt
7. **Keep 1Password in sync** - Defense in depth, multiple backup locations
8. **Never commit unencrypted keys** - Always use sops before committing
9. **Monitor key age** - Systemd timers notify when rotation is due
10. **Document exceptions** - If you skip rotation, document why

## Troubleshooting

### Cannot decrypt secrets

```bash
# Check which age keys are configured
cat .sops.yaml | grep -A 10 "meh"

# Verify age key derivation from SSH host key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Test decryption
sops -d nixos/workstation/meh/secrets.yaml
```

### Key rotation failed

```bash
# Check git status
git status

# Revert recent commits
git log --oneline | head -5
git revert <commit-sha>

# Re-run validation
./scripts/ssh-key-rotation/validate.sh auth
```

### Lost access to secrets

1. Check if 1Password has backup
2. Check git history for previous keys
3. As last resort, regenerate all keys and re-encrypt all secrets

## References

- sops-nix documentation: https://github.com/Mic92/sops-nix
- SSH key types: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
- Age encryption: https://github.com/FiloSottile/age
