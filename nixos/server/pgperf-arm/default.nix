# pgperf-arm — EC2 Graviton (aarch64) PostgreSQL performance-test host.
# Target: the fastest current Graviton metal/large instance (e.g. r8g.metal
# / r8g.48xlarge) for at-scale DB benchmarks. Managed via Colmena (deploy)
# and built as an AMI via nixos-generators (mkEc2Image, platform aarch64).
{ modulesPath, ... }:
{
  imports = [
    # The EC2/amazon image profile: cloud bootloader, growpart, ec2 metadata
    # + SSH key import — the cloud equivalent of hardware-configuration.nix.
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../../_mixins/perf-test.nix
    ../../_mixins/services/tailscale-autoconnect.nix
  ];

  networking.hostName = "pgperf-arm";
  nixpkgs.hostPlatform = "aarch64-linux";

  # Headless server: SSH only, key-based.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
}
