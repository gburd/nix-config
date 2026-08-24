{ config, lib, pkgs, ... }:
# solnix -- the gburd profile on a solnix host (Nix on illumos/Solaris).
#
# Two shapes of solnix host use this file, distinguished by `desktop`:
#   * desktop = "cosmic": a workstation (the imminent RISC-V daily-driver box,
#     or a test EC2 instance) running the COSMIC desktop -- functionally the
#     pop!_OS COSMIC experience, illumos underneath.
#   * desktop = null: a headless solnix build-farm animal (the aarch64 EC2
#     build node) -- just the console/cli + AI agent tooling.
#
# The heavy lifting (per-OS gating) lives in systems/solaris.nix; this host
# file only carries solnix-host-specific opinions.
{
  # solnix has no sops secrets provisioned yet (like ec2.nix, the modules
  # fall back safely without one). Turn off the pieces that assume a running
  # LiteLLM gateway / secrets on the box; agents reach a gateway over SSH
  # forward if needed, same as the ec2 tier.
  programs.ai.litellm.enable = lib.mkForce false;

  # SkillSpector's uvx-based switch-time scan hangs on a fresh box (see
  # ec2.nix); pointless on solnix where the toolchain is still filling in.
  programs.ai.skills.skillSpector.enable = lib.mkForce false;

  # illumos is not Linux: no targets.genericLinux, no nix-ld. Home-manager's
  # activation must not assume systemd --user. Anything that does is gated in
  # systems/solaris.nix (which this host pairs with).
}
