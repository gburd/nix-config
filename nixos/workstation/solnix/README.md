# solnix — declarative system target (illumos / Nix-on-illumos), x86_64-solaris

⚠️ **NOT YET FUNCTIONAL.** This directory is the *system-layer* counterpart to
the `gburd@solnix` home-manager config (`home-manager/_mixins/users/gburd/hosts/solnix.nix`).
It records where we're aiming: a declarative illumos system that a solnix EC2
instance boots, analogous to how `nixos/workstation/meh/` defines the `meh`
NixOS host.

## Why there is no `default.nix` here (yet)

`meh` is a **NixOS** host: `mkHost` → `nixpkgs.lib.nixosSystem` → systemd,
`nixos/` modules, `configuration.nix`. **solnix is illumos, not NixOS** — it
does not use the NixOS module system or systemd. Its declarative system layer
lives in the **solnix project itself** (not this repo):

- `configurations/base.nix` + `modules/config/*` (solnix) — the declarative
  system: `environment.systemPackages` → `system.path` →
  `/run/current-system/sw`, `/etc/nix/nix.conf`, login env, users.
- **SMF**, not systemd, for services (`modules/system/boot/init/smf.nix`).
- **ZFS boot environments** (BEs), not NixOS generations-on-GRUB, for the
  system generation ↔ bootable-toplevel mapping.

So the "declarative system" for solnix is authored in the solnix repo's module
tree (NixOS-like, but illumos-native). This directory in nix-config exists to:

1. **Mark the target** in the same place `meh` lives, so it's discoverable.
2. Hold the **eventual bridge**: once solnix exposes a NixOS-compat eval layer
   (`modules/nixos-compat.nix` in solnix), a thin `default.nix` here could
   import the shared `nixos/_mixins` subset that ports to illumos and hand the
   rest to solnix's SMF/ZFS-BE machinery. That bridge is not built yet.

## The parity goal

`solnix` ≈ **`meh` minus the Linux-only pieces**: headless, same CLI/dev
tooling, same `gburd` home-manager profile — but services translated
systemd→SMF, packages rebuilt as real hermetic `x86_64-solaris` derivations,
and boot/generations on ZFS BEs. Tracked in the solnix project roadmap
(`docs/roadmap-fully-nixified.md`, `docs/design-declarative-userland.md`).

## What has to land first (all in the solnix project, not here)

1. `x86_64-solaris` wired as an evaluable nixpkgs platform (solnix-pkgs fork).
2. Pure `x86_64-solaris` stdenv (**DONE — GATE 1b-PURE proven**) + the package
   set rebuilt as real hermetic derivations (Phase-3, in progress).
3. HM → illumos port (OS-agnostic subset) + flake `inputs.nixpkgs`-for-solaris
   wiring so `gburd@solnix` evaluates.
4. systemd → SMF service shim for `meh`'s 6 services (backlog).
5. sops-on-illumos (backlog).
