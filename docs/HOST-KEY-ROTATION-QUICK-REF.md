# Host Key Rotation - Quick Reference

**⚠️ Read full documentation first:** `docs/HOST-KEY-ROTATION.md`

## Pre-Flight Checklist

- [ ] Read full documentation
- [ ] Full backup exists
- [ ] 2+ hours available
- [ ] System is stable
- [ ] Can afford 30+ day dual-key period

## The 9 Phases

```
A. Generate new host key          [5 min]  [Low risk]
B. Derive new age key             [2 min]  [Low risk]
C. Add to .sops.yaml              [5 min]  [Low risk] ← DUAL-KEY BEGINS
D. Re-encrypt all secrets         [15 min] [MEDIUM]   ← CRITICAL
E. Deploy and verify              [15 min] [MEDIUM]
F. Cutover to new key            [5 min]  [HIGH]     ← POINT OF NO RETURN
G. Verify decryption still works  [10 min] [HIGH]     ← CRITICAL
H. 30-day safety period           [30 days][Low]     ← DO NOT SKIP
I. Remove old key                 [15 min] [MEDIUM]  ← FINAL
```

## Quick Commands

### Phase A: Generate
```bash
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key_NEW -N ""
sudo chmod 600 /etc/ssh/ssh_host_ed25519_key_NEW
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key_NEW  # Record fingerprint
```

### Phase B: Derive Age Keys
```bash
AGE_KEY_NEW=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key_NEW.pub)
AGE_KEY_OLD=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
echo "OLD: $AGE_KEY_OLD"
echo "NEW: $AGE_KEY_NEW"
```

### Phase C: Update .sops.yaml
```yaml
# Add new key, rename old to *-old
- &meh-old age150z9ve...  # old key
- &meh-new age1abc123...  # NEW key
```

### Phase D: Re-encrypt
```bash
cd ~/ws/nix-config
sops -d nixos/workstation/$(hostname)/secrets.yaml | head  # Test BEFORE
for f in $(find . -name "secrets.yaml"); do sops updatekeys "$f"; done
sops -d nixos/workstation/$(hostname)/secrets.yaml | head  # Test AFTER
```

### Phase E: Deploy
```bash
git push
nixos-rebuild switch --flake .#$(hostname)
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null  # Must work!
```

### Phase F: Cutover
```bash
sudo systemctl stop sshd
sudo mv /etc/ssh/ssh_host_ed25519_key{,.OLD}
sudo mv /etc/ssh/ssh_host_ed25519_key_NEW /etc/ssh/ssh_host_ed25519_key
sudo systemctl start sshd
```

### Phase G: Verify
```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub  # Must match AGE_KEY_NEW
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null  # Must work!
cat ~/.config/claude-code/.bearer_token  # Must work!
```

### Phase H: Wait
```
Day 1:  ✓ Check decryption
Day 7:  ✓ Check decryption
Day 14: ✓ Check decryption
Day 21: ✓ Check decryption
Day 30: ✓ Proceed to Phase I
```

### Phase I: Remove Old Key
```bash
# Edit .sops.yaml: remove *-old, rename *-new to base name
cd ~/ws/nix-config
for f in $(find . -name "secrets.yaml"); do sops updatekeys "$f"; done
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null  # Must work!
sudo tar -czf /root/old-host-key-$(date +%Y%m%d).tar.gz /etc/ssh/*.OLD
```

## Emergency Rollback

### If Phase G Fails
```bash
sudo systemctl stop sshd
sudo mv /etc/ssh/ssh_host_ed25519_key.OLD /etc/ssh/ssh_host_ed25519_key
sudo systemctl start sshd
# Old key restored, investigate failure
```

## Critical Rules

1. **NEVER remove old key before 30-day period**
2. **ALWAYS test decryption after every phase**
3. **ALWAYS backup before Phase F**
4. **If anything fails in Phase G, rollback immediately**

## Verification Commands

```bash
# Age key matches?
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Decryption works?
sops -d nixos/workstation/$(hostname)/secrets.yaml >/dev/null && echo "✓"

# Secrets accessible?
cat ~/.config/claude-code/.bearer_token >/dev/null && echo "✓"

# Services running?
systemctl status protonmail-bridge
```

## Timeline Example

| Date       | Phase | Action                           |
|------------|-------|----------------------------------|
| Apr 30     | A-E   | Generate, add to .sops, deploy   |
| Apr 30     | F     | Cutover to new key               |
| Apr 30     | G     | Verify (CRITICAL)                |
| May 1-29   | H     | Monitor (30 days)                |
| May 30     | I     | Remove old key (complete)        |

**Total time:** ~90 minutes active work + 30 days monitoring

## After Rotation

Update:
- [ ] `rotation_history.yaml`
- [ ] This README with new fingerprint
- [ ] Calendar for next rotation (1 year)
- [ ] SSH client `known_hosts`

## Help

- Full docs: `docs/HOST-KEY-ROTATION.md`
- Helper script: `scripts/ssh-key-rotation/host-key-rotation-helper.sh`
- Issues? Check Emergency Rollback section
