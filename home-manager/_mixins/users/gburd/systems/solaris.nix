{ username, ... }:
# systems/solaris.nix — the per-systemType mixin for x86_64-solaris (illumos),
# selected by users/gburd/default.nix when platform splits to ".. - solaris - ..".
#
# ⚠️ NOT YET FUNCTIONAL (see hosts/solnix.nix header). This is the illumos
# analog of systems/linux.nix, with every Linux/systemd-specific piece removed:
#
#   - NO services.keybaseClient  — that HM module emits a systemd user unit;
#     illumos uses SMF. A keybase-on-illumos SMF service is solnix backlog.
#   - NO systemd.user.tmpfiles   — no systemd on illumos. The equivalent
#     (ensure ~/ws exists) is done with a plain home.activation script below,
#     which is OS-agnostic.
#   - NO Quickemu VM configs      — those are Linux-guest desktop conveniences,
#     irrelevant on a headless illumos box.
#
# Kept deliberately minimal: the OS-agnostic subset only.
{
  # ~/ws directory — systemd.user.tmpfiles has no illumos equivalent, so use an
  # HM activation script (portable: it's just mkdir at `home-manager switch`).
  home.activation.ensureWsDir = ''
    run mkdir -p "$HOME/ws"
  '';

  # NOTE (solnix backlog): keybase, and meh's other services, need an HM->SMF
  # translation shim before they can run here. Omitted, not forgotten.
}
