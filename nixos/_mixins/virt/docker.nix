{ pkgs, lib, config, ... }: {

  # https://nixos.wiki/wiki/Docker
  environment.systemPackages = with pkgs; [ docker-compose ];

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

}
