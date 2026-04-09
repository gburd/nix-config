{ pkgs, ... }:
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

    # Python ecosystem (CLAUDE.md requirements)
    python3
    uv # CLAUDE.md: "Runtime: 3.13 with uv venv"
    ruff # CLAUDE.md: "Always use ruff" - replaces black/pylint/flake8
    pyright # Type checker
    python3Packages.pytest

    # SQL tools for RA PostgreSQL extension testing
    postgresql_17 # psql CLI
    sqlite # sqlite3 CLI
    sqlfluff # SQL linter (zero warnings policy)
    pgcli # PostgreSQL with auto-completion

    # Rust database development
    rpg-cli # https://github.com/NikolayS/rpg - Rust Postgres extension generator

    # CI/CD validation (CLAUDE.md requirements)
    actionlint # GitHub Actions linter

    # Shell tools
    shellcheck
    shfmt
    perl

    # Version control
    # git provided by programs.git (gitFull with SVN support)
    gh

    # LSPs for multi-language support
    bash-language-server
    typescript-language-server
    nil # Nix LSP (if not already installed)

    # TypeScript/Node.js ecosystem (CLAUDE.md requirements)
    typescript
    nodePackages.prettier # Until oxfmt available in nixpkgs
    # oxlint not yet in nixpkgs - use prettier interim

    # Nix development tools
    nixpkgs-fmt # Nix formatter
    alejandra # Alternative formatter (faster)
    statix # Nix linter
    deadnix # Find dead code
    nix-tree # Visualize dependencies
    nix-diff # Compare derivations
  ];

  xdg.configFile."claude-code/mcp-config.json".source = ./mcp-config.json;
}
