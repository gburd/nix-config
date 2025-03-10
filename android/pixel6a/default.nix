{ pkgs, ... }:

{
  # Simply install just the packages
  environment.packages = with pkgs; [
    # User-facing stuff that you really really want to have
    vim # or some other editor, e.g. nano or neovim

    # Some common stuff that people expect to have
    curl
    diffutils
    findutils
    utillinux
    tzdata
    hostname
    man
    git
    gnugrep
    gnupg
    gnused
    gnutar
    bzip2
    gzip
    openssh
    xz
    zip
    unzip
  ];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Read the changelog before changing this value
  system.stateVersion = "23.05";

  # Set up nix for flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your time zone
  time.timeZone = "America/Detroit";

  # After installing home-manager channel like
  #   nix-channel --add https://github.com/rycee/home-manager/archive/release-24.11.tar.gz home-manager
  #   nix-channel --update
  # you can configure home-manager in here like
  #home-manager = {
  #  useGlobalPkgs = true;
  #
  #  config =
  #    { config, lib, pkgs, ... }:
  #    {
  #      # Read the changelog before changing this value
  #      home.stateVersion = "24.11";
  #
  #      # insert home-manager config
  #    };
  #};
}

# vim: ft=nix
