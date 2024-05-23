{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    # "loglevel=3" "rd.udev.log_level=3" "systemd.show_status=auto" "udev.log_level=3"
    plymouth.enable = true;
    #consoleLogLevel = 0;
    #initrd.verbose = false;
  };

  # AppImage support & X11 automation
  environment.systemPackages = with pkgs; [
    appimage-run
    wmctrl
    xdotool
    ydotool
  ];

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  programs.dconf.enable = true;

  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;

  #  systemd.services.disable-wifi-powersave = {
  #    wantedBy = [ "multi-user.target" ];
  #    path = [ pkgs.iw ];
  #    script = ''
  #      iw dev wlp0s20f3 set power_save off
  #    '';
  #  };

  #  xdg.portal = {
  #    enable = true;
  #    xdgOpenUsePortal = true;
  #  };
}
