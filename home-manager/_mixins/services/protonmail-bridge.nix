{ config, lib, pkgs, ... }:
let
  cfg = config.services.protonmailBridge;
  vault = "%h/.config/protonmail/bridge-v3";
  busctl = "${pkgs.systemd}/bin/busctl";
  cu = "${pkgs.coreutils}/bin";
  bridgeCmd = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive --log-level info";
  # Start the bridge only once the secret-service default collection is
  # UNLOCKED. When the user manager starts before the desktop login (unison
  # peers ssh in at boot), the keyring is still locked, the bridge's keychain
  # test fails, and it silently opens a new EMPTY file vault under insecure/:
  # neomutt then gets "no such user" (floki 2026-10-14, -28 twice, -29).
  # The wait is inside ExecStart, not ExecStartPre: a waiting start job would
  # hold the user manager's startup, and with it every ssh login.
  startBridge = pkgs.writeShellScript "protonmail-bridge-keyring-start" ''
    until [ "$(${busctl} --user get-property org.freedesktop.secrets \
        /org/freedesktop/secrets/aliases/default \
        org.freedesktop.Secret.Collection Locked 2>/dev/null)" = "b false" ]; do
      [ -n "$waited" ] || echo "waiting for the login keyring to be unlocked"
      waited=1
      ${cu}/sleep 5
    done
    # A fallback vault from an earlier run must never be picked up again.
    if [ -d "$1/insecure" ]; then
      ${cu}/mv "$1/insecure" "$1/insecure.fallback-$(${cu}/date +%Y%m%d-%H%M%S)"
    fi
    exec ${bridgeCmd}
  '';
in
{
  options.services.protonmailBridge.requireKeyring = lib.mkEnableOption ''
    keyring-only vault: wait for an unlocked secret-service collection
    before starting and refuse the bridge's empty file-vault fallback.
    Only for hosts whose real vault is in the keyring (floki); hosts with no
    secret service (meh, werk, arnold) keep using the file vault'';

  config = {
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
        ExecStart = if cfg.requireKeyring then "${startBridge} ${vault}" else bridgeCmd;
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
  };
}
