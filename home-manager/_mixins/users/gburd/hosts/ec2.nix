{ ... }:
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

  programs.ai.litellm.enable = false;
}
