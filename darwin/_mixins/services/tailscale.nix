# Tailscale on macOS, via nix-darwin's own services.tailscale module.
#
# Why this host was missing from the tailnet: nothing blocked it. Tailscale
# builds fine for aarch64-darwin and headscale/Tailscale both list macOS as
# supported -- it had simply never been configured here. (The solnix hosts
# dixi/dixa/dixr are a different case: illumos has no Tailscale client at
# all, so no amount of config or a Headscale switch would add them.)
#
# This installs and runs the tailscaled daemon. It does NOT enrol the node:
# unlike the NixOS path (nixos/_mixins/services/tailscale-autoconnect.nix,
# which reads a reusable auth key from sops), nix-darwin's module exposes no
# auth-key or extra-up-flags option, and there is no sops-nix on darwin
# (see darwin/_mixins/console/ai/default.nix). So the first `tailscale up`
# is a one-time manual step -- see docs/tailscale-darwin.md.
#
# Deliberately NOT setting services.tailscale.overrideLocalDns. Its own
# option description warns that it makes 100.100.100.100 the sole DNS
# server, so "all non-MagicDNS queries WILL fail" unless a DNS server is
# added and `Override local DNS` is enabled in the Tailscale control panel.
# This host is a laptop that moves between networks; breaking plain DNS to
# gain MagicDNS is the wrong trade.
{ pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
  };

  # `tailscale` CLI on PATH for the enrolment step and day-to-day use
  # (status, ssh, exit-node switching). The daemon above ships the binary,
  # but not on an interactive PATH.
  environment.systemPackages = [ pkgs.tailscale ];
}
