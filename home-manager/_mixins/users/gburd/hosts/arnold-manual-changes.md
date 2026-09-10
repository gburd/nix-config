# arnold — host-level changes NOT captured by Nix/home-manager

arnold is a **Fedora** box running the `gburd@arnold` home-manager profile via
standalone Nix (it is NOT NixOS — there is no `nixos/workstation/arnold`).
That means anything below the home-manager layer — the Fedora base system,
system-scoped systemd units, `dnf` packages, and one-off filesystem/permission
fixes applied live over SSH — is **not** reproduced by `home-manager switch`.

This file records those out-of-band changes so a rebuilt/re-provisioned arnold
can be brought back to a known-good state. Everything here was applied
manually; none of it is enforced declaratively (yet).

> If a change CAN be made declarative in the HM config, prefer that and delete
> the entry here. Items remain because they're Fedora-system-scoped (no Nix
> hook) or genuinely one-off.

---

## 1. Mask the per-user `uresourced` daemon (CPU busy-loop)

**Symptom:** after a Fedora + HM update and reboot, `systemd --user` (pid ~1346)
sat at ~65-70% CPU with load ~2.7, persistently (survived reboot).

**Cause:** Fedora's `uresourced --user` (User Resource Assignment Daemon —
dynamically boosts the active graphical session's memory-cgroup protection) got
stuck in a silent D-Bus busy-loop with `systemd --user` (~5000 ctxt-switches/s
each, logging nothing). It auto-starts via `WantedBy=graphical-session.target`,
so a reboot doesn't help — it comes back on every graphical login. Confirmed:
stopping it froze systemd --user's ctxt-switch counter and dropped it to 0% CPU.
The SYSTEM `uresourced.service` was fine — only the `--user` instance looped.

**Fix (applied live, persists via the symlink):**
```bash
systemctl --user mask uresourced.service
# -> ~/.config/systemd/user/uresourced.service -> /dev/null
```
Safe: uresourced is a non-essential cgroup-priority tuner. Masking is the
standard remedy for this Fedora bug. Re-apply after any wipe of
`~/.config/systemd/user`.

## 2. Fix `~/.ssh` subdir permissions (broke borg backups)

**Symptom:** nightly `borgmatic` failed for weeks (exit 105, "permission denied
on some files"), so no archive was written.

**Cause:** `~/.ssh/gitpod/` and `~/.ssh/_/` were created mode **600** (no `x`
traverse bit), so borg couldn't stat the files inside → exit 105 → whole backup
aborted. (The container-storage exclude that also contributed IS declarative —
see `services/borgmatic.nix`; only the perm fix is manual.)

**Fix (applied live):**
```bash
chmod 700 ~/.ssh/gitpod ~/.ssh/_
```
`~/.ssh/_` holds a stray, unreferenced 2023 `gburd@symas.com` keypair; `gitpod`
is Gitpod-VSCode-managed. Both are also excluded from backups in
`services/borgmatic.nix`. If truly abandoned they can be deleted instead.

## 3. If a `home-manager switch` hangs at "Starting units: sops-nix.service"

**Symptom:** the switch reaches `reloadSystemd` and hangs; `systemctl --user
list-jobs` shows `sops-nix.service start` stuck in `waiting`; the `sd-switch`
process never returns.

**Cause:** arnold's `systemd --user` job scheduler wedges (a passive `After=
basic.target` ordering deadlocks during sd-switch's reload). One-off, not
persistent state.

**Fix (recovery, not permanent config):**
```bash
systemctl --user daemon-reexec   # re-execs the user manager, clears the wedged job
# then re-run: home-manager switch --flake ~/ws/nix-config#gburd@arnold -b hm-bak
```

---

## Fedora-side operational notes (not Nix-managed)

- **No passwordless sudo** — `sudo dnf upgrade`, system flatpak ops, and any
  system-unit changes must be run interactively by the user; they cannot be
  driven non-interactively over SSH.
- **`dnf upgrade` + `flatpak update`** are the Fedora update path (the HM layer
  is separate: `home-manager switch --flake ~/ws/nix-config#gburd@arnold -b hm-bak`,
  with `nix` on PATH — a non-login shell won't find it: exit 127
  "nix: command not found").
- **GUI flatpaks are system-scoped** (Orion, Slack, Typora, Remmina); `--user`
  flatpak list is empty.
- **Stray `flake.lock` modification** recurs on arnold and blocks `git pull
  --ff-only`; reset before pulling: `git checkout -- flake.lock`.
- Sops on arnold decrypts via the `~/.ssh/id_ed25519` age key and reuses
  floki's `secrets.yaml` (see `arnold.nix`) — the age key must exist for the
  bedrock token / borg secrets to render.
