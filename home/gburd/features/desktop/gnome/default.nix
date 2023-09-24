{ config, pkgs, lib, ... }: {
  imports = [
    ../common
    ../common/gnome-wm

    ./tty-init.nix
  ];

  home.packages = with pkgs; [
    emacs
    ungoogled-chromium
    gnupg
    pinentry
    alacritty
  ];
  # dconf
  # settings reset org.gnome.desktop.input-sources xkb-options
  # gsettings reset org.gnome.desktop.input-sources sources
}
