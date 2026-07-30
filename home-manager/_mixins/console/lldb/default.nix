{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Single lldb across the whole config: llvmPackages_latest.lldb (the
    # "latest" the module always wanted). Do NOT also list plain `lldb`
    # here or in neovim/default.nix -- on nixos-26.05 `lldb` (21.1.8) and
    # `llvmPackages_latest.lldb` (22.1.5) are DIFFERENT versions, and
    # buildEnv errors on the conflicting bin/.lldb-wrapped when both land
    # in home.packages (they were the same version on 25.11, so it slipped
    # by before).
    llvmPackages_latest.lldb # LLVM debugger (lldb-dap for Rust/C/C++), latest, full debug symbols
  ];

  home.file.".lldbinit".source = ./lldbinit;
}
