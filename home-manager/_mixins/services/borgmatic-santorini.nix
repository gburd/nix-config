# borgmatic-santorini — BorgBackup for the Windows host "santorini",
# executed from INSIDE the WSL NixOS distro against the Windows drives
# mounted at /mnt/c.
#
# WHY THIS IS A SEPARATE MODULE (not the shared services/borgmatic.nix):
#   - santorini's real data lives on the WINDOWS side (C:\Users\gburd,
#     C:\Users\gregb, C:\bf), reachable from WSL at /mnt/c/... — not in the
#     WSL Linux home the shared module backs up.
#   - WSL2 cannot be launched from an SSH session or a session-less
#     scheduled task (confirmed on this host: Wsl/Service/E_UNEXPECTED). It
#     runs only inside an interactive `gburd` session or a Task Scheduler
#     task registered WITH stored credentials (LogonType=Password / S4U).
#     So the systemd-user *timer* the other hosts use won't fire here (the
#     WSL VM, hence its systemd, is only up while someone/something drives
#     it). Instead a WINDOWS scheduled task invokes `wsl.exe ... borgmatic`.
#
# WHAT'S SHARED WITH THE FLEET:
#   - Same rsync.net repo (ssh://zh6216@zh6216.rsync.net/./borg), same
#     archive layout, retention, compression, borg1 remote_path.
#   - Same sops secrets (backup/borg-passphrase, backup/rsync-ssh-key,
#     backup/borg-keyfile) deployed into ~/.config/borgmatic in WSL.
#   - Same reliability knobs (checkpoint_interval, ssh keepalives, -F none).
#
# ONE-TIME SETUP (see the block comment at the bottom of this file):
#   1. add sops secrets for santorini, `nixos-rebuild switch` inside WSL,
#   2. `borg init` is NOT needed — the repo already exists (shared); just
#      import the existing keyfile (sops deploys it),
#   3. install the Windows scheduled task (install-windows-task.ps1, emitted
#      into ~/.config/borgmatic/).
{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory; # WSL home, holds config + secrets only
  cfgDir = "${home}/.config/borgmatic";

  # Windows source roots, as seen from WSL.
  windowsSources = [
    "/mnt/c/Users/gburd"
    "/mnt/c/Users/gregb"
    "/mnt/c/bf" # build-farm client-code + animal .conf files (small, precious)
  ];

  # santorini-specific Windows-path excludes (build_root c:/build, caches,
  # build outputs). Same load-and-filter approach as the rubo77 set.
  santoriniExcludePatterns =
    let
      raw = builtins.readFile ./borgmatic-santorini-excludes.txt;
      lines = lib.splitString "\n" raw;
      stripped = map (l: lib.removeSuffix "\r" l) lines;
      keep = l:
        let s = lib.strings.trim l;
        in s != "" && !(lib.hasPrefix "#" s);
    in
    map lib.strings.trim (builtins.filter keep stripped);

  borgmaticConfig = {
    source_directories = windowsSources;
    repositories = [
      {
        path = "ssh://zh6216@zh6216.rsync.net/./borg";
        label = "rsync-net";
      }
    ];
    archive_name_format = "{hostname}-{now:%F-%T}";
    compression = "auto,zstd,7";
    exclude_patterns = santoriniExcludePatterns;
    # Drop any tree a user tags with a marker file (matches the fleet).
    exclude_if_present = [ ".nobackup" ".borgignore" ];
    # Windows paths are case-insensitive; make borg match that way so an
    # exclude of `Local Settings` also catches `local settings`, etc.
    # (borgmatic passes this through to `borg create`.)
    # NOTE: borg has no global case-insensitive flag; patterns above are
    # written to match the real on-disk casing. Left here as a reminder.

    keep_within = "2d";
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 3;

    checkpoint_interval = 300;
    lock_wait = 60;

    encryption_passcommand = "${pkgs.coreutils}/bin/cat ${cfgDir}/.passphrase";
    remote_path = "borg1";
    ssh_command = "${pkgs.openssh_gssapi}/bin/ssh -F none -i ${cfgDir}/.rsync-key -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o PreferredAuthentications=publickey -o LogLevel=ERROR -o ServerAliveInterval=60 -o ServerAliveCountMax=10";
  };

  # Wrapper the Windows scheduled task runs (via wsl.exe -d NixOS --user gburd
  # -- <this>). Keeps the invocation on the Windows side trivial and lets us
  # add pre/post logic (VSS could go here later) without touching the task.
  runBackup = pkgs.writeShellScript "santorini-borg-backup" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.borgbackup pkgs.borgmatic pkgs.openssh_gssapi pkgs.coreutils ]}:$PATH
    log=${cfgDir}/last-run.log
    echo "=== borgmatic run $(date -Is) ===" > "$log"
    # create then prune, same as the fleet's systemd service.
    borgmatic create --stats --list >> "$log" 2>&1
    borgmatic prune  --list          >> "$log" 2>&1
    echo "=== done $(date -Is) rc=$? ===" >> "$log"
  '';

  # PowerShell installer for the Windows scheduled task. Emitted into the
  # config dir; run ONCE from an elevated Windows PowerShell (it needs the
  # gburd password to store credentials so the task runs while logged out).
  #
  #   powershell -ExecutionPolicy Bypass -File \
  #     \\wsl$\NixOS\home\gburd\.config\borgmatic\install-windows-task.ps1
  installTaskPs1 = ''
    # Registers "borgmatic-santorini": runs the WSL borg backup nightly at
    # 04:00, whether or not gburd is logged in (stored credentials -> a real
    # user session WSL2 can start in).
    param([string]$User = "$env:COMPUTERNAME\gburd")
    $ErrorActionPreference = "Stop"
    $wslCmd = 'wsl.exe -d NixOS --user gburd -- ${runBackup}'
    $action  = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c $wslCmd"
    $trigger = New-ScheduledTaskTrigger -Daily -At 4:00AM
    $settings = New-ScheduledTaskSettingsSet `
      -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
      -StartWhenAvailable -WakeToRun `
      -ExecutionTimeLimit (New-TimeSpan -Hours 6) `
      -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 30)
    # LogonType=Password so it runs logged-out; prompts for the password once.
    $cred = Get-Credential -UserName $User -Message "gburd password (stored so backup runs while logged out)"
    Register-ScheduledTask -TaskName "borgmatic-santorini" -Action $action `
      -Trigger $trigger -Settings $settings `
      -User $cred.UserName -Password $cred.GetNetworkCredential().Password `
      -RunLevel Limited -Force
    Write-Host "Installed. Test now with:  schtasks /Run /TN borgmatic-santorini"
    Write-Host "Log (from WSL): ~/.config/borgmatic/last-run.log"
  '';
