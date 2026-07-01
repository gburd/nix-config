{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    # Use neovim 0.12.x from nixpkgs-unstable (stable 25.11 is still on
    # 0.11.7). 0.12 unlocks the current plugin ecosystem (e.g. telescope
    # master, which moved to the 0.12-only vim.nonnil API) and the native
    # vim.lsp / vim.pack improvements.
    package = pkgs.unstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nixd # Nix LSP (more complete than nil)
      # rust-analyzer is provided by rustup (via languages/rust.nix)
      # to avoid conflicts with rustup's wrapper
      clang-tools # provides clangd
      gopls # Go LSP
      pyright # Python LSP
      sqls # SQL LSP
      taplo # TOML LSP + formatter
      vscode-langservers-extracted # JSON, HTML, CSS, ESLint LSP
      yaml-language-server
      perlPackages.PLS # Perl LSP
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
  # Global markdownlint config (nvim-lint runs markdownlint on .md buffers).
  # markdownlint's prose defaults are noisy: MD010 flags every leading hard
  # tab ("Hard tabs [Column: 1]"), MD013 flags long lines, MD041 demands an
  # H1 first. Silence the ones that fight normal note-taking; a repo-local
  # .markdownlint.json still overrides this if a project wants stricter rules.
  home.file.".markdownlint.json".text = builtins.toJSON {
    MD010 = false; # no-hard-tabs — allow tab indentation
    MD013 = false; # line-length — don't wrap prose
    MD041 = false; # first-line-h1 — not every doc starts with #
    MD024 = false; # duplicate headings (common in changelogs)
    MD033 = false; # inline HTML — allowed
  };
}
