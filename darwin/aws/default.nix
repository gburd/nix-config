# Device:      work-issued macOS laptop ("aws" host)
# CPU:         Apple Silicon (aarch64-darwin)
# Hostname:    aws
#
# Starting-point config modelled on 80a99738d7e2 (the existing work laptop).
# An agent on the host will tune this further; this gives parity with the
# other hosts (shared darwin/default.nix: home-manager, AI agents, fish,
# git, overlays, fonts).

{ username, ... }: {
  imports = [
    ../_mixins/console/homebrew.nix
    ./brews.nix
  ];

  networking = {
    hostName = "aws";
  };

  system = {
    primaryUser = username;

    defaults = {
      dock = {
        autohide = true;
        orientation = "left";
      };
      finder = {
        AppleShowAllExtensions = true;
      };
      trackpad = {
        TrackpadRightClick = true;
      };
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };
    };
    keyboard = { enableKeyMapping = true; };
  };
}
