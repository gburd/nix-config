{ pkgs, ... }:
{
  # borgbackup is provided by services/borgmatic.nix; vorta is the GUI frontend
  # for browsing/restoring archives. Imported only on hosts that have a
  # desktop session (floki, meh); arnold is headless and doesn't import this.
  home.packages = with pkgs; [
    vorta
  ];

  systemd.user.services = {
    vorta = {
      Unit = {
        Description = "Vorta";
        # Vorta is a Qt GUI — it must NOT start until the user's graphical
        # session is up (DISPLAY / WAYLAND_DISPLAY exported into the
        # systemd-user environment). With the previous WantedBy=default.target,
        # the daemon raced login on every reboot, hit
        #   "could not connect to display ... no Qt platform plugin could be
        #    initialized"
        # crashed with SIGABRT, restarted 5x in 5s, and got marked failed by
        # systemd's burst limiter ("Start request repeated too quickly").
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.vorta}/bin/vorta --daemonise";
        Restart = "on-failure";
        # Pause between restarts so a transient crash doesn't burn through the
        # default 5-fast-restarts-in-10s limit and end up permanently failed.
        RestartSec = 5;
      };
      Install = {
        # Tie lifecycle to the graphical session: Vorta starts when GNOME
        # comes up and stops when the session ends. Avoids the start-before-
        # display race entirely.
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
