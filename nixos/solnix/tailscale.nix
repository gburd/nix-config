# nixos/solnix/tailscale.nix -- a solnix host on our tailnet (Headscale, headscale.burd.me), solnix's services.tailscale.
# The NixOS hosts use nixos/_mixins/services/tailscale-autoconnect.nix (sops-nix); solnix has no sops-nix, so the reusable
# pre-auth key is placed by hand, like the build-queue bearer (never in the store or argv):
#   sops -d --extract '["tailscale-auth-key"]' nixos/_mixins/secrets.yaml \
#     | ssh root@<host> 'umask 077; mkdir -p /var/lib/solnix; cat > /var/lib/solnix/tailscale-authkey'
# illumos has no tailscale TUN, so tailscaled runs userspace networking: tailnet TCP to this node is forwarded to localhost
# (sshd works), and local programs reach the tailnet only through tailscaled's SOCKS5/HTTP proxy.
# The key is used only while the node is logged out: once /var/lib/tailscale holds a session, autoconnect is a no-op, and
# a change to extraUpFlags reaches a logged-in node only after `tailscale up --reset ...` by hand (or a wiped state).
{ config, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/solnix/tailscale-authkey";
    extraUpFlags = [ "--login-server=https://headscale.burd.me" "--accept-routes" "--hostname=${config.networking.hostName}" ];
    # tailscaled uploads logs to log.tailscale.io whatever the control server is; not under Headscale (as the NixOS hosts).
    disableUpstreamLogging = true;
  };
}
