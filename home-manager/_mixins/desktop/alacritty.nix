{ pkgs, ... }:
{
  home.packages = [ pkgs.alacritty pkgs.alacritty-theme pkgs.gnomeExtensions.toggle-alacritty ];
}
