# nixos/solnix/dixr.nix -- dixr, a hosted riscv64 solnix SERVER: headless, many cores, lots of RAM, no GPU.
#
# Where it runs (maintainer, 2026-10-24): most likely an EC2 instance running qemu-system-riscv64 with a server-like
# virt machine (high -smp, large -m, virtio-blk + virtio-net), until real RISC-V server hardware is rented.
#
# HONEST STATE (2026-10-24), from solnix's docs/riscv64-shell-session-2026-10-23.md:
#   * the uts riscv64 kernel boots under qemu virt (OpenSBI fw_payload, SMP), with virtio-blk/virtio-net drivers;
#   * userland is static newlib binaries: dash, sbase (ls/rm/mv/... with real getdents/unlink/rename), ed, less,
#     zlib, ncurses. A full shell session (pipes, redirects, $( )) works in one boot;
#   * NOT yet: nix, ZFS/boot environments, a dynamic loader, sshd, termios, illumos signal numbers.
# So this EVALUATES and does not build a bootable system. It records the target so the server work has a shape:
# headless, gburd's account and keys, the virtio NIC, EC2's resolver.
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

  # qemu virt's virtio-net is vioif on illumos; DHCP from qemu's user/tap network. EC2's resolver.
  networking.interfaces.vioif0.dhcp = true;
  networking.nameservers = [ "169.254.169.253" ];

  # No packages yet: pkgs.solnix has no riscv64 derivations (the riscv64 userland is built outside Nix, see above).
  # No desktop: a server.
}
