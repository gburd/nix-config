# SSH Key Management Documentation

This directory contains comprehensive documentation for SSH key management, rotation, and security practices used in this nix-config.

## Documentation Index

### 📘 Core Documentation

1. **[HOST-KEY-ROTATION.md](HOST-KEY-ROTATION.md)** ⚠️ CRITICAL
   - Complete 9-phase host key rotation procedure
   - Emergency rollback procedures
   - Safety checks and verification steps
   - **READ THIS BEFORE rotating host keys**
   - ~100 pages of detailed instructions

2. **[HOST-KEY-ROTATION-QUICK-REF.md](HOST-KEY-ROTATION-QUICK-REF.md)**
   - Quick reference card for host key rotation
   - Phase checklist
   - Quick commands for each phase
   - Emergency rollback commands
   - Use alongside full documentation

### 📁 Related Documentation

3. **[../secrets/ssh-keys/README.md](../secrets/ssh-keys/README.md)**
   - SSH keys secret management with sops
   - Directory structure
   - YAML structure for secrets
   - User key (auth/signing) rotation
   - Accessing secrets in Nix config

4. **[../PHASE2-DEPLOYMENT.md](../PHASE2-DEPLOYMENT.md)**
   - Meh pilot migration deployment guide
   - Step-by-step Phase 2 instructions
   - Verification checklist
   - Troubleshooting

## Scripts

### User Key Rotation (Auth/Signing)

Located in `scripts/ssh-key-rotation/`:

- `rotate.sh` - Main rotation orchestration
- `validate.sh` - Pre-rotation validation
- `generate-keys.sh` - Key generation
- `update-git-hosting.sh` - GitHub/Codeberg integration
- `sops-rekey.sh` - Sops encryption management
- `sync-1password.sh` - 1Password synchronization
- `manual-add-keys-to-sops.sh` - Interactive helper for adding keys

### Host Key Rotation

- `host-key-rotation-helper.sh` - Interactive 9-phase guide

## Quick Start

### For User Keys (Auth/Signing)

These rotate **quarterly** (90 days):

```bash
cd ~/ws/nix-config

# Validate before rotation
./scripts/ssh-key-rotation/validate.sh auth

# Rotate auth key (with dry-run)
./scripts/ssh-key-rotation/rotate.sh auth --dry-run
./scripts/ssh-key-rotation/rotate.sh auth

# Rotate signing key
./scripts/ssh-key-rotation/rotate.sh signing
```

### For Host Keys

These rotate **annually** (365 days):

⚠️ **DANGER:** Host keys affect sops-nix encryption. Read full docs first.

```bash
cd ~/ws/nix-config

# Interactive helper (recommended)
./scripts/ssh-key-rotation/host-key-rotation-helper.sh A  # Phase A

# Or follow manual procedures in HOST-KEY-ROTATION.md
```

## Key Types Summary

| Key Type | Location | Purpose | Rotation | Risk |
|----------|----------|---------|----------|------|
| **Auth** | `~/.ssh/id_auth_ed25519` | SSH connections | 90 days | Low |
| **Signing** | `~/.ssh/id_signing_ed25519` | Git commits | 90 days | Low |
| **Host** | `/etc/ssh/ssh_host_ed25519_key` | SSH daemon, sops-nix | 365 days | **HIGH** |

## When to Rotate

### Scheduled Rotation

- **User keys (auth/signing)**: Every 90 days
  - Systemd timer notifies at 80 days
  - Desktop notification when due

- **Host keys**: Every 365 days
  - Manual calendar reminder recommended
  - Set 30 days before due date

### Emergency Rotation

Rotate immediately if:
- Key compromised or suspected compromise
- Security incident
- Host reinstall (host keys only)
- Key accidentally published

Use `--emergency` flag:
```bash
./scripts/ssh-key-rotation/rotate.sh auth --emergency --force
```

## Safety Features

### Dual-Key Period

- **User keys**: 7 days
  - Both old and new keys active
  - Test new key before removing old
  - Easy rollback if issues

- **Host keys**: 30 days minimum
  - Both age keys can decrypt
  - Extensive verification required
  - Conservative approach for high-risk operation

### Validation

All rotation scripts include:
- Pre-rotation validation
- Post-rotation verification
- Automated rollback on failure
- Comprehensive error handling

### Audit Trail

- `rotation_history.yaml` logs all rotations
- Git history tracks all changes
- State files track rotation progress

## Emergency Procedures

### User Key Issues

If user key rotation fails:
```bash
cd ~/ws/nix-config
git revert <commit-sha>
home-manager switch
# Old keys restored
```

### Host Key Emergency

If host key rotation breaks decryption:

