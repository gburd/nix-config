# pgperf-x86 — EC2 x86_64 PostgreSQL performance-test host.
# Target: the fastest current x86 metal/large instance (e.g. r8i.metal-48xl
# / m7i.metal-48xl) for at-scale DB benchmarks. Managed via Colmena (deploy)
# and built as an AMI via nixos-generators (mkEc2Image, platform x86_64).
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../../_mixins/perf-test.nix
    ../../_mixins/services/tailscale-autoconnect.nix
  ];

  networking.hostName = "pgperf-x86";
  nixpkgs.hostPlatform = "x86_64-linux";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
}
