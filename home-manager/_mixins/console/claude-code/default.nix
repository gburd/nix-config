{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    unstable.claude-code
    bubblewrap
    socat
    nodejs

    # Development tools for Claude Code
    rustc
    cargo
    rust-analyzer
    gcc
    clang
    clang-tools
    python311
    python311Packages.pylint
    shellcheck
    shfmt
    perl
    git
    gh
  ];

  xdg.configFile."claude-code/mcp-config.json".source = ./mcp-config.json;
}
