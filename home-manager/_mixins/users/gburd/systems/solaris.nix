{ desktop ? null, lib, pkgs, username, ... }:
# systems/solaris.nix -- the per-OS split for solnix (illumos/Solaris under Nix,
# platform x86_64-solaris or aarch64-solaris; systemType "solaris").
#
# The parallel to systems/linux.nix, but for a Nix-on-illumos host. illumos
# has no systemd/udev/dconf-session-bus, so the Linux desktop-app mixins
# (tilix/celluloid/keybase-gui, all of which pull dconf + a GNOME session bus
# at activation) are NOT imported here. The desktop on solnix is COSMIC
# (libcosmic/GTK4/libadwaita), driven by the system config (modules/), not by
# home-manager desktop mixins -- same functional experience as pop!_OS COSMIC,
# illumos underneath.
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
