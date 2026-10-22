# Device:      MacBook Air (M3, 2024)
# CPU:         Apple M3 (aarch64-darwin)
# Model:       Mac15,7
# Hostname:    80a99738d7e2 (aliased as "aws")

{ username, ... }: {
  imports = [
    ../_mixins/console/homebrew.nix
    # Tailscale/Headscale REMOVED from the aws Mac (2026-10-21, per request).
    # It never registered a node on the Headscale server (no 'aws' node ever
    # appeared), and the config is dropped so a darwin-rebuild switch stops
    # configuring and starting tailscaled here. The module and
    # docs/tailscale-darwin.md are kept for reference / possible re-enable.
    #   ../_mixins/services/tailscale.nix
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
