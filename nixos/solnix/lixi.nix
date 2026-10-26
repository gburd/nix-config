# nixos/solnix/lixi.nix -- lixi, the maintainer's ThinkPad X1 Extreme Gen 5 (21DE: i9-12900H, Iris Xe 8086:46a6,
# RTX 3080 Ti 10de:2420, Intel AX211 wifi 8086:51f0, WD SN810 NVMe), running solnix (Nix on illumos).
#
#   solnix-install --git https://codeberg.org/gregburd/nix-config.git \
#                  --flake .#lixi --home-manager .#gburd@dixi
#
# Evaluated by lib/helpers.nix:mkSolnixHost through solnix's own evaluator. It EVALUATES on a Linux dev box and only
# BUILDS on an illumos host.
#
# WHAT IS PROVEN ON THIS MACHINE (solnix docs: x1e-wifi-runtime-bind.md, x1e-gpu-runtime-bind.md):
#   * the live installer boots to multi-user and ssh; the dGPU is powered off at boot (default) and the thermal
#     shutdown path works (tzmon re-sends SIGPWR; never disable it);
#   * iwx attaches to the AX211 and scans (registered as iwx0) when bound at runtime; joining needs the PSK;
#   * i915 has NEVER attached here. It ships unbound; the first attach is the supervised stage-B plan.
# So: wifi is bound at boot here (opt-in, the hardware has shown it works), the GPUs are not.
# No wired NIC: the X1E has no RJ45. The network is iwx0 or a USB-C ethernet adapter (usbecm).
{ inputs, sshMatrix, pkgs, lib, ... }:

{
  imports = [ "${inputs.solnix}/configurations/base.nix" ];

  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    description = "Greg Burd";
    extraGroups = [ "sysadmin" ];
    profiles = [ "Primary Administrator" ];
    # bash, as on the Linux hosts since b00d562 (base.nix ships bash; /usr/bin is the system sw/bin).
    shell = "/usr/bin/bash";
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };

  # AX211 (iwx), bound at boot, joins sedgwick at boot (site/solnix-wifi-join-iwx, solnix b0e4974).
  hardware.wirelessIwx = {
    enable = true;
    attachAtBoot = true;
    allowUnfreeFirmware = true;
    # The passphrase lives only on lixi: root 0600, first line. Joined in-kernel (WPA2 4-way), then DHCP on iwx0.
    networks.sedgwick.pskFile = "/etc/wifi/sedgwick.psk";
  };

  # GPUs: shipped, bound to nothing. Flip i915.attachAtBoot only after stage B of x1e-gpu-runtime-bind.md passes.
  hardware.graphics.i915.attachAtBoot = false;

  # Build toolchain on the machine, like dixi.
  environment.systemPackages = with pkgs.solnix; [ home-manager solnix-dev-full ];
  system.buildCapable = true;

  solnix.dumpadm = {
    enable = true;
    device = "/dev/zvol/dsk/rpool/dump";
  };
  solnix.coreadm.developerUsers = [ "gburd" ];
  environment.enableDebugInfo = true;

  # Wired networking: a USB-C ethernet adapter (Belkin RTL8153 on usbecm). It attaches about 2 min after boot, and its
  # instance number is not stable (usbecm0 on one boot, usbecm1 on the next when its first connect failed), so DHCP runs
  # on whatever wired link appears (networking.useDHCP, as NixOS does) instead of a named one. solnix's bring-up waits
  # for it. ena0 (EC2's NIC, from base.nix) is off. iwx0 gets its own entry in the wifi step. DNS from the lease.
  networking.hostName = "lixi";
  networking.useDHCP = true;
  networking.interfaces = { ena0.dhcp = false; };
  networking.nameservers = lib.mkForce [ ];

  # EC2-only services from base.nix: off on a laptop. The first-boot IMDS key fetch retries (and times out) when there
  # is no instance metadata, and the MTU raise is for ena's jumbo frames. NixOS likewise only imports its amazon-image
  # module on EC2.
  solnix.cloud.ec2.firstBootAuthKeys = false;
  solnix.mtu.enable = false;
}
