{ hostname, pkgs, username, ... }: {
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=/home/${username}/Syncthing/Devices/${hostname}"
      "--data=/home/${username}/Syncthing/DB/${hostname}"
      # GUI on loopback only. The admin UI has no auth by default; binding
      # 0.0.0.0 exposed it to every network the host joins (incl. public
      # WiFi). Reach it remotely via tailscale or an SSH tunnel
      # (ssh -L 8384:127.0.0.1:8384 <host>).
      "--gui-address=127.0.0.1:8384"
      "--no-default-folder"
      "--no-browser"
    ];
    tray = {
      enable = true;
      package = pkgs.unstable.syncthingtray;
    };
  };
}
