# Common configuration for all workstations (desktops/laptops)
{ lib, pkgs, ... }:
{
  imports = [
    ../desktop/ente.nix
    ../hardware/systemd-boot.nix
    ../hardware/disable-nm-wait.nix
    ../services/avahi.nix
    ../services/bluetooth.nix
    ../services/pipewire.nix
    ../services/tailscale.nix
    ../virt

    # Optional: Enable comprehensive documentation and debug support
    ../features/documentation.nix
    ../features/debug-symbols.nix
  ];

  # Common console/keyboard settings
  console.keyMap = lib.mkForce "us";
  console.font = lib.mkForce "${pkgs.terminus_font}/share/consolefonts/ter-232n.psf.gz";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=12
    xkb-layout=us
  '';
  services.xserver.xkb.layout = lib.mkForce "us";
  services.xserver.xkb.options = "ctrl:swapcaps";

  # Enable 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "gburd" ];
  };
  # Symlink op-ssh-sign to the standard path expected by git/1Password configs
  systemd.tmpfiles.rules = [
    "d /opt/1Password 0755 root root -"
    "L+ /opt/1Password/op-ssh-sign - - - - ${pkgs._1password-gui}/share/1password/op-ssh-sign"
  ];

  # NextDNS with DNS-over-TLS
  services.resolved = {
    enable = true;
    # 26.05: services.resolved.extraConfig was removed in favor of the
    # structured .settings (INI section -> key/value). dnsovertls/fallbackDns
    # were also renamed into settings.Resolve.DNSOverTLS/FallbackDNS. This is
    # the [Resolve] section of resolved.conf.
    settings.Resolve = {
      # "opportunistic", not "true"/strict. Strict DNS-over-TLS refuses to fall
      # back to plaintext, which is the right posture on a trusted network but
      # makes captive portals (hotel, airplane, conference wifi) impossible to
      # join: a portal works by hijacking plaintext DNS on port 53 to point you
      # at its sign-in page, and it cannot touch an encrypted session on 853.
      # Under strict mode the hijack never lands, so lookups just fail and no
      # login page ever appears.
      #
      # Opportunistic still uses DoT to NextDNS wherever DoT actually works,
      # which is the normal case. The trade is real and deliberate: on a
      # hostile network DNS can degrade to cleartext instead of failing closed.
      # That window is the couple of minutes before you authenticate, and the
      # alternative was a laptop that cannot join public wifi at all.
      DNSOverTLS = "opportunistic";
      FallbackDNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      DNS = [
        "45.90.28.0#362f8c.dns.nextdns.io"
        "2a07:a8c0::#362f8c.dns.nextdns.io"
        "45.90.30.0#362f8c.dns.nextdns.io"
        "2a07:a8c1::#362f8c.dns.nextdns.io"
      ];
      # Route .local queries to mDNS (avahi), not upstream NextDNS
      Domains = "~local";
    };
  };

  # NetworkManager connectivity checking. Without a URI to probe, NM cannot
  # tell "connected" from "connected but behind a portal": it reported
  # connectivity=full on a network that had not been joined yet, so GNOME was
  # never told to raise the sign-in window. With this set, NM fetches the URI,
  # sees a redirect or wrong body, reports connectivity=portal, and GNOME
  # offers the captive-portal login.
  #
  # NB: the probe must be plain HTTP. An HTTPS probe cannot be intercepted by a
  # portal, which defeats the point. This endpoint exists for exactly this
  # purpose and returns a known short body.
  # Tell NetworkManager to use systemd-resolved. DHCP-provided DNS is still
  # ignored so NextDNS stays authoritative on ordinary networks; the portal case
  # is handled by opportunistic DoT plus the connectivity check above rather
  # than by trusting whatever resolver the network hands out.
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.settings = {
    connection = {
      "ipv4.ignore-auto-dns" = true;
      "ipv6.ignore-auto-dns" = true;
    };
    # NB: there is no networking.networkmanager.connectivity option in NixOS;
    # this is NetworkManager's own [connectivity] .conf section, passed through
    # via settings (same mechanism as [connection] above).
    connectivity = {
      uri = "http://networkcheck.kde.org/";
      response = "OK";
      interval = 300;
    };
  };

  # LAN host resolution: bare names (meh, floki, etc.) resolve via search domain
  # "local" appended → hostname.local → answered by avahi mDNS
  networking.search = [ "local" ];

  # Known static LAN hosts (fallback if mDNS not yet available)
  # For DHCP hosts, mDNS via avahi (hostname.local) is the primary mechanism.
  # Add IPs here for any hosts with DHCP reservations or static addresses.
  networking.hosts = {
    "192.168.1.185" = [ "meh" "meh.local" ];
    "192.168.1.206" = [ "sun" "icarus" ];
    # arnold  — fill in IP when static/reserved (currently resolves via mDNS)
    # greenfly (rv) — fill in IP when connected to LAN
  };

  # Disable sudo lecture message and use_pty (fails in non-TTY contexts)
  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults !use_pty
  '';

  # Make Nix tools available at traditional FHS paths
  # Provides /usr/bin/env, /bin/sh, and other standard paths
  services.envfs.enable = true;

  # Dynamic linker for non-NixOS binaries
  # Provides /lib64/ld-linux-x86-64.so.2 and other standard library paths
  programs.nix-ld.enable = true;

  # Enable core dumps in current directory with pattern core.<pid>
  # 26.05: systemd.coredump.extraConfig removed in favor of .settings.Coredump.
  systemd.coredump.settings.Coredump.Storage = "none";
  security.pam.loginLimits = [
    { domain = "*"; type = "-"; item = "core"; value = "unlimited"; }
  ];
  boot.kernel.sysctl = {
    "kernel.core_pattern" = "core.%p";
    "kernel.core_uses_pid" = 1;
    # Allow ptrace (gdb/lldb/strace attaching to an unrelated process) without
    # sudo. Default (1, "restricted") only allows a process to ptrace its own
    # direct children -- attaching a debugger to an already-running process
    # (a running server, a test harness's child, another terminal's shell)
    # needs CAP_SYS_PTRACE (sudo) otherwise. 0 = classic/unrestricted (any
    # process owned by the same uid can be traced), the standard trade-off on
    # a single-user dev workstation that already trusts its own user.
    "kernel.yama.ptrace_scope" = 0;
  };

  # Support for cross-platform NixOS builds
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];
}
