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
{ config, pkgs, ... }:
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
    exclude_patterns =
      let h = config.home.homeDirectory; in [
        # Build tool caches (large, regenerable)
        "${h}/.cache"
        "${h}/.rustup"
        "${h}/.cargo"
        "${h}/.ccache"
        "${h}/.npm"
        "${h}/.pgrx"
        "${h}/.gradle/caches"
        "${h}/.m2/repository"
        "${h}/go/pkg/mod/cache"
        "${h}/.nv/GLCache"
        "${h}/.nvm"
        # Browser caches (regenerable, large)
        "${h}/.mozilla/firefox/*/Cache"
        "${h}/.mozilla/firefox/*/minidumps"
        "${h}/.config/google-chrome/*/Local Storage"
        "${h}/.config/google-chrome/*/Session Storage"
        "${h}/.config/google-chrome/*/Service Worker/CacheStorage"
        "${h}/.config/google-chrome/ShaderCache"
        "${h}/.config/BraveSoftware/Brave-Browser/ShaderCache"
        "${h}/.config/BraveSoftware/Brave-Browser/*/Service Worker/CacheStorage"
        "${h}/.config/chromium/*/Service Worker/CacheStorage"
        # Desktop/app caches
        "${h}/.local/share/Trash"
        "${h}/.local/share/baloo"
        "${h}/.local/share/zeitgeist"
        "${h}/.local/share/tracker"
        "${h}/.local/share/gvfs-metadata"
        "${h}/.thumbnails"
        "${h}/.var/app/*/cache"
        "${h}/.var/app/*/.cache"
        # IDE/editor caches
        "${h}/.config/Code/CachedData"
        "${h}/.config/Code/Cache"
        "${h}/.config/Code/logs"
        "${h}/.vscode/extensions"
        "${h}/.config/**/blob_storage"
        "${h}/.config/**/GPUCache"
        "${h}/.config/**/Code Cache"
        # Misc regenerable state
        "${h}/.gnupg/random_seed"
        "${h}/.ICEauthority"
        "${h}/.Xauthority"
        "${h}/nohup.out"
        # Nix store symlinks (huge, managed by nix)
        "${h}/.nix-profile"
        "${h}/.nix-defexpr"
        "${h}/.local/state/nix"
      ];
    exclude_if_present = [ ".nobackup" ".borgignore" ];
    keep_within = "2d";
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 3;
    # Passphrase file written by sops (floki/meh) or manually created (arnold/other)
    encryption_passcommand = "cat ${config.home.homeDirectory}/.config/borgmatic/.passphrase";
    # rsync.net uses "borg1" for borg 1.x server-side binary
    remote_path = "borg1";
    # Use sops-deployed rsync.net key (works unattended without 1Password)
    ssh_command = "ssh -i ${config.home.homeDirectory}/.config/borgmatic/.rsync-key -o IdentitiesOnly=yes";
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
