# Optional debug symbols configuration
# Import this mixin to enable debug information for system libraries and tools

{ config, lib, pkgs, ... }:

{
  # Enable separate debug info for packages
  # This creates a separate output with debug symbols that debuggers can find
  environment.enableDebugInfo = true;

  # Install common debugging tools
  environment.systemPackages = with pkgs; [
    gdb               # GNU Debugger
    lldb              # LLVM Debugger
    valgrind          # Memory debugging and profiling
    strace            # System call tracer
    ltrace            # Library call tracer
    binutils          # objdump, readelf, nm, etc.
    elfutils          # eu-readelf, eu-stack, etc.
    patchelf          # Modify ELF executables
  ];

  # Set environment variables for debuggers to find debug info
  environment.variables = {
    # GDB will search these paths for separate debug files
    DEBUGINFOD_URLS = "";  # Disable fedora/arch debuginfod servers
  };

  # Optional: Enable core dumps for debugging crashes
  # systemd.coredump.enable = true;
  # systemd.coredump.extraConfig = ''
  #   Storage=external
  #   MaxUse=10G
  # '';
}
