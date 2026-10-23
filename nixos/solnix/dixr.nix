# nixos/solnix/dixr.nix -- dixr, the aarch64 solnix host on EC2 Graviton.
#
# HONEST STATE (2026-10-23): this EVALUATES and does not build a bootable system.
#   * aarch64 solnix boots on c6g.metal through root mount (GICv3 ITS, ECAM, NVMe
#     MSIs all fixed on real metal); the console then goes silent, so sshd has not
#     been reached and there is no aarch64 AMI.
#   * There is no aarch64 nix or userland built from source, so pkgs.solnix has no
#     aarch64 packages to list. Add packages here when it does, not before.
# The Milk-V board that used to be called dixr is nixos/solnix/lixr.nix.
{ sshMatrix, ... }:

{
  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    description = "Greg Burd";
    extraGroups = [ "sysadmin" ];
    shell = "/usr/bin/ksh93";
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };

  # Graviton's NIC is ena0, as on x86 EC2; EC2's own resolver.
  networking.interfaces.ena0.dhcp = true;
  networking.nameservers = [ "169.254.169.253" ];
}
