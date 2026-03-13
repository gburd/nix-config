{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      lua-language-server
      nil
      # rust-analyzer is provided by rustup (via languages/rust.nix)
      # to avoid conflicts with rustup's wrapper
      clang-tools # provides clangd
      pyright
      nodePackages.bash-language-server
      stylua nixpkgs-fmt black shfmt
      # rustfmt is provided by rustup (via languages/rust.nix)
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
