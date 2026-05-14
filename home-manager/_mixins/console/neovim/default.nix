{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nixd              # Nix LSP (more complete than nil)
      # rust-analyzer is provided by rustup (via languages/rust.nix)
      # to avoid conflicts with rustup's wrapper
      clang-tools # provides clangd
      gopls       # Go LSP
      pyright     # Python LSP
      sqls        # SQL LSP
      taplo       # TOML LSP + formatter
      vscode-langservers-extracted   # JSON, HTML, CSS, ESLint LSP
      yaml-language-server
      perlPackages.PLS               # Perl LSP
      nodePackages.bash-language-server

      # Formatters
      stylua
      nixpkgs-fmt
      black
      shfmt
      pgformatter # PostgreSQL formatter
      sqlfluff # SQL linter and formatter
      # rustfmt is provided by rustup (via languages/rust.nix)

      # Linters
      shellcheck
      python3Packages.ruff
      python3Packages.mypy
      markdownlint-cli

      # Debuggers
      lldb # LLDB debugger for Rust/C/C++ (provides lldb-vscode)
      python3Packages.debugpy # Python debugger
      delve # Go debugger

      # Testing tools
      python3Packages.pytest

      # Build tools
      meson
      gnumake
      cmake
      cargo-nextest # Better Rust test runner

      # Utilities
      ripgrep
      fd
      # gcc  # Removed: provided by console/default.nix as gcc14
      nnn
      zig
    ];
  };
  xdg.configFile = {
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };
}
