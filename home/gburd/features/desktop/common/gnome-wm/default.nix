{ pkgs, ... }:
{
  imports = [];

  home.packages = with pkgs; [
    # Gnome3 apps
#    gnome3.eog    # image viewer
#    gnome3.evince # pdf reader

    # Desktop look & feel
#    gnome.gnome-tweak-tool

    # Extensions
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
  ];

  # environment.gnome.excludePackages = (with pkgs; [
  #   gnome-photos
  #   gnome-tour
  # ]) ++ (with pkgs.gnome; [
  #   cheese # webcam tool
  #   gnome-music
  #   geary # email reader
  #   gnome-characters
  #   yelp # Help view
  #   gnome-contacts
  #   gnome-initial-setup
  # ]);
  # programs.dconf.enable = true;
  # environment.systemPackages = with pkgs; [
  #   gnome.gnome-tweaks
  # ]
  # };
#  dbus.packages = [ pkgs.gnome.dconf ];
#  udev.packages = [ pkgs.gnome.gnome-settings-daemon ];

  home.sessionVariables = {
  };
}
