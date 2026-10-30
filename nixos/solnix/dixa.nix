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
#   * What works on dixa now (2026-10-28, track dixa1): multi-user nix (nix-daemon, nixbld1..32, hand-applied from
#     modules/config/nix.nix) and the home-manager half, gburd@dixa (mkSolnixHome, platform aarch64-solaris), built on the box
#     through the daemon. The aarch64 rtld gives every shared object's static TLS the same address (solnix
#     /scratch/solnix/dixa1/tls-finding.md), so a heavily threaded nix can still crash until the image's rtld is fixed.
#
# THE HOST NOW (2026-10-30, track dixa3): m6gd.8xlarge (Nitro VM, 32 vCPU, 128 GB) in us-west-2, 54.201.116.95 (private
#   172.31.16.120, the maintainer's account; not in dixi's VPC), from solnix-ami aarch64 v4 (ami-0e08aa06f629ffbac: m4 + the
#   Nitro-VM fixes + the full minor_perm; the TLS fix is in its rtld/libc). Disks: c1t1d0 10 GiB EBS (armpool: root AND /nix/store,
#   so watch its space), c2t1d0 1.7 TB instance store = pool `data` (ws, src, /scratch, /var/tmp, /var/tmp/big), WIPED on stop/start
#   (kept on reboot): after a stop, `zpool destroy -f data` and redo it. Host key restored from secrets.yaml (dixa_ssh_host_ed25519_key).
#   gburd@dixa built on dixa through its daemon and activated (needs the braich dev root + /opt/nixboot laid over /: its drvs name
#   /usr/bin/bash, /usr/gnu, /opt/ooce, /opt/nixboot).
# Hand-installed until an aarch64 module-system toplevel exists (then these become ./community.nix + modules/config/*):
#   modules/config/nix.nix       -> nixbld1..32, /etc/nix/nix.conf (as evaluated here), svc:/system/nix-daemon (TMPDIR=/var/tmp/big)
#   community/census.nix         -> site/solnix-census{,-setup} (as daemon; system aarch64-solaris, builder=true, seeding=false)
#   community/builder.nix        -> site/solnix-builder in project solnix-builder (cpu-cap 400) + the /etc/project line; the bearer
#                                   by hand. It plans every queue row OTHER-SYSTEM today: no aarch64 rows on recipes.tsv, and solnix's
#                                   flake has no packages.aarch64-solaris.
#   community/seed.nix, cache-proxy.nix: not installed (no solnix-torrent for aarch64).
#   shell-environment.nix        -> ~/.nix-profile/bin first in /etc/profile.
# No tailnet: tailscale has no aarch64 illumos build (GOOS=illumos is amd64 only).
#
# Headless deliberately: no COSMIC, nothing graphical. This is a build/test node.
{ sshMatrix, ... }:

{
  # As on dixi (the maintainer's live account on dixa 2026-10-30 had exactly this: bash, Primary Administrator, his keys).
  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    description = "Greg Burd";
    # illumos RBAC, not wheel: "Primary Administrator" makes `pfexec <cmd>` root-equivalent; sysadmin is the group half.
    extraGroups = [ "sysadmin" ];
    profiles = [ "Primary Administrator" ];
    shell = "/run/current-system/sw/bin/bash";
    # Key login only. No password hash in a git-tracked file.
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
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
