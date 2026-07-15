{ lib, ... }:
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
  # meh/arnold) -- the guest itself never invokes it. Disabling it here
  # isn't just tidiness: agent-sandbox.nix's derivation embeds BOTH the
  # x86_64 AND aarch64 ec2-tier config templates as literal store-path
  # strings (so an operator on either arch host can launch either arch
  # guest), which forces Nix to build/substitute BOTH unconditionally as
  # part of evaluating the derivation -- confirmed live: a fresh x86_64
  # EC2 guest's own home-manager deploy failed hard trying to build the
  # aarch64 template, because (unlike floki/meh) this guest's nix.conf has
  # no aarch64 in extra-platforms/binfmt (that's set by
  # nixos/_mixins/workstations/common.nix, never deployed here).
  programs.ai.sandbox.enable = lib.mkForce false;
}
