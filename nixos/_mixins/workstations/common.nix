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
    # LAN addresses for hosts that otherwise resolve only through the
    # tailnet's MagicDNS. During the Tailscale -> Headscale move, a host
    # still on the OLD tailnet resolved `arnold` / `rv` to their old
    # 100.x SaaS addresses (arnold.tail09c91d.ts.net). Those are dead once
    # the peer moves, so `ssh arnold` failed. Over the LAN they keep working
    # whichever control server either side is on. Observed 2026-10-14; set
    # DHCP reservations on the router if these ever change.
    "192.168.1.37" = [ "arnold" ];
    "192.168.1.126" = [ "rv" ];
    "192.168.1.61" = [ "nuc" ];
    "192.168.1.179" = [ "lixr" ];
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

  # trippy (`trip`) needs raw sockets. This upstream module installs a
  # setcap wrapper at /run/wrappers/bin/trip with capabilities
  # "cap_net_raw+p", owner root, so `trip` runs unprivileged without sudo.
  # /run/wrappers/bin precedes ~/.nix-profile/bin on PATH, so this wrapper
  # shadows the plain binary the home-manager console mixin installs --
  # which is what we want; the HM copy stays as the fallback on non-NixOS
  # hosts (arnold is Fedora and has no security.wrappers, so `trip` still
  # needs sudo there).
  programs.trippy.enable = true;

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

  # --- Memory: survive an OOM with the session's plumbing intact ----------
  #
  # floki 2026-10-14 10:10: a pg_fts installcheck build (postgres, uid
  # nixbld) pushed the box to global OOM. floki has 31 GiB, no swap and no
  # zram. Resident at the time: 18 pi sessions 7.95 GiB, the build's
  # postgres 3.18 GiB, chrome 2.08 GiB, litellm 1.85 GiB.
  #
  # The kernel's first pick was right (chrome, adj 300). The pressure held,
  # though, and its next picks were the SESSION DAEMONS. systemd gives every
  # user-manager service oom_score_adj=200 (DefaultOOMScoreAdjust) but apps
  # and terminals 100, so a 3 MiB dbus-broker ranked above a 2 GiB pi. Lost:
  # dbus-broker, gpg-agent, scdaemon, the ssh-agent child of gcr-ssh-agent,
  # gnome-keyring's secrets service, protonmail-bridge and litellm. Then:
  #   * ssh/git: gcr-ssh-agent's child could not respawn (stale socket; see
  #     desktop/gnome.nix). Every agent login failed for 4h.
  #   * neomutt/Proton: the bridge restarted while the keyring was gone,
  #     found "no keychain", and fell back to a NEW EMPTY vault
  #     (bridge-v3/insecure/). Every IMAP login got "no such user".
  #
  # Fix 1, zram. Compressed swap in RAM gives the kernel room to reclaim
  # before it must kill. It is the NixOS-recommended answer for swapless
  # desktops. 50% means up to ~15.5 GiB uncompressed can be parked in about a
  # third of that; zstd is the default algorithm.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Fix 2, rank the BUILD below the session, from the system manager.
  #
  # The first version of this set OOMScoreAdjust=0 on dbus-broker, gpg-agent
  # and gcr-ssh-agent as USER units, and DefaultOOMScoreAdjust in user.conf.
  # It did not work, and cannot. The user manager runs unprivileged
  # (CapEff=CAP_AUDIT_READ only, no CAP_SYS_RESOURCE), and the kernel lets an
  # unprivileged process RAISE oom_score_adj but never LOWER it. Those units
  # stayed at 100/200 after the switch, and gpg-agent's unit is
  # home-manager's, so the drop-in never reached it anyway.
  #
  # The system manager IS privileged, so ranks are set there instead:
  #   * user@.service sits at 100 upstream; its children inherit that as
  #     a floor. Lowering it to 0 makes the session daemons rank like
  #     normal processes. User units then land at 0+100 (the user manager's
  #     own default), which is still well below the build.
  #   * nix-daemon gets +500. Its sandbox builds (the pg_fts postgres that
  #     triggered all three 2026-10-14 OOMs, 3.2 / 8.3 / 16.2 GiB) inherit
  #     that, so when memory runs out the kernel picks the BUILD first, not
  #     dbus-broker or the ssh-agent.
  systemd.services."user@".serviceConfig.OOMScoreAdjust = 0;

  # Fix 3, cap the builds. Both floki OOMs on 2026-10-14 (10:10, then 17:08)
  # came from the same place: Nix builds of pg_fts running Postgres TAP and
  # installcheck suites in the sandbox. At 17:08 the build's postgres held
  # 8.33 GiB, more than the 20 pi sessions (8.01 GiB), and nix-daemon peaked
  # at 11.8 GiB with no memory limit at all.
  #
  # MemoryHigh makes the kernel reclaim and throttle the BUILD cgroup when
  # it goes over, so pressure lands on the build and not on the desktop.
  # MemoryMax is the hard ceiling. A build that tries to exceed it is
  # OOM-killed INSIDE nix-daemon.service, which fails that one build with a
  # clear error, instead of the global OOM killer picking through the
  # session. 60% / 75% of RAM leaves room for the session and the pi fleet.
  # A build that legitimately needs more can be run with `systemd-run`, or
  # these can be raised per host.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "60%";
    MemoryMax = "75%";
    OOMScoreAdjust = 500;
  };
}
