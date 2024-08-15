{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../cli/signal.nix
    ../../desktop/alacritty.nix
    ../../desktop/dconf-editor.nix
    ../../desktop/jetbrains-toolbox.nix
    ../../desktop/meld.nix
    ../../desktop/protonmail-bridge.nix
    ../../desktop/protonmail-desktop.nix
    ../../desktop/sublime-merge.nix
    ../../desktop/sublime.nix
    ../../desktop/zed-editor.nix
    ../../services/keybase.nix
  ];

  # Authrorize X11 access in Distrobox
  home.file.".distroboxrc".text = ''
    xhost +si:localuser:$USER
  '';
}
