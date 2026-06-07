{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    # NOTE: `mitigations=off` was removed — it disabled all CPU
    # vulnerability mitigations (Spectre/Meltdown/MDS/...) system-wide on
    # every desktop, including the floki laptop that travels and runs a
    # browser. The marginal perf gain isn't worth the exposure on a
    # general-purpose machine. Re-add it ONLY on a dedicated, trusted
    # single-user compute box if you ever need the last few % (and scope
    # it to that host, not this shared desktop default).
    kernelParams = [ "quiet" "vt.global_cursor_default=0" ];
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
    graphics = {
      enable = true;
    };
  };

  programs.dconf.enable = true;

  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];

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
