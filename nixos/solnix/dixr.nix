# nixos/solnix/dixr.nix -- the Milk-V board, riscv64.
#
# =============================================================================
# ASPIRATIONAL SCAFFOLDING. THIS CANNOT BUILD OR BOOT ANYTHING TODAY.
# =============================================================================
#
# This file exists so the riscv64 target has a shape to grow into, and so the
# gap is CONCRETE rather than hypothetical. It is not a working configuration and
# no part of it has been built. Specifically, measured:
#
#   1. riscv64 has ZERO registry derivations. docs/registry/real-derivations.tsv
#      has no published riscv64 rows at all, so pkgs.solnix.starter is EMPTY for
#      this platform. There is nothing to put in environment.systemPackages.
#   2. THE ELF LOADER IS STATIC-ONLY. elf.c on riscv64 handles ET_EXEC only --
#      no ET_DYN, so no dynamic linking, so no ld.so.1 and no shared libraries.
#      Essentially every derivation in the tree is dynamically linked.
#   3. THERE IS NO ZFS. So there is no boot environment, no `rpool/ROOT/<be>`, no
#      beadm, and therefore none of solnix's generation model -- which is built on
#      ZFS boot environments as its central mechanism.
#
# Any one of those three alone blocks a bootable system. Together they mean the
# honest status is "the architecture is named, and that is all".
#
# WHAT THE HARDWARE ACTUALLY IS. Worth pinning down because it has been recorded
# wrong: `lshw` on the board reports "SpacemiT K3 Pico ITX". It is a K3, NOT a K1.
# A config or driver written against K1 documentation is written against the wrong
# SoC.
#
# So: no packages, no core-OS slices, no desktop, no network interface that has
# ever been seen to attach. Adding any of those would be inventing evidence.
{ config, lib, pkgs, ... }:

{
  users.users.gburd = {
    uid = 1000;
    home = "/home/gburd";
    group = "staff";
    extraGroups = [ "sysadmin" ];
    # ksh93 for the same reason as the other two hosts: bash is not in the gate.
    # Moot here -- there is no userland to log into.
    shell = "/usr/bin/ksh93";
  };

  # NOTHING ELSE, ON PURPOSE.
  #
  # No environment.systemPackages: pkgs.solnix.starter is empty for riscv64 (fact
  # 1 above), so every name would be an undefined variable.
  #
  # No networking.interfaces.*: no riscv64 NIC has been observed to attach on this
  # board, and declaring an interface name that does not exist generates bringup
  # for a datalink that is not there. `dladm show-phys` on the board is the only
  # thing that can settle it, and that requires a booting system.
  #
  # No solnix.desktop.cosmic: the COSMIC module ASSERTS
  # pkgs.stdenv.hostPlatform.isx86_64 and would correctly fail the build. Nothing
  # in the COSMIC set has ever been built for riscv64.
}
