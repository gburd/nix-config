{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ tailscale ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Allow acting as subnet router or exit node
  };

  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
