{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ tailscale ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Allow acting as subnet router or exit node
    extraUpFlags = [ "--advertise-exit-node" ];
  };

  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  # Optimize UDP GRO forwarding for Tailscale throughput
  # (fixes "UDP GRO forwarding is suboptimally configured" warning)
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };

  # Apply ethtool GRO settings on network interfaces at boot
  systemd.services.tailscale-udp-gro = {
    description = "Enable UDP GRO for Tailscale forwarding performance";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.ethtool pkgs.iproute2 ];
    script = ''
      for iface in $(ip -o link show up | awk -F': ' '{print $2}' | grep -v '^lo$\|^tailscale'); do
        ethtool -K "$iface" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
      done
    '';
  };
}
