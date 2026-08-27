{ desktop ? null, lib, pkgs, ... }:
# systems/solaris.nix -- the per-OS split for the solnix hosts (illumos/Solaris
# under Nix): dixi (x86_64), dixa (aarch64), dixr (riscv64); systemType
# "solaris".
#
# The parallel to systems/linux.nix, but for Nix-on-illumos hosts. illumos
# has no systemd/udev/dconf-session-bus, so the Linux desktop-app mixins
# (tilix/celluloid/keybase-gui, all of which pull dconf + a GNOME session bus
# at activation) are NOT imported here. Only dixr (the physical RISC-V dev
# box, desktop="cosmic") gets a desktop -- COSMIC (libcosmic/GTK4/libadwaita),
# driven by the solnix system config (modules/), not by home-manager desktop
# mixins -- the same functional experience as pop!_OS COSMIC, illumos
# underneath. dixi/dixa are headless EC2 build animals (desktop=null) and get
# no GUI closure at all.
#
# Keep this LEAN: the console/ + cli/ base (shell, git, editors, the AI agent
# tooling) is what a gburd login on solnix needs day one -- including the
# imminent RISC-V daily-driver box. Grow it as solnix's package set fills in.
{
  # No Linux-only services (keybase GUI, dconf desktop apps). The COSMIC
  # session + apps are provisioned by the solnix system config, not here.

  # Desktop apps that DO exist as solnix packages + are wanted in the COSMIC
  # session get added here once built (cosmic-term is the default terminal;
  # editors/browsers as they land). Gated on `desktop` so a headless
  # build-farm login stays minimal.
  home.packages = lib.optionals (builtins.isString desktop) (
    # COSMIC-session userland the gburd profile wants when a desktop is present.
    # Names resolve against the solnix package set (nixpkgs-illumos overlay),
    # not stock nixpkgs -- kept as an explicit allowlist so a headless build
    # animal never drags in the GUI closure.
    lib.filter (p: p != null) [
      (pkgs.cosmic-term or null)
      (pkgs.cosmic-files or null)
      (pkgs.cosmic-edit or null)
    ]
  );

  # illumos SMF-managed user services would go here (the home-manager
  # systemd-user analog) once solnix grows a per-user SMF bridge. Until then,
  # the gburd login relies on the console/cli tooling + the system COSMIC
  # session.
}
