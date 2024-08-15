{ desktop, lib, pkgs, ... }:
{
  imports = lib.optional (builtins.isString desktop) ./desktop.nix;

  #https://nixos.wiki/wiki/Docker
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
  ];

  virtualisation = {
    docker.enable = true;
    docker.storageDriver = lib.mkDefault "overlay2";
    # docker.rootless = { TODO
    #   enable = true;
    #   setSocketVariable = true;
    # };
  };
}
