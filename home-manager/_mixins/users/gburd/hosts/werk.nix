{ pkgs, ... }:
# werk -- headless x86_64 NixOS on EC2 (m6idn.12xlarge). The home-manager half
# of the werk host. A "headless floki" for the command line: the AI agent
# tooling (console/ai) plus the dev CLIs, no desktop apps, no email/calendar/
# backup services. werk is long-lived (stop + termination protection, on the
# tailnet, enrolled in sops) unlike the throwaway agent-sandbox ec2 tier, so
# it keeps its own LiteLLM gateway and the normal MCP set.
#
# Deliberately minimal to start; grow it toward meh.nix (borgmatic, email,
# unison-sync, ssh-management) as the host earns those roles.
{
  imports = [
    ../../../console/ai # Opt-in AI configuration (LiteLLM gateway, MCPs, agents)
  ];

  # Same dev-CLI parity as the ec2 tier: object-store client + cmake + locate.
  # awscli2 and s5cmd come from the console/ai and shared cli imports.
  home.packages = with pkgs; [
    cmake
    plocate
    unstable.rclone
  ];
}
