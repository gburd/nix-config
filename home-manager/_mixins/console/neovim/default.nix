{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      lua-language-server
      nil
      rust-analyzer
      clangd
      pyright
      nodePackages.bash-language-server
      stylua nixpkgs-fmt rustfmt black shfmt
      meson gnumake cmake
      ripgrep fd
      gcc
      nnn
      zig
    ];
  };
  xdg.configFile = {
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };
}
