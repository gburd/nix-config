{ pkgs, ... }:
{
  home.packages = [ pkgs.sublime4 ]; # Updated from old sublime (v2) to sublime4

  # Sublime Text 4 configuration
  xdg.configFile."sublime-text/Packages/User/Preferences.sublime-settings".source = ../console/sublime/Preferences.sublime-settings;
}
