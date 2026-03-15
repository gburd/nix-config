{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sublime4 # Sublime Text 4
  ];

  # Sublime Text configuration
  xdg.configFile."sublime-text/Packages/User/Preferences.sublime-settings".source = ./Preferences.sublime-settings;
}
