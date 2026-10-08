# nixos/solnix/dixi.nix -- the maintainer's Lenovo X1 Carbon, running solnix
# (Nix on illumos). The target of:
#
#   solnix-install --git https://github.com/gburd/nix-config.git \
#                  --flake .#dixi --home-manager .#gburd@dixi
#
# Evaluated by lib/helpers.nix:mkSolnixHost through solnix's own evaluator, NOT
# nixosSystem -- see that function's header for why.
#
# WHAT IS REAL HERE, AND WHAT IS NOT. Read this before believing the file:
#
#   * The illumos CORE-OS slices below (core-utils / oamuser / halt / zfs) are
#     REAL derivations carved from the gate proto with a COMPUTED DT_NEEDED
#     closure, and they were BUILT on illumos. df, useradd, reboot, zpool are
#     genuinely store paths.
#   * This config EVALUATES on a Linux dev box and only BUILDS on an illumos
#     host. `nix eval` succeeding is not a build; a build is not a boot.
#   * COSMIC is wired below and is NOT a working desktop -- see the block there.
{ inputs, lib, pkgs, ... }:

{
  # solnix's base system: sshd (UsePAM yes), nix + nix-daemon settings, /etc/system.
  imports = [ "${inputs.solnix}/configurations/base.nix" ];

  # /home, not /export/home. FreeBSD's bsdinstall makes a plain
  # `/home mountpoint=/home` dataset so homes are common to all boot
  # environments -- the same reason Solaris uses /export/home, without the
  # indirection.
  #
  # /home is chosen at INSTALL time, not here: solnix has no `solnix.home.style`
  # option (checked modules/config/), and setting an option that does not exist
  # is an eval error. The installer's SOLNIX_HOME_STYLE / interactive prompt owns
  # it. Recording the gap beats inventing an option that silently does nothing.
  #
  # WARNING: Whichever is chosen, /home needs THREE things and a dataset is only one of
  # them: the dataset, the autofs SERVICE disabled, and the `/home` line in
  # /etc/auto_master commented. autofs owns /home via auto_master, so a dataset
  # alone is silently shadowed at boot and every home directory vanishes. The
  # installer does all three.

  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    # illumos has NO `wheel` and sudo is not in illumos-gate. The native
    # root-equivalent is the RBAC "Primary Administrator" profile (prof_attr
    # defines it uid=0;gid=0); `sysadmin` (gid 14) is the group half. pfexec is
    # the native privilege-escalation command. The installer grants the RBAC
    # profile, which this module set has no option for.
    extraGroups = [ "sysadmin" ];
    # The RBAC half (user_attr profiles=), so `pfexec <cmd>` is root-equivalent.
    profiles = [ "Primary Administrator" ];
    # WARNING: /usr/bin/ksh93, NOT bash: BASH IS NOT IN THE GATE PROTO AT ALL. `find`
    # over the whole proto for a file named bash returns nothing -- it is an
    # OpenIndiana package, not illumos core-OS. A config naming /bin/bash
    # produces an account that cannot log in.
    shell = "/usr/bin/ksh93";
    # No password hash here on purpose: a hash in a git-tracked config is a
    # hazard. The installer prompts for it.
  };

  # WARNING: COSMIC ON THIS MACHINE IS NOT A WORKING DESKTOP. Stated plainly because
  # the option name reads like it is:
  #
  #   * ~25-36 COSMIC applications COMPILE for x86_64-illumos and the shell
  #     RENDERS. cosmic-term has been run.
  #   * NOTHING HAS EVER RUN AGAINST A LIVE COMPOSITOR. cosmic-comp does not
  #     build on illumos (it is hard-coupled to DRM/GBM); smallvil is a prebuilt
  #     binary, not a derivation, which is why `compositor` is a STRING PATH --
  #     the module refuses to pretend it has a package.
  #   * THE X1 HAS NO WORKING GPU DRIVER. It shows `vgatext` only -- there is no
  #     i915 on illumos -- so the ceiling here is llvmpipe SOFTWARE rendering,
  #     and that is the optimistic case.
  #
  # So this installs the apps and the session environment. Expect no desktop.
  # `compositor` is deliberately left null: the module warns when it is null, and
  # that warning is accurate.
  solnix.desktop.cosmic.enable = false;

  # What a `home-manager switch --flake .#gburd@dixi` needs present BEFORE it can
  # run. nix itself comes from solnix's modules/config/nix.nix. git and curl are
  # built from source by solnix (pkgs/illumos/base-src.nix, nix-src.nix); the
  # cache-only pkgs.solnix.starter.{git,curl} were retired from the cache. df,
  # useradd, reboot, zpool (the old core-utils/oamuser/halt/zfs slices) are in the
  # illumos world every solnix system ships, so they are not listed.
  environment.systemPackages = with pkgs.solnix; [ git curl ];

  # WARNING: NETWORK IS A HARD PREREQUISITE AND WIFI CANNOT SATISFY IT ON THIS MACHINE.
  # The Intel AX2xx has no illumos driver and no OpenSolaris-family fork has one
  # (illumos-gate, omnios, joyent, nexenta all checked -- newest Intel support is
  # the iwn/iwp 6000-series era; zero forks claim 0x2723/0x2725/0x02f0), and the
  # OpenBSD iwx port was abandoned after measuring that it needs a BSD
  # network-interface layer illumos never had.
  #
  # USB-ETHERNET IS THE ANSWER. illumos has four USB-ethernet drivers and all are
  # Fast Ethernet: axf (ASIX AX88172/88178/88772), udmf (Davicom DM9601E), upf
  # (Prolific), urf (Realtek RTL8150). NONE claims RTL8153, which is what a modern
  # Lenovo dongle usually is -- so an ASIX AX88772-based adapter is the safe buy.
  #
  # The X1's ONBOARD wired NIC is e1000g0 (measured on this machine with
  # `dladm show-phys`); a USB dongle would appear as axf0/udmf0/upf0/urf0. solnix's
  # base.nix enables EC2's ena0, which this machine does not have.
  networking.interfaces = { ena0.dhcp = false; e1000g0.dhcp = true; };
  # DNS comes from the LAN's DHCP lease, not from this file. base.nix sets EC2's
  # resolver (169.254.169.253); an empty list generates no /etc/resolv.conf, so
  # the lease's servers are used.
  networking.nameservers = lib.mkForce [ ];
}
