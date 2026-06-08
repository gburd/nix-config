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
    # nixpkgs' default `docker` attr still tracks 28.x, which is flagged
    # unmaintained (EOL Nov 2025) and fails eval. Pin the maintained line.
    docker.package = pkgs.docker_29;
    docker.storageDriver = lib.mkDefault "overlay2";
    # docker.rootless = { TODO
    #   enable = true;
    #   setSocketVariable = true;
    # };
  };
}
