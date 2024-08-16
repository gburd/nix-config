{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    zed-editor
  ];
}
