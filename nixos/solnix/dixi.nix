# nixos/solnix/dixi.nix -- dixi, the x86_64 solnix host on EC2 (Nix on illumos).
#
# Launched from the public "Solnix 2026.11 (DP)" AMI, then switched to this config:
#
#   solnix-install --git https://codeberg.org/gregburd/nix-config.git \
#                  --flake .#dixi --home-manager .#gburd@dixi
#
# or, on a running dixi: solnix-rebuild switch --flake .#dixi (nixos-rebuild works too).
#
# Evaluated by lib/helpers.nix:mkSolnixHost through solnix's own evaluator, NOT
# nixosSystem. It EVALUATES on a Linux dev box and only BUILDS on an illumos host.
# The ThinkPad X1 Extreme Gen 1 that used to be called dixi is nixos/solnix/arnold.nix (lixi.nix is the Gen 5).
{ inputs, pkgs, sshMatrix, ... }:

{
  # The public-AMI system: base.nix (sshd, nix-daemon, the ten CLI tools, man pages)
  # + IMDS first-boot keypair fetch + the boot-safe 1500 MTU (no self-reboot).
  imports = [ "${inputs.solnix}/configurations/cloud-ec2.nix" ];

  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    description = "Greg Burd";
    # illumos RBAC, not wheel: "Primary Administrator" makes `pfexec <cmd>`
    # root-equivalent; sysadmin (gid 14) is the group half.
    extraGroups = [ "sysadmin" ];
    profiles = [ "Primary Administrator" ];
    # ksh93: bash is not in the gate proto. The home-manager profile adds bash
    # for interactive use; the login shell must exist before the first switch.
    shell = "/usr/bin/ksh93";
    # Key login only. No password hash in a git-tracked file.
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };

  # A build host: from-source gcc 14 + binutils + make + pkg-config, so dixi can
  # rebuild solnix packages itself. buildCapable admits the toolchain into the
  # runtime closure (the toplevel's disallowed-refs gate fails otherwise).
  environment.systemPackages = with pkgs.solnix; [ git home-manager solnix-dev-full ];
  system.buildCapable = true;

  # Crash dumps: DISABLED by default. The dump device is pool- and size-
  # specific (the DP AMI roots on `spool`, ~7.5 GiB, not `rpool`; an 8 GiB
  # dump zvol doesn't fit until the pool is expanded onto the 32 GiB EBS root
  # and/or the instance-store NVMe). Re-enable per deployment once a dump zvol
  # exists, e.g.:
  #   zpool set autoexpand=on spool && zpool online -e spool c1t1d0
  #   zfs create -V 8G spool/dump
  # then set enable = true and device = "/dev/zvol/dsk/spool/dump".
  solnix.dumpadm.enable = false;
  solnix.coreadm.developerUsers = [ "gburd" ];

  environment.enableDebugInfo = true;

  # ena0 + EC2's resolver come from base.nix; nothing to override on EC2.
}
