{ pkgs, ... }:
# Proton desktop apps for GUI hosts (floki, arnold):
#   - Proton Pass  (proton-pass)        — password manager GUI
#   - Proton Mail  (protonmail-desktop) — the Electron mail client
#   - Proton Meet                       — WEB-ONLY (no Linux app); a .desktop
#                                         launcher opens meet.proton.me
# Proton Mail Bridge (the IMAP/SMTP gateway) is a separate systemd SERVICE
# in services/protonmail-bridge.nix; Proton Drive is services/proton-drive.nix.
{
  home.packages = with pkgs; [
    proton-pass
    protonmail-desktop
  ];

  # Proton Meet has no native Linux client — it runs in the browser. Provide
  # a menu launcher that opens the web app (uses the default browser).
  xdg.desktopEntries.proton-meet = {
    name = "Proton Meet";
    genericName = "Video Conferencing";
    comment = "Proton Meet (web app)";
    exec = "xdg-open https://meet.proton.me";
    terminal = false;
    type = "Application";
    categories = [ "Network" "VideoConference" "AudioVideo" ];
  };
}
