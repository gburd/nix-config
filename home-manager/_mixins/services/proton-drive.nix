{ config, pkgs, ... }:
{
  home.packages = [ pkgs.rclone pkgs.fuse ];

  xdg.configFile."rclone/rclone.conf".text = ''
    [protondrive]
    type = webdav
    url = https://webdav.protonmail.com
    vendor = other
    user = $(cat ${config.sops.secrets."drive/proton/user".path})
    pass = $(cat ${config.sops.secrets."drive/proton/pass".path})
  '';

  systemd.user.services.proton-drive-mount = {
    Unit = {
      Description = "Mount Proton Drive via rclone";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/ProtonDrive";
      ExecStart = "${pkgs.rclone}/bin/rclone mount protondrive: %h/ProtonDrive --vfs-cache-mode writes --allow-other";
      ExecStop = "${pkgs.fuse}/bin/fusermount -u %h/ProtonDrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.file."ProtonDrive/.keep".text = "";
}
