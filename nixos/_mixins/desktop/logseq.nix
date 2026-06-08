{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    logseq
  ];

  # required due to outdated version of Electron used for Logseq
  # (logseq 0.10.15 now bundles Electron 39, which the current nixpkgs
  # flags as EOL/insecure — was 25.9.0 in older nixpkgs).
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];
}
