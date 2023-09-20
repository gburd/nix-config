{
  services = {
    xserver = {
      enable = true;
      displayManager.gdm = {
        enable = true;
        autoSuspend = false;
        wayland = false;
      };
      desktopManager.gnome = {
        enable = true;
      };
    };
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
