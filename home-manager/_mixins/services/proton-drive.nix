{ config, pkgs, lib, ... }:
# Proton Drive via rclone's NATIVE `protondrive` backend (rclone >= 1.64;
# nixpkgs ships 1.72). This replaces the old broken WebDAV attempt
# (Proton Drive has no WebDAV API). It does NOT copy your whole Drive
# locally: `rclone mount` presents Drive as ~/ProtonDrive and fetches files
# on demand, caching only what you open (--vfs-cache-mode writes).
#
# Auth: rclone logs in with the sops username/password and CACHES the
# resulting session tokens (client_uid/access/refresh/salted_key_pass) into
# a WRITABLE rclone.conf in the runtime dir, so it doesn't re-login every
# mount. A `rclone.conf` template (with the credentials) is rendered at
# service start from sops, never written to the Nix store.
#
# 2FA note: if the Proton account has 2FA enabled, the FIRST login is
# interactive (rclone prompts for a TOTP code) — run once by hand:
#   rclone config reconnect protondrive:
# then the cached session tokens make subsequent automatic mounts work.
let
  inherit (lib) mkEnableOption mkOption types mkIf;
  c = config.services.protonDrive;
  confDir = "%t/rclone";
  conf = "${confDir}/rclone.conf";
in
{
  options.services.protonDrive = {
    enable = mkEnableOption "Mount Proton Drive via rclone's native protondrive backend";
    mountPoint = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/ProtonDrive";
      description = "Where to FUSE-mount Proton Drive.";
    };
  };

  config = mkIf c.enable {
    home.packages = [ pkgs.rclone pkgs.fuse ];

    systemd.user.services.proton-drive-mount = {
      Unit = {
        Description = "Mount Proton Drive via rclone (native protondrive backend)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "notify";
        Environment = [ "RCLONE_CONFIG=${conf}" ];
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${c.mountPoint} ${confDir}"
          # Render the rclone.conf from sops creds into the runtime dir
          # (tmpfs, mode 600). rclone will append cached session tokens here
          # on first login so later starts reuse the session.
          (toString (pkgs.writeShellScript "proton-drive-render-conf" ''
            set -eu
            CONF="${conf}"
            # Preserve an existing conf (it holds the cached session tokens);
            # only seed a fresh one if absent.
            if [ ! -f "$CONF" ]; then
              USER_VAL="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."drive/proton/user".path})"
              PASS_RAW="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."drive/proton/pass".path})"
              PASS_OBS="$(${pkgs.rclone}/bin/rclone obscure "$PASS_RAW")"
              ${pkgs.coreutils}/bin/install -m600 /dev/null "$CONF"
              {
                echo "[protondrive]"
                echo "type = protondrive"
                echo "username = $USER_VAL"
                echo "password = $PASS_OBS"
                echo "enable_caching = true"
              } > "$CONF"
            fi
          ''))
        ];
        ExecStart = "${pkgs.rclone}/bin/rclone mount protondrive: ${c.mountPoint} --config ${conf} --vfs-cache-mode writes --dir-cache-time 30s";
        ExecStop = "${pkgs.fuse}/bin/fusermount -u ${c.mountPoint}";
        Restart = "on-failure";
        RestartSec = "30s";

        # --- sandbox (FUSE needs the setuid fusermount, so no
        # NoNewPrivileges/RestrictSUIDSGID; --allow-other not used so no
        # ProtectHome conflict). The rest applies. ---
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictRealtime = true;
        LockPersonality = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
        UMask = "0077";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
