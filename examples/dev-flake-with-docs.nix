# Example: Development flake with documentation and debug symbols
# Place this in your project as flake.nix
#
# Usage:
#   nix develop          # Enter dev shell with docs and debug tools
#   nix develop .#minimal # Enter minimal shell without docs/debug

{
  description = "Example development environment with optional docs and debug";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Helper to enable debug info for a package

        # Documentation packages for different languages
        docPackages = with pkgs; [
          # C/C++ documentation
          man-pages # Linux programmer's manual
          man-pages-posix # POSIX standards
          # glibc.doc         # GNU libc documentation (large!)

          # Python documentation
          # python3.doc       # Python stdlib docs (can use pydoc instead)

          # Rust documentation (rust analyzer handles this)
          # rust.doc          # Rust std docs (use rustup doc instead)
        ];

        # Debugging tools
        debugTools = with pkgs; [
          gdb # GNU Debugger
          lldb # LLVM Debugger
          valgrind # Memory debugger
          strace # System call tracer
          rr # Time-travel debugger
        ];

        # Common development tools
        baseTools = with pkgs; [
          git
          ripgrep
          fd
          jq
        ];

      in
      {
        # Default dev shell: includes everything
        devShells.default = pkgs.mkShell {
          name = "dev-full";

          buildInputs = baseTools ++ docPackages ++ debugTools;

          # Example: C/C++ development with debug symbols
          nativeBuildInputs = with pkgs; [
            gcc
            cmake
            pkg-config
          ];

          shellHook = ''
            echo "🔧 Development environment loaded"
            echo "📚 Man pages: man malloc, man pthread_create, etc."
            echo "🐛 Debug tools: gdb, valgrind, strace"
            echo ""
            echo "To build with debug symbols:"
            echo "  cmake -DCMAKE_BUILD_TYPE=Debug .."
            echo "  make CFLAGS='-g -O0'"
          '';

          # Environment variables for debugging
          NIX_DEBUG_INFO_DIRS = "${pkgs.stdenv.cc.cc.debug}/lib/debug";

          # Ensure man pages are found
          MANPATH = "${pkgs.man-pages}/share/man:${pkgs.man-pages-posix}/share/man";
        };

        # Minimal dev shell: no docs or debug tools
        devShells.minimal = pkgs.mkShell {
          name = "dev-minimal";
          buildInputs = baseTools;

          shellHook = ''
            echo "⚡ Minimal development environment"
          '';
        };

        # Language-specific example: Python with debug
        devShells.python = pkgs.mkShell {
          name = "python-dev";

          buildInputs = with pkgs; [
            # Use python with debug symbols
            (python3.override {
              enableOptimizations = false;
              reproducibleBuild = false;
              stripBytecode = false;
            })

            # Python development tools
            python3Packages.pip
            python3Packages.ipython
            python3Packages.pytest

            # Debugging
            gdb
            python3Packages.pudb # Python debugger
          ] ++ docPackages;

          shellHook = ''
            echo "🐍 Python development environment"
            echo "Debug with: python -m pudb script.py"
            echo "Or use: gdb python"
          '';

          # Enable Python debug mode
          PYTHONDEBUG = "1";
        };

        # Rust development example
        devShells.rust = pkgs.mkShell {
          name = "rust-dev";

          buildInputs = with pkgs; [
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer

            # Debugging
            lldb
            rr
          ] ++ docPackages;

          shellHook = ''
            echo "🦀 Rust development environment"
            echo "Build with debug: cargo build"
            echo "Debug with: rust-lldb target/debug/binary"
            echo "Documentation: rustup doc --std"
          '';

          # Rust specific flags for more debug info
          RUSTFLAGS = "-C debuginfo=2";
        };
      }
    );
}
