{ pkgs, ... }:
{
  imports = [
    ../services/xdg-portal.nix
  ];

  services = {
    # Enable the X11 windowing system.
    xserver.enable = false;

    # Enable the GNOME Desktop Environment.
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    # Enable udev rules
    udev.packages = with pkgs.unstable; [ gnome.cosmic-settings-daemon ];
  };

  environment.systemPackages = with pkgs.unstable; [
    gnomeExtensions.appindicator
    gnome-tweaks
  ];
}
