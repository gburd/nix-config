# Advanced example: Building specific packages with debug symbols
# This shows how to get debug symbols for system libraries you're debugging

{ pkgs ? import <nixpkgs> { } }:

let
  # Helper function to build a package with debug info
  withDebugInfo = pkg: pkg.overrideAttrs (oldAttrs: {
    # Don't strip debug symbols
    dontStrip = true;

    # Separate debug info into .debug output
    separateDebugInfo = true;

    # Add debug compiler flags
    NIX_CFLAGS_COMPILE = toString (
      (oldAttrs.NIX_CFLAGS_COMPILE or [ ]) ++ [
        "-g" # Include debug symbols
        "-O0" # No optimization (easier debugging)
        "-fno-omit-frame-pointer" # Keep frame pointers
      ]
    );

    # For CMake projects
    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DCMAKE_BUILD_TYPE=Debug"
    ];

    # For Meson projects
    mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [
      "-Dbuildtype=debug"
    ];
  });

  # Example: Build specific libraries with debug symbols
  glibcDebug = withDebugInfo pkgs.glibc;
  opensslDebug = withDebugInfo pkgs.openssl;
  curlDebug = withDebugInfo pkgs.curl;

in
pkgs.mkShell {
  name = "debug-shell";

  buildInputs = with pkgs; [
    # Use debug versions of critical libraries
    glibcDebug
    opensslDebug
    curlDebug

    # Debugging tools
    gdb
    lldb
    valgrind
    strace
    ltrace

    # Binary analysis
    binutils
    elfutils
    patchelf
    radare2
  ];

  shellHook = ''
    echo "🐛 Debug environment loaded"
    echo ""
    echo "Libraries with debug symbols:"
    echo "  glibc: ${glibcDebug}"
    echo "  openssl: ${opensslDebug}"
    echo "  curl: ${curlDebug}"
    echo ""
    echo "Debug info locations:"
    echo "  $NIX_DEBUG_INFO_DIRS"
    echo ""
    echo "Example GDB usage:"
    echo "  gdb --args ./your-program"
    echo "  (gdb) break malloc"
    echo "  (gdb) run"
    echo "  (gdb) backtrace"
  '';

  # Tell GDB where to find debug info
  NIX_DEBUG_INFO_DIRS = pkgs.lib.makeSearchPath "lib/debug" [
    glibcDebug.debug or glibcDebug
    opensslDebug.debug or opensslDebug
    curlDebug.debug or curlDebug
  ];
}
