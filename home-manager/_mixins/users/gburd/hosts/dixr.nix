{ ... }:
# dixr -- RISC-V solnix (Nix on illumos) host on PHYSICAL hardware (keyboard,
# mouse, monitor): the daily-driver dev box. Unlike the headless dixi/dixa, it
# runs the COSMIC desktop -- the Pop!_OS COSMIC experience, illumos underneath.
# The `desktop = "cosmic"` arg (set in flake.nix's mkHome) drives
# systems/solaris.nix to add the COSMIC userland the gburd profile wants.
#
# Solnix's roadmap has RISC-V at Phase 5 ("no illumos port exists yet"), so
# dixr is the furthest-out target: it evaluates now (profile shape) and builds
# only once solnix grows a riscv64-solaris platform.
{
  imports = [ ./_solnix-common.nix ];
}
