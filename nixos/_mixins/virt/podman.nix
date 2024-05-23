{ config, desktop, lib, pkgs, ... }:
#let
#  dockerEnabled = config.virtualisation.docker.enable;
#in
{
  imports = lib.optional (builtins.isString desktop) ./desktop.nix;

  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    buildah
    distrobox
    fuse-overlayfs
    podman-compose
    podman-tui
  ];

  virtualisation = {
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true; #!dockerEnabled;
      #dockerSocket.enable = !dockerEnabled;
      enable = true;
      enableNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
    };
  };

  #  virtualisation.oci-containers.backend = lib.mkIf (!dockerEnabled) "podman";

  #  environment.extraInit = lib.mkIf (!dockerEnabled)
  #    ''
  #      if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
  #        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
  #      fi
  #    '';

}
