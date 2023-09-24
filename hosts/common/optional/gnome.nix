{
  services = {
    xserver = {
      enable = true;
      displayManager.gdm = {
        enable = true;
        wayland = true;
        autoSuspend = false;
      };
      desktopManager.gnome = {
        enable = true;
      };
    };
    excludePackages = [ pkgs.xterm ];
    geoclue2.enable = true;
    gnome.games.enable = true;
  };
  networking.networkmanager.enable = true;
  services.avahi.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi.nssmdns = true;
  # for a WiFi printer
  services.avahi.openFirewall = true;
}
