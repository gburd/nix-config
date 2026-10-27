# nixos/solnix/dixa.nix -- headless aarch64 solnix host on EC2.
#
# Evaluated by lib/helpers.nix:mkSolnixHost (solnix's evaluator, not nixosSystem).
#
# STATE OF aarch64 SOLNIX (2026-10-27, solnix 915b3d7, docs/aarch64-nix-derivations-2026-10-26.md):
#   * There is a real-Nix aarch64 AMI, ami-07fbc4867d02c9b2b in the permanent account (us-west-2). nix 2.24.15,
#     gcc 14.3.0, git and the eleven tools are real aarch64-solaris derivations, the registry fetch works, and it
#     boots on c6g.metal (about 20 min; the first cycle is a boot-archive reboot). Launch dixa from it.
#   * Its toplevel is pkgs/illumos/aarch64/system.nix, NOT this module-system configuration. The solnix activation
#     module still hard-codes x86 paths and there are no aarch64 world/kernel slices. So THIS file evaluates (it
#     records the target: gburd, keys, the NIC, EC2's resolver), but its toplevel does not build yet, and
#     `solnix-rebuild switch --flake .#dixa` is not possible on dixa today.
#   * What works on dixa now: nix (single-user) and the home-manager half, gburd@dixa, built on the box.
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
