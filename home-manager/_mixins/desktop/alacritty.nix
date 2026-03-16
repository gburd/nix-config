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
      keyboard.bindings = [
        {
          key = "Return";
          mods = "Control|Shift";
          action = "SpawnNewInstance";
        }
      ];
    };
  };

  home.packages = [ pkgs.alacritty-theme ];
  # NOTE: gnomeExtensions.toggle-alacritty not available in current nixpkgs
}
