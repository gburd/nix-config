# Device:      MacBook Air (M3, 2024)
# CPU:         Apple M3
# Model:       Mac15,7

{ username, ... }: {
  imports = [
    ../_mixins/console/homebrew.nix
    ./brews.nix
  ];

  networking.hostName = "80a99738d7e2";

  system = {
    # Required in nix-darwin 26.05
    primaryUser = username;

    defaults = {
      dock = {
        autohide = true;
        orientation = "bottom";
        tilesize = 80;
      };
      finder = { };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
    };
    keyboard = { enableKeyMapping = true; };
  };
}
