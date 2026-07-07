_:
# firejail — namespace-based sandbox (SUID helper) used by agent-sandbox to
# isolate coding agents transparently (no agent cooperation, agent-agnostic).
# Enables the SUID wrapper so `firejail <cmd>` works for the user. Custom
# agent profiles are shipped per-user to ~/.config/firejail/ by the
# home-manager module modules/home-manager/ai/agent-sandbox.nix.
#
# NixOS only (floki, meh). arnold is Fedora — install firejail via dnf there
# if agent-sandbox is wanted on that host.
{
  programs.firejail.enable = true;
}
