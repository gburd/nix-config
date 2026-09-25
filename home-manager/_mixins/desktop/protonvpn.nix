{ pkgs, ... }:
# Proton VPN, official GTK app (protonvpn-app). Replaces the old chaotic-nyx
# nordvpn.nix.
#
# There is no NixOS module for it, and none is needed: the app creates its
# WireGuard/OpenVPN tunnels as NetworkManager connections over D-Bus and keeps
# credentials in the Secret Service keyring. The system-side prerequisites are
# already in place on floki: networking.networkmanager, gnome-keyring, and
# networking.firewall.checkReversePath = "loose" (strict reverse-path
# filtering drops WireGuard replies routed through NM).
#
# The kill switch blocks all non-tunnel traffic, captive-portal sign-in pages
# included. On hotel or airplane wifi, sign in to the portal before
# connecting.
{
  home.packages = [ pkgs.proton-vpn ];
}
