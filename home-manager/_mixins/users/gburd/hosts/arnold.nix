{ pkgs, ... }:
{
  # Arnold is a Fedora system running home-manager via Nix
  # Import shared mixins for CLI and console tools
  imports = [
    ../../cli # Shared CLI tools
    ../../console # Shared console (neovim, tmux, etc.)
  ];

  home.file.".inputrc".text = ''
    "\C-v": ""
    set enable-bracketed-paste off
  '';

  home.file.".config/direnv/direnv.toml".text = ''
    [global]
    load_dotenv = true
  '';

  # Arnold-specific packages
  home.packages = with pkgs; [
    autoconf
    bash
    cmake
    dig
    file
    gcc
    gdb
    gnumake
    htop
    libtool
    lsof
    m4
    openssl
    perl
    pkg-config
    python3
    ripgrep
    tig
    tree
    xclip
  ];

  home.enableDebugInfo = true;
}
