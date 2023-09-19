{
  services = {
    xserver = {
      enable = true;
      desktopManager.gnome = {
        enable = true;
      };
      displayManager.gdm = {
        enable = true;
        autoSuspend = false;
	wayland = true;
      };
    };
    geoclue2.enable = true;
    gnome.games.enable = true;
  };
  services.avahi.enable = true;
  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi.nssmdns = true;
  # for a WiFi printer
  services.avahi.openFirewall = true;
  networking.networkmanager.enable = true;
}
