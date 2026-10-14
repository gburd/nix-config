_:
# lixr -- LOCAL riscv64 host: a SpacemiT K3 Pico ITX (X100 cores, 8c / 31 GB)
# at 192.168.1.179. Naming: "l" = local/LAN (a physical machine in the house),
# "-r" = riscv64. Compare dixr, the DISTRIBUTED riscv64 solnix target.
#
# Today it runs Bianbu 4.0.6 (Debian-derived) with home-manager on top -- like
# arnold, not NixOS. It is expected to become a solnix (illumos) host later;
# until then this file gives gburd floki's user-level setup where riscv64 can
# carry it.
#
# WHAT "SAME AS FLOKI" CAN AND CANNOT MEAN HERE -- measured, not assumed:
#
#   * NO GNOME. Bianbu ships LXQt and labwc (wayland-sessions: bianbu-lite,
#     labwc, lxqt-wayland; xsessions: lxqt). home-manager cannot install a
#     desktop session on a non-NixOS host, so floki's gnome dconf tree has
#     nothing to act on. This host therefore passes NO `desktop` argument
#     (see flake.nix), the same choice arnold makes, and the GUI apps are
#     listed directly below rather than through _mixins/desktop.
#
#   * Six of floki's GUI apps have NO riscv64 build in nixpkgs at all
#     (meta.platforms checked 2026-10-14): sublime4, sublime-merge, typora,
#     protonmail-desktop, proton-pass, lmstudio. They are prebuilt x86_64 /
#     aarch64 binaries. Left out deliberately; adding them would fail eval.
#
#   * vorta and telegram-desktop ALSO fail, despite listing riscv64-linux in
#     their own meta.platforms: both depend on qtwebengine-6.11.2, which
#     refuses to evaluate on riscv64-linux. A package's meta.platforms says
#     nothing about its dependencies -- the real test is evaluating the
#     package's outPath and accepting ANY eval error as a failure.
#
#   * element-desktop fails too: it is Electron, i.e. Chromium, and Chromium
#     has "no chromium Rosetta Stone entry for cpu: riscv64". So every
#     Electron app is out. (An earlier probe of mine reported it fine because
#     it grepped only for "Refusing to evaluate" and missed this message.)
#     wezterm is the only one of floki's GUI apps that evaluates here.
#
#   * NO BINARY CACHE. cache.nixos.org has no riscv64-linux coverage (narinfo
#     404 for hello/bash/coreutils/git), so every package here is built from
#     source on the board. The first switch will take many hours.
#
#   * BOOTSTRAP WORKAROUND REQUIRED. nixpkgs' riscv64 bootstrap gcc segfaults
#     unless /etc/sysctl.d/99-nix-riscv64-bootstrap.conf lowers
#     vm.mmap_min_addr to 61440. That file is host-level, outside
#     home-manager; see lixr-manual-changes.md.
{
  imports = [
    ../../../console/ai
    # Floki's terminal setup verbatim: a self-contained programs.wezterm
    # module with no session or package coupling beyond wezterm itself.
    ../../../desktop/wezterm.nix
    # Not imported: services/vdirsyncer.nix + console/khal.nix (floki has
    # them). vdirsyncer reads Google-calendar OAuth secrets from sops
    # (calendar/google/personal/*) that only floki/meh declare, and lixr has
    # no sops setup yet. It is also already failing on meh, and khal is
    # unconfigured everywhere. Add both once calendars actually work.
  ];

  # No extra home.packages: of floki's GUI set, only wezterm (imported above)
  # evaluates on riscv64-linux. See the header for each exclusion and why.
}
