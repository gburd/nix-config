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
{ config, lib, pkgs, ... }:
let
  # rubo77/rsync-homedir-excludes — vendored snapshot of
  # https://raw.githubusercontent.com/rubo77/rsync-homedir-excludes/master/rsync-homedir-excludes.txt
  # sha256: 3f73592de0903df36a30842914b3a82af94a666c1da4bce9258195b3b910fb77
  # To refresh:
  #   curl -fsS https://raw.githubusercontent.com/rubo77/rsync-homedir-excludes/master/rsync-homedir-excludes.txt \
  #     -o home-manager/_mixins/services/borgmatic-excludes-rubo77.txt
  #   sha256sum home-manager/_mixins/services/borgmatic-excludes-rubo77.txt   # update the comment above
  #
  # Format conversion (rsync syntax → borg patterns):
  #   - Lines starting with `/`         → `${h}<line>`           (anchored to home)
  #   - Lines without a leading `/`     → `sh:${h}/**/<line>`    (match anywhere; sh: enables `**` across path separators, fm: does not)
  # Empty lines and `#`-comments are skipped.
  rubo77ExcludePatterns =
    let
      h = config.home.homeDirectory;
      raw = builtins.readFile ./borgmatic-excludes-rubo77.txt;
      lines = lib.splitString "\n" raw;
      stripped = map (l: lib.removeSuffix "\r" l) lines;
      keep = l:
        let s = lib.strings.trim l;
        in s != "" && !(lib.hasPrefix "#" s);
      patterns = builtins.filter keep stripped;
      toBorg = l:
        let
          # Strip rsync's trailing-slash "directory-only" marker; borg paths
          # don't end with `/`, so the trailing slash would silently match
          # nothing.
          s = lib.removeSuffix "/" (lib.strings.trim l);
        in if lib.hasPrefix "/" s
           then "${h}${s}"
           else "sh:${h}/**/${s}";
    in
      map toBorg patterns;

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
      ] ++ rubo77ExcludePatterns;
    exclude_if_present = [ ".nobackup" ".borgignore" ];
    keep_within = "2d";
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 3;
    # Reliability knobs: a `borg create` of ~1.2T home with 3.35M chunks spends
    # significant time scanning files locally; if no SSH traffic flows during
    # that window, rsync.net's borg1 server closes the connection ("Connection
    # closed by remote host", exit 81). Two complementary defences:
    #   - SSH keepalives (in ssh_command below) keep the channel alive.
    #   - checkpoint_interval commits an intermediate archive every 5 minutes,
    #     so partial progress survives an interrupted run; subsequent runs
    #     resume rather than restart from zero.
    # lock_wait gives concurrent runs a chance to finish rather than failing
    # immediately on a stale lock.
    checkpoint_interval = 300;
    lock_wait = 60;
    # Passphrase file written by sops (floki/meh) or manually created (arnold/other)
    # Use absolute path to coreutils/cat: systemd user units inherit a minimal
    # PATH (just systemd's own bin dir on some hosts, e.g. meh), causing
    # `cat` to fail with `[Errno 2] No such file or directory: 'cat'` when
    # borgmatic spawns the passcommand subprocess.
    encryption_passcommand = "${pkgs.coreutils}/bin/cat ${config.home.homeDirectory}/.config/borgmatic/.passphrase";
    # rsync.net uses "borg1" for borg 1.x server-side binary
    remote_path = "borg1";
    # Use sops-deployed rsync.net key (works unattended without 1Password).
    # Pin ssh to openssh_gssapi explicitly: on Fedora (arnold), system-wide
    # /etc/ssh/ssh_config.d/50-redhat.conf includes
    # /etc/crypto-policies/back-ends/openssh.config which sets
    # `GSSAPIKexAlgorithms`. Plain nixpkgs openssh lacks the GSSAPI-kex patch
    # and refuses that option ("Bad configuration option:
    # gssapikexalgorithms"), aborting every connection. openssh_gssapi is the
    # same OpenSSH + GSSAPI-kex patch, so it parses the file cleanly. Using
    # the absolute path here also sidesteps the systemd-user PATH issue (see
    # encryption_passcommand above).
    #
    # `LogLevel=ERROR` overrides the user's global `~/.ssh/config` setting of
    # `LogLevel QUIET`, which previously silenced auth failures and made borg
    # report only the misleading "Connection closed by remote host" — hiding
    # 3+ weeks of broken backups behind that single line. ERROR keeps normal
    # operation quiet but still surfaces real failures (Permission denied,
    # etc.). ServerAliveInterval/CountMax keep the channel alive across long
    # local-scan phases so rsync.net doesn't drop us as idle.
    ssh_command = "${pkgs.openssh_gssapi}/bin/ssh -i ${config.home.homeDirectory}/.config/borgmatic/.rsync-key -o IdentitiesOnly=yes -o LogLevel=ERROR -o ServerAliveInterval=60 -o ServerAliveCountMax=10";
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