**Option 1: Restore from backup**
```bash
sudo tar -xzf /root/ssh-backup-*.tar.gz -C /
sudo systemctl restart sshd
```

**Option 2: Restore from 1Password**
```bash
op item list --categories "SSH Key"
# Restore secrets manually
```

**Option 3: Revert .sops.yaml**
```bash
cd ~/ws/nix-config
cp .sops.yaml.before-phase-c .sops.yaml
sops updatekeys nixos/workstation/*/secrets.yaml
```

See [HOST-KEY-ROTATION.md](HOST-KEY-ROTATION.md) Emergency Rollback section for details.

## Architecture

### Key Management Flow

```
┌─────────────────┐
│ Generate Keys   │
│ (ed25519)       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Encrypt (sops)  │
│ Add to secrets  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Git (encrypted) │◄────┐
└────────┬────────┘     │
         │              │ Backup
         v              │
┌─────────────────┐     │
│ Deploy (NixOS)  │     │
│ Decrypt to ~/.ssh│    │
└────────┬────────┘     │
         │              │
         v              │
┌─────────────────┐     │
│ 1Password       │─────┘
│ (backup)        │
└─────────────────┘
```

### sops-nix Integration

```
Host Key (/etc/ssh/ssh_host_ed25519_key)
         │
         │ ssh-to-age
         v
    Age Key (age1abc...)
         │
         │ .sops.yaml
         v
  Encrypt/Decrypt Secrets
         │
         v
  ~/.config/sops-nix/secrets/*
```

## Monitoring

### Systemd Timers

Check rotation timer status:
```bash
# User key age check
systemctl --user status ssh-key-rotation-check.timer

# Next run time
systemctl --user list-timers ssh-key-rotation-check.timer

# Manual trigger
~/.local/bin/ssh-check-rotation
```

### Key Age

Check when keys need rotation:
```bash
# Auth key age
stat -c %Y ~/.ssh/id_auth_ed25519
# Compare to 90 days (7776000 seconds)

# Host key age
sudo stat -c %Y /etc/ssh/ssh_host_ed25519_key
# Compare to 365 days (31536000 seconds)
```

## Rotation Calendar

Maintain a schedule:

| Host   | Auth Key Due | Signing Key Due | Host Key Due |
|--------|--------------|-----------------|--------------|
| meh    | 2026-07-30   | 2026-07-30      | 2027-04-30   |
| floki  | -            | -               | -            |
| arnold | -            | -               | -            |
| darwin | -            | -               | -            |

Set calendar reminders 7 days before due date.

## Best Practices

### For All Rotations

1. **Always validate first**
   - Run validation script before rotating
   - Check system stability
   - Ensure backups exist

2. **Use dry-run mode**
   - Test rotation without making changes
   - Verify script logic
   - Catch issues early

3. **Test thoroughly**
   - Verify SSH auth works
   - Verify git signing works
   - Verify sops decryption works
   - Check all services using secrets

4. **Document everything**
   - Log all rotations
   - Note any issues
   - Update rotation schedule

### For Host Key Rotation

5. **Read documentation completely**
   - Don't skip any steps
   - Understand each phase
   - Know rollback procedures

6. **Use helper script**
   - Guides through 9 phases
   - Tracks progress
   - Validates each step

7. **Wait the full 30 days**
   - Don't rush Phase I
   - Monitor system daily
   - Keep old key as backup

8. **Backup before cutover**
   - Full system backup
   - Old key archived
   - Multiple recovery options

## Troubleshooting

### Common Issues

**"Cannot decrypt secrets"**
- Check age key derivation matches .sops.yaml
- Verify SSH host key is correct
- Try old key if during dual-key period

**"SSH agent not working"**
- Check $SSH_AUTH_SOCK
- Restart ssh-agent service
- Log out and back in

**"Git signing failed"**
- Check signing key permissions (600)
- Verify allowed_signers file
- Check git config

**"Validation failed"**
- Fix issues before rotating
- Don't proceed with rotation
- Check validation error messages

### Getting Help

1. Check troubleshooting sections in documentation
2. Review rotation_history.yaml for past issues
3. Check git log for recent changes
4. Review systemd journal for errors

## References

- **sops:** https://github.com/getsops/sops
- **sops-nix:** https://github.com/Mic92/sops-nix
- **age:** https://github.com/FiloSottile/age
- **ssh-to-age:** https://github.com/Mic92/ssh-to-age
- **OpenSSH:** https://www.openssh.com/

## Contributing

When updating documentation:

1. Keep procedures accurate and tested
2. Document edge cases and failures
3. Update troubleshooting sections
4. Version documentation with date
5. Test on pilot host before rollout

## License

This documentation is part of the nix-config repository.
