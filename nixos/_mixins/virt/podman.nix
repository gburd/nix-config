{ config, desktop, lib, pkgs, ... }:
let
  dockerEnabled = config.virtualisation.docker.enable;
in
{

  # https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    unstable.distrobox
    podman-compose
    podman-tui
  ] ++ lib.optionals (desktop != null) [
    unstable.pods
    podman-desktop
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = !dockerEnabled;
    dockerSocket.enable = !dockerEnabled;
    defaultNetwork.settings.dns_enabled = true;
    enableNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
  };

  virtualisation.oci-containers.backend = lib.mkIf (!dockerEnabled) "podman";

  environment.extraInit = lib.mkIf (!dockerEnabled)
    ''
      if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
      fi
    '';

}
