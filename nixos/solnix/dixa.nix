# nixos/solnix/dixa.nix -- headless aarch64 solnix host on EC2.
#
# Evaluated by lib/helpers.nix:mkSolnixHost (solnix's evaluator, not nixosSystem).
#
# HONEST STATE OF aarch64 SOLNIX, so this file is not read as more than it is:
#
#   * The GICv3 interrupt-controller and ACPI `_CRS` fixes are CONFIRMED ON REAL
#     METAL -- that is a measured result, not a hope.
#   * A FULL USERLAND IS NOT BUILT. The aarch64 proto is banked at
#     s3://solnix-cache/ami/aarch64-proto-20260912/ and is a proto, not a set of
#     sliced derivations. There is no aarch64 equivalent of the x86_64
#     core-utils/oamuser/halt/zfs slices, so this config deliberately lists NO
#     illumos core-OS slices: naming x86_64 ones here would be an eval error at
#     best and a wrong-architecture closure at worst.
#   * So: expect this to EVALUATE. Do not expect it to build a bootable system
#     today. The gap is the userland, and it is a build campaign, not a config
#     change.
#
# Headless deliberately: no COSMIC, nothing graphical. This is a build/test node.
_:

{
  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    # illumos RBAC, not wheel -- see dixi.nix. The installer adds the
    # "Primary Administrator" profile; there is no module option for it.
    extraGroups = [ "sysadmin" ];
    # ksh93, not bash: bash is not in the illumos gate proto on any architecture.
    shell = "/usr/bin/ksh93";
  };

  # ena0 is the EC2 Nitro NIC. The metadata nameserver is EC2's own resolver.
  networking.interfaces.ena0.dhcp = true;
  networking.nameservers = [ "169.254.169.253" "8.8.8.8" ];

  # NO environment.systemPackages BEYOND WHAT base.nix ALREADY GIVES.
  #
  # This is the deliberate consequence of the note above: pkgs.solnix.starter is
  # keyed off docs/registry/real-derivations.tsv, whose published rows are
  # x86_64-solaris. Listing starter packages here would either fail to resolve or
  # silently pull the wrong architecture, and a wrong-architecture store path in a
  # toplevel is exactly the class of bug that only shows up at boot.
  #
  # Add packages here when aarch64 rows are published to the registry, not before.
}
