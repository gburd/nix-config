# solnix — declarative system target (illumos / Nix-on-illumos)

⚠️ **NOT YET FUNCTIONAL.** This directory is the *system-layer* marker for the
three solnix (`dix*`) home-manager hosts. It records where we're aiming: a
declarative illumos system that a solnix instance boots, analogous to how
`nixos/workstation/meh/` defines the `meh` NixOS host.

## The three hosts

| Host | Arch | Where | Desktop | Solnix phase |
|------|------|-------|---------|--------------|
| **dixi** | x86_64 | EC2 (permanent account) | headless | 1 (primary target) |
| **dixa** | aarch64 | EC2 (permanent account) | headless | 3 (arm port to integrate) |
| **dixr** | RISC-V | physical dev box (kbd/mouse/monitor) | **COSMIC** (Pop!_OS-like) | 5 (no illumos port yet) |

The gburd home-manager profiles are `gburd@dixi` / `gburd@dixa` / `gburd@dixr`
(`flake.nix`); each imports `home-manager/_mixins/users/gburd/hosts/dix*.nix`
(thin) → `_solnix-common.nix` (shared) and pairs with
`systems/solaris.nix` (per-OS gating). Only dixr carries `desktop = "cosmic"`.

## Why there is no `default.nix` here (yet)

`meh` is a **NixOS** host: `mkHost` → `nixpkgs.lib.nixosSystem` → systemd,
`nixos/` modules, `configuration.nix`. **solnix is illumos, not NixOS** — it
does not use the NixOS module system or systemd. Its declarative system layer
lives in the **solnix project itself** (`~/ws/solnix`, not this repo):

- `configurations/base.nix` + `modules/config/*` (solnix) — the declarative
  system: `environment.systemPackages` → `system.path` →
  `/run/current-system/sw`, `/etc/nix/nix.conf`, login env, users.
- **SMF**, not systemd, for services (`modules/system/boot/init/smf.nix`).
- **ZFS boot environments** (BEs), not NixOS generations-on-GRUB, for the
  system generation ↔ bootable-toplevel mapping.

So the "declarative system" for solnix is authored in the solnix repo's module
tree (NixOS-like, but illumos-native). This directory exists to:

1. **Mark the target** in the same place `meh` lives, so it's discoverable.
2. Hold the **eventual bridge**: once solnix exposes a NixOS-compat eval layer,
   a thin `default.nix` here could import the shared `nixos/_mixins` subset
   that ports to illumos and hand the rest to solnix's SMF/ZFS-BE machinery.
   That bridge is not built yet.

## The parity goal

`dix*` ≈ **`meh` (headless) / a COSMIC workstation (dixr) minus the Linux-only
pieces**: same CLI/dev tooling, same `gburd` home-manager profile — but
services translated systemd→SMF, packages rebuilt as real hermetic
`<arch>-solaris` derivations, and boot/generations on ZFS BEs. Tracked in the
solnix project roadmap.

## What has to land first (all in the solnix project, not here)

1. `<arch>-solaris` wired as an evaluable nixpkgs platform (solnix-pkgs fork).
   Today only `x86_64-solaris` exists (Phase 1); `aarch64-solaris` (Phase 3)
   and `riscv64-solaris` (Phase 5) are staged. **Until the fork is wired as a
   flake input here, `mkHome` falls back to native pkgs so the `dix*` configs
   still evaluate — profile shape only, nothing builds.**
2. Pure `<arch>-solaris` stdenv (x86_64 **DONE — GATE 1b-PURE proven**) + the
   package set rebuilt as real hermetic derivations (Phase-3, in progress).
3. HM → illumos port (OS-agnostic subset) + flake `inputs`-for-solaris wiring
   so `gburd@dixi` evaluates against a real solaris pkg set.
4. systemd → SMF service shim for `meh`'s services (backlog).
5. sops-on-illumos (backlog).
