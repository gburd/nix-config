# borgmatic — declarative BorgBackup wrapper
# Backs up /home/gburd to rsync.net (ssh://zh6216@zh6216.rsync.net/./borg)
# Passphrase comes from sops secret "backup/borg-passphrase" (or BORG_PASSPHRASE env)
#
# Usage: import this module in host-specific nix files (floki.nix, meh.nix).
# For arnold (Fedora/non-NixOS): import similarly; systemd user services work
# on Fedora with loginctl enable-linger gburd.
#
# Initial repo setup (run once per host, NOT idempotent):
#   borg init --encryption=repokey ssh://zh6216@zh6216.rsync.net/./borg
# when prompted for passphrase, use the value from sops "backup/borg-passphrase"
{ config, pkgs, lib, ... }:
let
  borgmaticConfig = {
    source_directories = [ config.home.homeDirectory ];
    repositories = [
      {
        path = "ssh://zh6216@zh6216.rsync.net/./borg";
        label = "rsync-net";
      }
    ];
    archive_name_format = "{hostname}-{now:%F-%T}";
    compression = "auto,zstd,7";
    exclude_patterns = [
      "${config.home.homeDirectory}/.cache"
      "${config.home.homeDirectory}/.rustup"
      "${config.home.homeDirectory}/.cargo"
      "${config.home.homeDirectory}/.ccache"
      "${config.home.homeDirectory}/.npm"
      "${config.home.homeDirectory}/.pgrx"
    ];
    exclude_if_present = [ ".nobackup" ".borgignore" ];
    keep_within = "2d";
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 3;
    # Passphrase file written by sops (floki/meh) or manually created (arnold/other)
    encryption_passphrase_command = "cat ${config.home.homeDirectory}/.config/borgmatic/.passphrase";
    # Use default SSH agent key (1Password agent provides the rsync.net key)
    ssh_command = "ssh -o IdentitiesOnly=no";
  };
in
{
  home.packages = [ pkgs.borgbackup pkgs.borgmatic ];

  # Write borgmatic config
  home.file.".config/borgmatic/config.yaml".text = builtins.toJSON borgmaticConfig;

  # Systemd user service: run borgmatic create + prune
  systemd.user.services.borgmatic = {
    Unit = {
      Description = "borgmatic backup";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      # BORG_PASSPHRASE injected at runtime — set via:
      #   systemctl --user set-environment BORG_PASSPHRASE="$(sops -d --extract '["backup"]["borg-passphrase"]' /path/to/secrets.yaml)"
      # or add to ~/.config/environment.d/borg.conf (managed below)
      ExecStart = "${pkgs.borgmatic}/bin/borgmatic create --stats --list";
      ExecStartPost = "${pkgs.borgmatic}/bin/borgmatic prune --list";
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
    };
  };

  # Systemd timer: daily at 02:30, randomised ±30 min
  systemd.user.timers.borgmatic = {
    Unit.Description = "borgmatic backup timer";
    Timer = {
      OnCalendar = "02:30";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
