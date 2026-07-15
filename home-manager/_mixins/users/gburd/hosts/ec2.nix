{ lib, pkgs, ... }:
# ec2 — the agent-sandbox `--tier ec2` guest. This is NOT a real workstation:
# it's a throwaway NixOS instance (see modules/home-manager/ai/agent-sandbox.nix,
# ec2 tier) provisioned with a gburd user + passwordless sudo, then handed
# just enough home-manager config to run the coding agents. Deliberately
# minimal — no sops (no secrets file exists on a fresh EC2 box, and
# console/ai's modules already fall back safely without one), no desktop
# apps, no backup/email/calendar services, no SSH key rotation (that's for
# long-lived hosts with an identity to rotate).
#
# litellm.enable is explicitly OFF here: this instance doesn't run its own
# gateway. Agents reach the ORIGINATING host's LiteLLM proxy through an SSH
# remote port-forward (127.0.0.1:4000 on the EC2 box tunnels back to the
# real gateway) set up by the ec2 tier's `connect` step, not a local one.
{
  imports = [
    ../../../console/ai
  ];

  programs.ai.litellm.enable = lib.mkForce false;

  # agent-sandbox is the CLIENT-side tool that manages this box's own
  # lifecycle (agent-sandbox --tier ec2 up/connect/down, run from floki/
  # meh/arnold) -- the guest itself never invokes it, so there's no reason
  # to deploy it here (it also can't reach the same numa AWS profile
  # without sops, and this host has none). Not required for correctness
  # (the ec2-tier config templates are plain writeText -- arch-neutral
  # text generation, not a derivation needing cross-arch build/emulation)
  # but there's no reason to build/carry a tool this box never runs.
  programs.ai.sandbox.enable = lib.mkForce false;

  # Same dev-CLI tooling as meh (users/gburd/hosts/meh.nix's own
  # home.packages, minus what genuinely doesn't belong here: GUI apps
  # (1password-gui, element-desktop -- meh is headless too and doesn't
  # actually run these either) and taskbook/khal (both hard-depend on
  # Proton Drive / calendar sops secrets this sops-free host doesn't
  # have). cmake/plocate/minio-client are real CLI tools with no such
  # dependency -- straightforward parity.
  home.packages = with pkgs; [
    cmake
    plocate
    unstable.minio-client
  ];
}
