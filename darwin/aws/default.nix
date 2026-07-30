# Device:      MacBook Air (M3, 2024)
# CPU:         Apple M3 (aarch64-darwin)
# Model:       Mac15,7
# Hostname:    80a99738d7e2 (aliased as "aws")

{ username, ... }: {
  imports = [
    ../_mixins/console/homebrew.nix
    ./brews.nix
  ];

  networking = {
    hostName = "80a99738d7e2";
    # Alias: use `ssh aws` via ~/.ssh/config, not nix-darwin networking
  };

  # Preserve Touch ID for sudo (matches the pre-existing /etc/pam.d/sudo_local
  # that we move aside as *.before-nix-darwin on first activation).
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = username;

    defaults = {
      dock = {
        autohide = true;
        orientation = "left";
        # tilesize not explicitly set — uses macOS default
      };
      finder = {
        AppleShowAllExtensions = true;
        # ShowPathbar and ShowStatusBar not explicitly set
      };
      trackpad = {
        # Clicking = false (tap-to-click disabled on this machine)
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
