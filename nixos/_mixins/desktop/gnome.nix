{ pkgs, ... }:
{
  imports = [
    ../services/xdg-portal.nix
  ];

  # Enable the graphical windowing system.
  # NOTE: xserver is a legacy naming convention, DEs may still use Wayland over X11
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.displayManager.gdm.enable = true;

  # TODO: Disable Wayland (issues with Electron app rendering)?
  services.xserver.displayManager.gdm.wayland = true;

  # Enable udev rules
  services.udev.packages = with pkgs.unstable; [ gnome.gnome-settings-daemon ];

  environment.systemPackages = with pkgs.unstable; [
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.pop-shell
    gnome3.gnome-tweaks
  ];

  # Exclude packages
  environment.gnome.excludePackages = (with pkgs; [
    # for packages that are pkgs.***
    gnome-tour
    gnome-connections
  ]) ++ (with pkgs.gnome; [
    # for packages that are pkgs.gnome.***
    epiphany # web browser
    geary # email reader
    evince # document viewer
  ]);

}
