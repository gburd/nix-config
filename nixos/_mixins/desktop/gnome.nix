{ pkgs, ... }:
{
  imports = [
    ../services/xdg-portal.nix
  ];

  # Enable the graphical windowing system.
  # NOTE: xserver is a legacy naming convention, DEs may still use Wayland over X11
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.desktopManager.gnome.enable = true;

  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Enable udev rules
  services.udev.packages = with pkgs.unstable; [ gnome-settings-daemon ];

  environment.systemPackages = with pkgs.unstable; [
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.pop-shell
    gnome-tweaks
  ]
  # Local voice dictation for agents (Kun Chen's workflow uses macOS
  # OpenSuperWhisper; this is the GNOME/Wayland equivalent). Push-to-talk
  # via a keyboard shortcut; runs whisper.cpp locally (bundled), no cloud.
  # Enable in GNOME Extensions + set a hotkey after switching. From STABLE
  # pkgs — it's absent in nixpkgs-unstable.
  ++ [ pkgs.gnomeExtensions.speech2text-with-whispercpp ];

  # Exclude packages
  environment.gnome.excludePackages = with pkgs; [
    # for packages that are pkgs.***
    gnome-tour
    gnome-connections
    epiphany # web browser
    geary # email reader
    evince # document viewer
  ];

}
