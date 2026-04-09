# Rust development environment
# Provides rustup, cargo, and development tools

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Rust toolchain manager
    # Note: rustup provides cargo, rustc, rust-analyzer, clippy, rustfmt, etc.
    # Don't install these tools separately to avoid path conflicts
    rustup

    # Code coverage tools
    cargo-llvm-cov # LLVM-based coverage (works with stable Rust)
    cargo-tarpaulin # Coverage tool with detailed reports

    # Additional Rust development tools
    cargo-nextest # Next-generation test runner (30-50% faster than cargo test)
    cargo-audit # Security vulnerability scanner
    cargo-deny # Supply chain security (licenses/advisories/bans)
    cargo-watch # Auto-rebuild on file changes
    cargo-expand # Show macro expansion
    cargo-flamegraph # Flamegraph profiler
    ast-grep # CLAUDE.md requirement: structure-aware code search

    # Uncomment as needed:
    # cargo-edit        # cargo add, cargo rm, cargo upgrade
    # cargo-outdated    # Check for outdated dependencies
    # cargo-udeps       # Find unused dependencies
    # clippy            # Rust linter (included in rustup)
    # rustfmt           # Rust formatter (included in rustup)
  ];

  # Environment setup for Rust
  home.sessionVariables = {
    # Set CARGO_HOME if you want to customize cargo directory
    # CARGO_HOME = "$HOME/.cargo";

    # Add cargo binaries to PATH (rustup manages this)
    # PATH = "$HOME/.cargo/bin:$PATH";

    # Enable colored output
    CARGO_TERM_COLOR = "always";

    # Increase build parallelism (optional)
    # CARGO_BUILD_JOBS = "8";
  };

  # Shell initialization for rustup
  programs.bash.initExtra = ''
    # Initialize rustup (if using rustup)
    if command -v rustup >/dev/null 2>&1; then
      export PATH="$HOME/.cargo/bin:$PATH"
    fi
  '';

  programs.fish.interactiveShellInit = ''
    # Initialize rustup (if using rustup)
    if command -v rustup >/dev/null 2>&1
      set -gx PATH $HOME/.cargo/bin $PATH
    end
  '';

  programs.zsh.initExtra = ''
    # Initialize rustup (if using rustup)
    if command -v rustup >/dev/null 2>&1; then
      export PATH="$HOME/.cargo/bin:$PATH"
    fi
  '';
}
