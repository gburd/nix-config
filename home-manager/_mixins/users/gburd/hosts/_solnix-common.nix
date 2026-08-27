{ lib, ... }:
# Shared gburd-profile base for the solnix (Nix on illumos/Solaris) hosts:
# dixi (x86_64, EC2, headless), dixa (aarch64, EC2, headless), and dixr
# (RISC-V, physical dev box, COSMIC desktop). Each host file imports this and
# adds only its own specifics (dixr adds the COSMIC desktop via its `desktop`
# arg, handled in systems/solaris.nix).
#
# The heavy per-OS gating lives in systems/solaris.nix; this base carries the
# solnix-host-common opinions that hold on ALL three.
{
  # No solnix host has sops secrets provisioned yet (like ec2.nix, the modules
  # fall back safely without one). Turn off pieces that assume a running
  # LiteLLM gateway / secrets on the box; agents reach a gateway over an SSH
  # forward if needed, same as the ec2 tier.
  programs.ai.litellm.enable = lib.mkForce false;

  # SkillSpector's uvx-based switch-time scan hangs on a fresh box (see
  # ec2.nix) -- pointless on solnix where the toolchain is still filling in.
  programs.ai.skills.skillSpector.enable = lib.mkForce false;

  # illumos is not Linux: no targets.genericLinux, no nix-ld, no systemd
  # --user. Anything that assumes those is gated OUT in systems/solaris.nix
  # (which every dix* host pairs with via systemType "solaris").
}
