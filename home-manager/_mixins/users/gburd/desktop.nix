{ config, lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../cli/signal.nix
    ../../desktop/alacritty.nix
    ../../desktop/audio-recorder.nix
    ../../desktop/celluloid.nix
    ../../desktop/dconf-editor.nix
    ../../desktop/gitkraken.nix
    ../../desktop/gnome-sound-recorder.nix
    ../../desktop/jetbrains-clion.nix
    ../../desktop/jetbrains-idea-ultimate.nix
    ../../desktop/jetbrains-toolbox.nix
    ../../desktop/meld.nix
    ../../desktop/protonmail-bridge.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sublime-merge.nix
    ../../desktop/sublime.nix
    ../../services/keybase.nix
  ];

  dconf.settings = {
    "org/gnome/rhythmbox/rhythmdb" = {
      locations = [ "file://${config.home.homeDirectory}/Studio/Music" ];
      monitor-library = true;
    };
  };

  # Authrorize X11 access in Distrobox
  home.file.".distroboxrc".text = ''
    xhost +si:localuser:$USER
  '';
}