in
{
  home.packages = [ pkgs.borgbackup pkgs.borgmatic pkgs.openssh_gssapi ];

  home.file.".config/borgmatic/config.yaml".text = builtins.toJSON borgmaticConfig;
  home.file.".config/borgmatic/install-windows-task.ps1".text = installTaskPs1;
  # Convenience: the wrapper path, so you can `cat` it to see what the task runs.
  home.file.".config/borgmatic/run-backup-path.txt".text = "${runBackup}\n";

  # NO systemd timer here (unlike the shared module): the WSL VM isn't
  # continuously running, so a WSL-internal timer can't fire reliably. The
  # Windows scheduled task is the trigger. See the header comment.

  # ---- ONE-TIME SETUP -----------------------------------------------------
  # 1. Add santorini's sops secrets (in nixos/wsl/santorini/secrets.yaml,
  #    or reuse an existing secrets file) and wire them in santorini.nix:
  #        backup/borg-passphrase -> ~/.config/borgmatic/.passphrase
  #        backup/rsync-ssh-key   -> ~/.config/borgmatic/.rsync-key   (0600)
  #        backup/borg-keyfile    -> ~/.config/borg/keys/zh6216_rsync_net__borg (0600)
  # 2. Inside WSL:  sudo nixos-rebuild switch --flake ~/ws/nix-config#santorini
  # 3. Verify borg can reach the repo (repo already exists; do NOT re-init):
  #        borgmatic rlist --repository ssh://zh6216@zh6216.rsync.net/./borg
  # 4. From elevated Windows PowerShell, install the scheduled task:
  #        powershell -ExecutionPolicy Bypass -File `
  #          \\wsl$\NixOS\home\gburd\.config\borgmatic\install-windows-task.ps1
  # 5. First run:  schtasks /Run /TN borgmatic-santorini
  #    then check ~/.config/borgmatic/last-run.log inside WSL.
}
