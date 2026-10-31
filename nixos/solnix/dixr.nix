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
# UPDATE 2026-10-31 (solnix docs/dixr-build-host-plan.md): a second base, n-hys/illumos-gate osport/v2021.07 (CDDL),
# was built on EC2 and boots qemu virt (-cpu rv64,sv57=off, 4/4 and 8/8 harts) from a ZFS root to SMF + console login,
# with ld.so.1, native gcc/g++ 11.1.0 and make; zlib 1.3.1 builds and passes make check in the guest. Its NIC is
# platmac0, not vioif0. Still NOT: nix, a working sshd (preauth EINVAL), so no packages yet.
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

  # qemu virt's virtio-net attaches as platmac0 under the n-hys riscv64pf/virt kernel (measured 2026-10-31: dladm
  # show-phys); DHCP from qemu's user/tap network. EC2's resolver.
  networking.interfaces.platmac0.dhcp = true;
  networking.nameservers = [ "169.254.169.253" ];

  # No packages yet: pkgs.solnix has no riscv64 derivations (the riscv64 userland is built outside Nix, see above).
  # No desktop: a server.
}
