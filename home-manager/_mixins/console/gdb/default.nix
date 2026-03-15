{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gdb # GNU Debugger with full debug symbols
    cgdb # Curses-based interface to GDB
  ];

  home.file.".gdbinit".source = ./gdbinit;

  # Enable debug symbols globally for better debugging experience
  home.sessionVariables = {
    # Ensure debug info is not stripped
    NIX_CFLAGS_COMPILE = "-g";
  };
}
