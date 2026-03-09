{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    bubblewrap
    socat
    nodejs

    # Development tools for Claude Code
    rustc
    cargo
    rust-analyzer
    gcc
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
