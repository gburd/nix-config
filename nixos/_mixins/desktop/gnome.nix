{ pkgs, ... }:
{
  imports = [
    ../services/xdg-portal.nix
  ];

  # Enable the graphical windowing system.
  # NOTE: xserver is a legacy naming convention, DEs may still use Wayland over X11
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.desktopManager.gnome.enable = true;

  services.displayManager.gdm = {
    enable = true;
    # 26.05/GNOME 50: gdm.wayland can no longer be toggled (wayland-only);
    # the option was removed. wayland is the default and only mode now.
  };

  # Enable udev rules
  services.udev.packages = with pkgs.unstable; [ gnome-settings-daemon ];

  environment.systemPackages = with pkgs.unstable; [
    gnomeExtensions.appindicator
    # blur-my-shell removed — caused semi-transparent ghost content at screen
    # edges after closing windows on GNOME 49 (blur actors miss repaints).
    gnomeExtensions.pop-shell
    gnome-tweaks
  ];
  # Voice dictation is NOT a GNOME extension (the whisper extensions lag the
  # shell version and broke on GNOME 49). It's the version-independent
  # `dictate` script instead — see home-manager/_mixins/desktop/voice.nix +
  # nixos/_mixins/desktop/ydotool.nix.

  # Exclude packages
  environment.gnome.excludePackages = with pkgs; [
    # for packages that are pkgs.***
    gnome-tour
    gnome-connections
    epiphany # web browser
    geary # email reader
    evince # document viewer
  ];

  # gcr-ssh-agent: clear a stale child socket before (re)starting.
  #
  # gcr-ssh-agent is a wrapper. It runs a real `ssh-agent -D -a
  # $XDG_RUNTIME_DIR/gcr/.ssh` and proxies $XDG_RUNTIME_DIR/gcr/ssh (our
  # SSH_AUTH_SOCK) to it. It removes .ssh only in its GObject finalizer
  # (gcr-4.4.1/gcr/gcr-ssh-agent-process.c:82). The respawn path,
  # agent_start_inlock(), never unlinks first. So when the child is
  # SIGKILLed, the socket file stays, and every respawn fails with
  # "unix_listener: cannot bind to path .../gcr/.ssh: Address already in use"
  # then "ssh-agent process is not ready". The wrapper stays "active", and
  # every client gets "communication with agent failed". gcr 4.4.1 is the
  # newest tag.
  #
  # Seen on floki 2026-10-14: an OOM kill at 10:11 took the child. Every
  # ssh/git login through the agent then failed for 4h, until .ssh was
  # removed and the unit restarted.
  #
  # This handles a restart of the WRAPPER. It cannot help if only the child
  # dies while the wrapper lives; the OOM protection in
  # workstations/common.nix is what keeps the child alive in the first place.
  # ExecStartPre does not run on socket activation into an already-running
  # service, so it cannot remove a live socket.
  systemd.user.services.gcr-ssh-agent.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/rm -f %t/gcr/.ssh";
}
