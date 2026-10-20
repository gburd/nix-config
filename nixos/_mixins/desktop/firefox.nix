{ pkgs, ... }: {
  programs.firefox = {
    enable = true;
    languagePacks = [ "en-US" ];
    package = pkgs.unstable.firefox;

    # Hand mailto: links to the OS default handler (neomutt, via the
    # neomutt-mailto.desktop in console/neomutt/default.nix + the
    # xdg.mimeApps association) instead of showing Firefox's own
    # "choose an application" chooser each time.
    #   external.mailto = true : treat mailto as an external-protocol handler
    #   warn-external.mailto = false : don't prompt before launching it
    # Status "user" makes each a changeable default, not a locked policy, so
    # it can still be overridden in about:config.
    policies.Preferences = {
      "network.protocol-handler.external.mailto" = { Value = true; Status = "user"; };
      "network.protocol-handler.warn-external.mailto" = { Value = false; Status = "user"; };
    };
  };
}
