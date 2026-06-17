{ config, lib, pkgs, ... }:
# Keybase: the core service (daemon) + KBFS filesystem on every host (TUI
# usable everywhere via the `keybase` CLI), plus the GUI (keybase-gui) on
# hosts that opt in. meh is headless terminal-only (gui = false); floki and
# arnold are GUI hosts (gui = true). Replaces the older orphaned
# desktop/keybase.nix + services/keybase.nix + services/keybase-gui.nix.
let
  inherit (lib) mkEnableOption mkOption types mkIf;
  c = config.services.keybaseClient;
in
{
  options.services.keybaseClient = {
    enable = mkEnableOption "Keybase service + KBFS (CLI/TUI on all hosts)";
    gui = mkOption {
      type = types.bool;
      default = false;
      description = "Also install + autostart the Keybase GUI (desktop hosts only).";
    };
  };

  config = mkIf c.enable {
    # Core keybase daemon (home-manager's services.keybase) — provides the
    # `keybase` CLI/TUI and the background service both GUI and TUI need.
    services.keybase.enable = true;

    # KBFS — the Keybase encrypted filesystem, mounted at ~/Keybase.
    services.kbfs = {
      enable = true;
      mountPoint = "Keybase";
    };

    # GUI: package + a systemd-user unit, only on opted-in desktop hosts.
    home.packages = lib.optional c.gui pkgs.keybase-gui;

    systemd.user.services.keybase-gui = mkIf c.gui {
      Unit = {
        Description = "Keybase GUI";
        # GUI needs the keybase service + a graphical session.
        After = [ "keybase.service" "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.keybase-gui}/bin/keybase-gui";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
