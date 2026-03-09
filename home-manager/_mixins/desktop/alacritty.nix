{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "xterm-256color";
      };
      window = {
        decorations = "full";
        dynamic_padding = true;
      };
      scrolling = {
        history = 10000;
      };
    };
  };

  home.packages = [ pkgs.alacritty-theme pkgs.gnomeExtensions.toggle-alacritty ];
}
