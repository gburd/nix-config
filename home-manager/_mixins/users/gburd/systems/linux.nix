{ desktop ? null, lib, username, ... }: {
  # Desktop-app modules (tilix, audio-recorder, celluloid, etc.) bring in
  # dconf settings that require the GNOME session bus at activation time.
  # On headless hosts (meh, servers) those activations abort the entire
  # home-manager activate run mid-way, dropping every step after
  # `dconfSettings` (setupLitellm, installHermesAgent, sops-nix, …). Gate
  # all desktop imports on `desktop` being set.
  imports = [
    # Keybase service + KBFS on every Linux host (CLI/TUI everywhere); the
    # GUI is opted in per-host via services.keybaseClient.gui (floki/arnold
    # = true, meh = headless/false).
    ../../../services/keybase.nix
  ] ++ lib.optionals (builtins.isString desktop) [
    ../../../desktop/audio-recorder.nix
    ../../../desktop/celluloid.nix
    ../../../desktop/dconf-editor.nix
    ../../../desktop/gnome-sound-recorder.nix
    ../../../desktop/tilix.nix
    # ../../../desktop/emote.nix  # Disabled - user doesn't want emoticons
  ];

  # Keybase on every Linux host. TUI/CLI + KBFS everywhere; GUI only where
  # there's a graphical session. Defaults gui to (desktop != null), which
  # covers floki (gnome). arnold has desktop=null but runs GUI apps over
  # X11, so it overrides gui=true in its host file.
  services.keybaseClient = {
    enable = true;
    gui = builtins.isString desktop;
  };

  home = {
    file."Quickemu/nixos-console.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-console/disk.qcow2"
      disk_size="96G"
      iso="nixos-console/nixos.iso"
    '';
    file."Quickemu/nixos-desktop.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-desktop/disk.qcow2"
      disk_size="96G"
      iso="nixos-desktop/nixos.iso"
    '';
    file."Quickemu/nixos-nuc.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-nuc/disk.qcow2"
      disk_size="96G"
      iso="nixos-nuc/nixos.iso"
    '';
  };

  systemd.user.tmpfiles.rules = [
    "d /home/${username}/ws                           0755 ${username} users - -"
  ];
}
