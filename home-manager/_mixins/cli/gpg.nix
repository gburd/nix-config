{ pkgs, username, ... }:
let
  # Smart pinentry wrapper that auto-detects GUI availability
  pinentry-auto = pkgs.writeShellScriptBin "pinentry-auto" ''
    # Try GUI pinentry if we have a display
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
      # Try GNOME pinentry first (works with GTK and GNOME)
      if command -v ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 >/dev/null 2>&1; then
        exec ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 "$@"
      # Try GTK2 pinentry as fallback
      elif command -v ${pkgs.pinentry-gtk2}/bin/pinentry-gtk2 >/dev/null 2>&1; then
        exec ${pkgs.pinentry-gtk2}/bin/pinentry-gtk2 "$@"
      fi
    fi

    # Fall back to curses for terminal/SSH use
    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
  '';

in
{
  # Only install the wrapper and required library
  # The wrapper uses absolute paths to pinentry variants, so we don't need them in PATH
  home.packages = with pkgs; [
    gcr # GNOME crypto library (required by pinentry-gnome3)
    pinentry-auto # Our smart wrapper
  ];

  services.gpg-agent = {
    #TODO: gnupg vs gpg-agent ?
    enable = true;
    enableSshSupport = true;
    # TODO: sshKeys = [ "149F16412997785363112F3DBD713BC91D51B831" ];
    pinentry.package = pinentry-auto; # Use smart wrapper
    enableExtraSocket = true;
  };

  programs =
    let
      fixGpg = ''
        gpgconf --launch gpg-agent
      '';
      # Update GPG TTY for proper pinentry support (especially for sops)
      updateGpgTty = ''
        export GPG_TTY=$(tty)
        gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
      '';
    in
    {
      # Start gpg-agent if it's not running or tunneled in
      # SSH does not start it automatically, so this is needed to avoid having to use a gpg command at startup
      # https://www.gnupg.org/faq/whats-new-in-2.1.html#autostart
      bash.profileExtra = fixGpg;
      bash.initExtra = updateGpgTty;
      fish.loginShellInit = fixGpg;
      fish.interactiveShellInit = updateGpgTty;
      zsh.loginExtra = fixGpg;
      zsh.initExtra = updateGpgTty;

      gpg = {
        enable = true;
        settings = {
          trust-model = "tofu+pgp";
        };
        publicKeys = [{
          source = ../users/${username}/pgp.asc;
          trust = 5;
        }];
      };
    };

  systemd.user.services = {
    # Link /run/user/$UID/gnupg to ~/.gnupg-sockets
    # So that SSH config does not have to know the UID
    link-gnupg-sockets = {
      Unit = {
        Description = "link gnupg sockets from /run to /home";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/ln -Tfs /run/user/%U/gnupg %h/.gnupg-sockets";
        ExecStop = "${pkgs.coreutils}/bin/rm $HOME/.gnupg-sockets";
        RemainAfterExit = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
# vim: filetype=nix
