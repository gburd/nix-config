{ pkgs, ... }:
{
  services = {
    xserver = {
      enable = true;
      dpi = 180;
      displayManager.gdm = {
        enable = true;
        wayland = true;
        autoSuspend = false;
      };
      desktopManager.gnome = {
        enable = true;
      };
      excludePackages = [ pkgs.xterm ];
    };
    geoclue2.enable = true;
    gnome.games.enable = true;
  };
  networking.networkmanager.enable = true;
  services.avahi.enable = true;

  #  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  # environment.variables = {
  #   GDK_SCALE = "2";
  #   GDK_DPI_SCALE = "0.5";
  #   _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi.nssmdns = true;
  # for a WiFi printer
  services.avahi.openFirewall = true;
}
