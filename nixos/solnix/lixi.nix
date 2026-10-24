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
    shell = "/usr/bin/ksh93";
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };

  # AX211 (iwx), bound at boot. Joining is still manual: the solnix-wifi-join service reads
  # hardware.wirelessIwm.networks only, and iwx has no networks option yet. After boot:
  #   wpa-pmk -f /etc/wifi/sedgwick.psk sedgwick iwx0      (the PSK file: root, 0600, never in the store)
  hardware.wirelessIwx = {
    enable = true;
    attachAtBoot = true;
    allowUnfreeFirmware = true;
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

  # No ena0 here; DHCP on the wifi link once joined. DNS from the lease.
  networking.interfaces = { ena0.dhcp = false; iwx0.dhcp = true; };
  networking.nameservers = lib.mkForce [ ];
}
