{ pkgs, ... }:
{
  home.packages = with pkgs; [
    lldb # LLVM Debugger with full debug symbols
    llvmPackages_latest.lldb # Latest LLDB
  ];

  home.file.".lldbinit".source = ./lldbinit;
}
