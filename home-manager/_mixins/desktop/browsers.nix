{ pkgs, ... }:
{
  # Browser consolidation: ungoogled-chromium only
  # TODO: Add Orion when download URL and hash are available
  home.packages = with pkgs; [
    ungoogled-chromium
  ];

  # Preserve Chromium profile location
  # Profile data should be at ~/.config/chromium/
}
