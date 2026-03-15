{ config, pkgs, ... }:
{
  # Import language-specific development tools
  imports = [
    ../../languages/rust.nix
  ];

  home.packages = with pkgs; [
    claude-code
    bubblewrap
    socat
    nodejs

    # Development tools for Claude Code
    # Note: Rust tools (rustc, cargo, rust-analyzer, rustup, coverage tools)
    # are provided by languages/rust.nix
    # gcc  # Removed: provided by console/default.nix as gcc14
    clang-tools # Provides clangd LSP, no full clang needed
    python3
    python3Packages.pylint
    shellcheck
    shfmt
    perl
    # git provided by programs.git (gitFull with SVN support)
    gh
  ];

  xdg.configFile."claude-code/mcp-config.json".source = ./mcp-config.json;
}
