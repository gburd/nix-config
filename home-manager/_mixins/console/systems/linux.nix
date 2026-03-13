{ lib, config, pkgs, ... }: {
  home.packages = with pkgs; [
    debootstrap # Terminal Debian installer
    lurk # Modern Unix `strace`
  ];

  # gpg-agent is configured in cli/gpg.nix with smart pinentry auto-detection
  # No need to override here - it will automatically use curses in console environments

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = lib.mkDefault true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
      };
    };
  };
}
