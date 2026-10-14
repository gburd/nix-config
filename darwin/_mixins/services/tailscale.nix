# Tailscale CLIENT on macOS, coordinated by our own HEADSCALE server -- never
# by tailscale.com. Uses nix-darwin's services.tailscale for the daemon.
#
# WHY HEADSCALE HERE IN PARTICULAR: this is the employer's Mac, and talking to
# Tailscale's servers is blocked by policy there. So the client must not
# depend on any Tailscale-operated host for coordination, relay or logging:
#
#   * COORDINATION -> https://headscale.burd.me (fly.io, ~/ws/fly-apps/
#     headscale). Set at enrolment with `tailscale up --login-server`; nix-
#     darwin's module has no option for it. See docs/tailscale-darwin.md.
#   * RELAY (DERP) -> the Headscale server's EMBEDDED DERP only. Its config
#     sets derp.urls = [], dropping Tailscale's *.tailscale.com relay map, so
#     relayed traffic never leaves for a Tailscale host.
#   * LOG UPLOAD -> disabled here. tailscaled uploads logs to
#     log.tailscale.io by default, whatever the control server. That is a
#     Tailscale endpoint and would trip the policy block (and send telemetry
#     to Tailscale for a tailnet it does not run). TS_NO_LOGS_NO_SUPPORT=true
#     is the switch nixpkgs' NixOS module uses for
#     services.tailscale.disableUpstreamLogging; nix-darwin's module has no
#     such option, so it goes onto the launchd daemon's environment directly.
#   * CAPTIVE-PORTAL PROBES -> disabled here. When STUN is slow or the link
#     looks broken, tailscaled probes http://controlplane.tailscale.com and
#     http://login.tailscale.com/generate_204 (net/captivedetection), even
#     under a custom control server. TS_DISABLE_FEATURE=captiveportal
#     unregisters both the detection loop and the netcheck hook (checked
#     against the v1.104.1 source).
#
# MagicDNS needs nothing here. tailscaled itself writes
# /etc/resolver/<MagicDNS suffix> (here ts.burd.me) through os.Root. Do NOT
# also declare environment.etc."resolver/ts.burd.me": nix-darwin would make
# it a symlink into /etc/static, os.Root refuses to write through it ("path
# escapes from parent"), and tailscaled's own DNS config step fails and
# stops: SetDNS returns on that write error and never reaches its cleanup of
# stale resolver files. nix-darwin's own resolver/ts.net never collides,
# because ts.net is only the SaaS suffix.
#
# Deliberately NOT setting services.tailscale.overrideLocalDns: it makes
# 100.100.100.100 the SOLE resolver, which on this Mac would displace the
# corporate DNS. The Headscale config also sets dns.override_local_dns =
# false, for the same reason.
{ config, pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
  };

  launchd.daemons.tailscaled.serviceConfig.EnvironmentVariables = {
    TS_NO_LOGS_NO_SUPPORT = "true";
    TS_DISABLE_FEATURE = "captiveportal";
  };

  # `tailscale` CLI on PATH for the enrolment step and day-to-day use.
  environment.systemPackages = [ pkgs.tailscale ];

  # Fail evaluation, rather than silently drift, if someone re-enables the
  # option this file argues against.
  assertions = [{
    assertion = !config.services.tailscale.overrideLocalDns;
    message = "darwin tailscale: keep overrideLocalDns off on the work Mac (see the comment above).";
  }];
}
