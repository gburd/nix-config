{ pkgs, ... }:
{
  home.packages = [ pkgs.protonmail-bridge ];

  # ReadWritePaths entries must exist or systemd fails the unit at the
  # NAMESPACE step (status 226) before the bridge even runs. On a fresh host
  # (arnold) nothing had created these, and the unit restart-looped from
  # Sep 17 on.
  systemd.user.tmpfiles.rules = [
    "d %h/.config/protonmail 0700 - - -"
    "d %h/.local/share/protonmail 0700 - - -"
    "d %h/.cache/protonmail 0700 - - -"
  ];

  systemd.user.services.protonmail-bridge = {
    Unit = {
      Description = "ProtonMail Bridge";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive --log-level info";
      Restart = "on-failure";
      RestartSec = "5s";

      # --- sandboxing -------------------------------------------------
      # The bridge logs into Proton and exposes local IMAP/SMTP holding
      # full mailbox credentials in its keyring/config. Lock it down.
      # It needs network + its own config/keyring under ~/.config and
      # ~/.local; everything else stays read-only.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "%h/.config/protonmail"
        "%h/.local/share/protonmail"
        "%h/.cache/protonmail"
        # gnome-keyring's socket dir. "-" = optional: meh runs no
        # gnome-keyring and arnold uses KDE's ksecretd over D-Bus, so the
        # directory is absent there and a hard entry failed the unit.
        "-%t/keyring"
      ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      # Local IMAP/SMTP listeners + outbound HTTPS to Proton + the
      # secret-service unix socket. AF_NETLINK lets the bridge query the
      # interface list for its connectivity check (otherwise it logs a
      # harmless "route ip+net: netlinkrib: address family not supported"
      # every refresh).
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
      SystemCallErrorNumber = "EPERM";
      UMask = "0077";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
