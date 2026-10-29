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
  imports = [ "${inputs.solnix}/configurations/cloud-ec2.nix" ./community.nix ];

  users.users.gburd = {
    uid = 1000;
    createHome = true;   # /home/gburd must be gburd's even when data's ~/ws and ~/src mount under it first
    home = "/home/gburd";
    group = "staff";
    description = "Greg Burd";
    # illumos RBAC, not wheel: "Primary Administrator" makes `pfexec <cmd>`
    # root-equivalent; sysadmin (gid 14) is the group half.
    extraGroups = [ "sysadmin" ];
    profiles = [ "Primary Administrator" ];
    # bash, as on the Linux hosts and lixi, by the NixOS path (users.defaultUserShell is
    # /run/current-system/sw/bin/bash there), which is what the live account already has.
    shell = "/run/current-system/sw/bin/bash";
    # Key login only. No password hash in a git-tracked file.
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
  };

  # A build host: from-source gcc 14 + binutils + make + pkg-config, so dixi can
  # rebuild solnix packages itself. buildCapable admits the toolchain into the
  # runtime closure (the toplevel's disallowed-refs gate fails otherwise).
  environment.systemPackages = with pkgs.solnix; [ git home-manager solnix-dev-full ];
  system.buildCapable = true;

  # Crash dumps: the DP image's root pool fills its EBS volume, and site/solnix-dump-size sizes spool/dump to the
  # instance at boot (half of RAM, 1..16G, at most a quarter of the pool: 7G on 31.5G; solnix b33bdcb), so the
  # generation only has to name it.
  solnix.dumpadm = { enable = true; device = "/dev/zvol/dsk/spool/dump"; };
  solnix.coreadm.developerUsers = [ "gburd" ];

  environment.enableDebugInfo = true;

  # NixOS gives wheel admins daemon trust (nix.settings.trusted-users = [ "root" "@wheel" ]);
  # illumos has no wheel, so name the admin.
  nix.settings.trusted-users = [ "root" "gburd" ];

  # The instance-store NVMe: scratch, WIPED on every stop (a reboot keeps it). solnix-ephemeral-pool recreates `data`
  # on the next boot when the disk is blank and refuses if it holds a label. Big build trees go here (build-dir).
  # dixi is an m6idn.8xlarge since the 2026-10-29 relaunch: ONE 1.7 TB instance-store disk (the old m6idn.12xlarge had two).
  solnix.ephemeralPool = {
    enable = true;
    disks = [ "c2t1d0" ];
    datasets = {
      home-gburd-ws = { mountpoint = "/home/gburd/ws"; owner = "gburd:staff"; };
      home-gburd-src = { mountpoint = "/home/gburd/src"; owner = "gburd:staff"; };
      scratch = { mountpoint = "/scratch"; owner = "gburd:staff"; };
      nix-tmp = { mountpoint = "/var/tmp/big"; mode = "1777"; };
    };
  };
  nix.settings.build-dir = "/var/tmp/big";

  # ena0 + EC2's resolver come from base.nix; nothing to override on EC2.
}
