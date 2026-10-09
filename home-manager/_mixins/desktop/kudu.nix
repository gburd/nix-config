{ pkgs, ... }:
# Kudu — system cleaner / scanner / startup manager, GUI hosts only.
# Electron app packaged from upstream's AppImage; see pkgs/kudu.
#
# GUI-only because it has no CLI mode worth having: the binary launches the
# Electron window. Lives in the desktop mixin, which home-manager/default.nix
# imports only when `desktop` is a string, so headless hosts (meh when it was
# server-shaped, the solnix boxes) never pull a 149MB AppImage.
{
  home.packages = [ pkgs.kudu ];
}
