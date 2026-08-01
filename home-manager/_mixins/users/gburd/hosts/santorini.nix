{ inputs, lib, pkgs, config, ... }:
{
  # santorini — NixOS running as a WSL2 distro on the Windows host
  # "santorini". This home-manager profile (gburd, inside WSL) drives the
  # BorgBackup of the WINDOWS side (C:\Users\gburd, C:\Users\gregb, C:\bf)
  # via /mnt/c, triggered by a Windows scheduled task. See
  # services/borgmatic-santorini.nix for the full rationale.
  imports = [
    ../../../services/borgmatic-santorini.nix
  ];

  # Sops secrets — reuses floki's secrets.yaml (encrypted to gburd-user age
  # key), same pattern as arnold. Only the backup secrets are needed here.
  sops = {
    defaultSopsFile = "${inputs.self}/nixos/workstation/floki/secrets.yaml";
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      # Borgmatic backup secrets — mirrors floki/meh/arnold. Deployed into
      # the WSL home; the borgmatic-santorini module points at these paths.
      "backup/borg-passphrase" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.passphrase";
      };
      "backup/rsync-ssh-key" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.rsync-key";
        mode = "0600";
      };
      "backup/borg-keyfile" = {
        path = "${config.home.homeDirectory}/.config/borg/keys/zh6216_rsync_net__borg";
        mode = "0600";
      };
    };
  };
}
