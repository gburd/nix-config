{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zed-editor # Zed editor
  ];

  # Zed configuration
  xdg.configFile."zed/settings.json".source = ./settings.json;
  xdg.configFile."zed/keymap.json".source = ./keymap.json;
}
