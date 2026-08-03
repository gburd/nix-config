{ inputs, lib, pkgs, config, ... }:
with lib.hm.gvariant;
let
  # Orion browser flatpak bundle (see the installOrionBrowser activation
  # below for why this is a direct bundle fetch, not a Flathub install).
  # Bump both the URL and hash together when a newer release is wanted.
  orionBrowserBundle = pkgs.fetchurl {
    url = "https://orionbrowser.com/download/oriongtk.0.3.0.flatpak";
    hash = "sha256-0NOWPS2Yv5NpnTxqsiMvshHFyTyDotPi964/2og/bCw=";
  };
in
{
  imports = [
    # NOTE: impermanence only works with home-manager as NixOS module
    # Not compatible with standalone home-manager switch command
    # inputs.impermanence.nixosModules.home-manager.impermanence
    ../../../console/ai # Opt-in AI configuration for this host
    ../../../desktop/vorta.nix
    ../../../services/borgmatic.nix
    ../../../desktop/sublime.nix
    ../../../desktop/sublime-merge.nix
    ../../../desktop/sublime-license.nix
    ../../../desktop/proton-apps.nix
    ../../../desktop/typora.nix
    ../../../desktop/wezterm.nix
    ../../../desktop/voice.nix
    ../../../services/protonmail-bridge.nix
    ../../../services/vdirsyncer.nix
    ../../../services/proton-drive.nix
    ../../../console/khal.nix
    ../../../console/taskbook.nix
    # SSH key management with rotation
    (inputs.self + "/modules/home-manager/ssh-management")
  ];
  # LMStudio NPU-accelerated local models (floki has Intel Arc NPU)
  programs.ai.lmstudio.enable = true;

  # Claude Max/Pro subscription (claude-max-opus-4-8 model row in LiteLLM),
  # alongside the existing Bedrock rows. Bedrock stays the default for every
  # agent (claude/pi/maki/codex/hermes' defaultModel = claude-opus-4-8);
  # this is opt-in per-request by naming the model explicitly. Token from
  # `claude setup-token`, sops-deployed (see sops.secrets below).
  programs.ai.litellm.anthropicAuthTokenFile =
    "${config.home.homeDirectory}/.config/claude-code/.anthropic_oauth_token";

  # Local voice I/O — ENABLED. The original feedback-loop risk (dictate's
  # ydotool auto-typing runaway) is now bounded: a hard maxRecordSeconds cap
  # (auto-stops the mic), a minTranscriptChars floor (won't auto-type
  # suspiciously-short/garbage transcriptions), and a shared voice-lock that
  # makes it STRUCTURALLY impossible for STT (dictate) and TTS (speak) to run
  # at the same time — so pocket-tts output can never be picked up by the mic
  # and re-transcribed. STT: whisper.cpp + ydotool, Super+D toggle. TTS:
  # pocket-tts via the `speak <text>` command.
  programs.ai.voice.enable = true;
  programs.ai.voice.tts.enable = true;

  # Orion browser (Kagi's WebKitGTK browser) -- proprietary, not packaged in
  # nixpkgs and not published on Flathub, only distributed as a direct
  # single-file flatpak BUNDLE from orionbrowser.com. fetchurl makes Nix the
  # one that downloads/verifies/caches it (reproducible, garbage-collectable
  # like anything else in the store) instead of a raw `curl | flatpak install`
  # in an activation script. Requires org.gnome.Platform/x86_64/49 from
  # Flathub (confirmed via the bundle's own embedded metadata --
  # `runtime=org.gnome.Platform/x86_64/49`). No passwordless sudo is
  # configured for this user (confirmed: no wheelNeedsPassword override
  # anywhere in nixos/_mixins), so a system-wide flatpak install from a
  # home.activation script would hang forever on a password prompt --
  # install --user instead, and add a USER-scoped Flathub remote here so
  # the runtime dependency resolves without depending on (or fighting
  # over scope with) the SYSTEM-wide remote ../../_mixins/services/flatpak.nix
  # adds. Both `remote-add --if-not-exists` and `install --or-update` are
  # idempotent -- safe to run on every switch.
  home.activation.installOrionBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists \
      flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 || true
    ${pkgs.flatpak}/bin/flatpak install --user --or-update -y --noninteractive \
      ${orionBrowserBundle} 2>&1 | ${pkgs.gnugrep}/bin/grep -v '^$' || true
  '';



  # Proton Drive (rclone native protondrive backend; on-demand FUSE mount).
  services.protonDrive.enable = true;

  # GNOME configuration
  dconf.settings = {
    # Disable paste warnings in GNOME Console
    "org/gnome/Console" = {
      unsafe-paste-warning = false;
    };

    # Fix Alt-Tab window switching
    "org/gnome/desktop/wm/keybindings" = {
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
      # Alternative app switcher (if using grouped mode)
      switch-applications = [ ];
      switch-applications-backward = [ ];
    };

    # Power management: Performance profile on AC, never auto-suspend
    "org/gnome/settings-daemon/plugins/power" = {
      power-profile-on-ac = "performance"; # max performance when plugged in
      power-profile-on-battery = "power-saver"; # conservative when on battery
      sleep-inactive-ac-type = "nothing"; # don't suspend on AC when idle
      sleep-inactive-ac-timeout = 0; # 0 = never
    };
  };

  # Sops secrets configuration
  sops = {
    # Use flake root to reference secrets file cleanly
    defaultSopsFile = "${inputs.self}/nixos/workstation/floki/secrets.yaml";
    # Use age key derived from SSH key for decryption
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      "aws/bearer_token_bedrock" = {
        path = "${config.home.homeDirectory}/.config/claude-code/.bearer_token";
      };
      "anthropic/claude_max_oauth_token" = {
        path = "${config.home.homeDirectory}/.config/claude-code/.anthropic_oauth_token";
      };
      # Dedicated Tailscale auth key for the agent-sandbox ec2 tier --
      # deliberately SEPARATE from the tailscale-auth-key used to join
      # real, long-lived hosts (nixos/_mixins/services/tailscale-autoconnect.nix):
      # that key's ephemeral/reusable flags are unknown from the key
      # string alone, and reusing it for throwaway EC2 boxes risks either
      # leaving permanent zombie device entries (if not ephemeral) or
      # being fine (if it is) -- not worth the ambiguity. Mint this ONE
      # specifically: https://login.tailscale.com/admin/settings/keys ->
      # Generate auth key -> Reusable + Ephemeral + tag:agent-sandbox.
      # Ephemeral is what makes `agent-sandbox --tier ec2 down --terminate`
      # need ZERO explicit teardown code -- Tailscale itself removes an
      # ephemeral node's device entry once it disconnects, which happens
      # automatically the moment the underlying EC2 instance is gone.
      "tailscale/agent-sandbox-key" = {
        path = "${config.home.homeDirectory}/.config/agent-sandbox/tailscale.key";
      };
      # Crates.io API token (exposed as $CARGO_REGISTRY_TOKEN by console/cargo.nix)
      "cargo/crates_io_token" = { };
      "jetbrains/clion-key" = {
        path = "${config.home.homeDirectory}/.config/JetBrains/clion.key";
      };

      # SSH key management (new)
      "ssh-keys/auth" = {
        path = "${config.home.homeDirectory}/.ssh/id_auth_ed25519";
      };
      "ssh-keys/signing" = {
        path = "${config.home.homeDirectory}/.ssh/id_signing_ed25519";
      };

      # Borg backup passphrase and SSH key (used by borgmatic)
      "backup/borg-passphrase" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.passphrase";
      };
      "backup/rsync-ssh-key" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.rsync-key";
        mode = "0600";
      };
      "backup/borg-keyfile" = {
        path = "${config.home.homeDirectory}/.config/borg/keys/zh6216_rsync_net__borg";
        mode = "0600";
      };

      # Email account credentials (nested structure)
      "email/proton/user" = { };
      "email/proton/pass" = { };
      "email/google/personal/user" = { };
      "email/google/personal/pass" = { };
      "email/google/pgus/user" = { };
      "email/google/pgus/pass" = { };
      "email/fastmail/user" = { };
      "email/fastmail/pass" = { };
      "email/apple/icloud/user" = { };
      "email/apple/icloud/pass" = { };
      "email/ms/outlook/user" = { };
      "email/ms/outlook/pass" = { };
      "email/amazon/user" = { };
      "email/amazon/pass" = { };

      # Calendar credentials (nested structure)
      "calendar/google/personal/client-id" = { };
      "calendar/google/personal/secret" = { };
      "calendar/google/pgus/client-id" = { };
      "calendar/google/pgus/secret" = { };
      "calendar/apple/icloud/user" = { };
      "calendar/apple/icloud/pass" = { };
      "calendar/ms/outlook/user" = { };
      "calendar/ms/outlook/pass" = { };

      # Proton Drive credentials (nested structure)
      "drive/proton/user" = { };
      "drive/proton/pass" = { };
    };
  };

  # Activation script to link CLion license to all version directories
  home.activation.linkClionLicense = lib.mkIf (config.sops.secrets ? "jetbrains/clion-key") (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CLION_LICENSE="${config.sops.secrets."jetbrains/clion-key".path}"

      if [ -f "$CLION_LICENSE" ]; then
        # Find all CLion version directories and create symlinks
        for clion_dir in ${config.home.homeDirectory}/.config/JetBrains/CLion*; do
          if [ -d "$clion_dir" ]; then
            TARGET="$clion_dir/clion.key"
            # Remove existing file/symlink if it exists
            if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
              rm -f "$TARGET"
            fi
            # Create symlink
            ln -sf "$CLION_LICENSE" "$TARGET"
            echo "Linked CLion license to $TARGET"
          fi
        done
      else
        echo "Warning: CLion license not found at $CLION_LICENSE"
      fi
    ''
  );

  # Sublime Text + Merge licenses are deployed by
  # ../../../desktop/sublime-license.nix (shared with arnold).

  # SSH key management with rotation support (replaces GPG signing with SSH)
  services.ssh-management = {
    enable = true;

    authKey = {
      secret = config.sops.secrets."ssh-keys/auth".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6HS8oDnpvGKTisMx38pq1I3YJP4+ds7WIYF+L578dW greg@burd.me-auth-floki-202604";
    };

    signingKey = {
      secret = config.sops.secrets."ssh-keys/signing".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ31SSVgFMDHNic/+zA41muVDVIuPVaUOnKIXJ31PyTb greg@burd.me-signing-floki-202604";
    };

    rotationInterval = "quarterly";
    sync1Password = true;
    gitHostingServices = [ "github" "codeberg" ];
  };

  home = {
    # NOTE: persistence disabled for standalone home-manager
    # Enable in NixOS configuration if using home-manager as NixOS module
    # persistence = {
    #   "/persist/home/gburd" = {
    #     directories = [
    #       "Documents"
    #       "Downloads"
    #       "Pictures"
    #       "Videos"
    #       ".local/bin"
    #       ".config"
    #     ];
    #     allowOther = true;
    #   };
    # };

    file.".inputrc".text = ''
      "\C-v": ""
      set enable-bracketed-paste off
    '';

    # Pan NNTP newsreader: pre-configure pg.ddx.io (PostgreSQL mailing lists)
    file.".pan2/servers.xml".text = ''
      <?xml version="1.0" encoding="utf-8" ?>
      <server-properties>
        <server>
          <host>nntp.pg.ddx.io</host>
          <port>563</port>
          <use-ssl>1</use-ssl>
          <connection-limit>2</connection-limit>
          <rank>1</rank>
        </server>
      </server-properties>
    '';

    file.".config/direnv/direnv.toml".text = ''
      [global]
      load_dotenv = true
    '';

    file.".envrc".text = ''
      ENVFS_RESOLVE_ALWAYS=1
    '';

    file.".config/Code/User/settings.json".text = ''
      {
          "editor.inlineSuggest.enabled": true,
          "editor.fontFamily": "'FiraCode Nerd Font Mono', 'Droid Sans Mono', 'monospace', monospace",
          "editor.fontLigatures": true,
          "cSpell.userWords": [
              "Burd",
              "Wpedantic",
              "Wvariadic"
          ],
          "files.watcherExclude": {
              "**/.bloop": true,
              "**/.metals": true,
              "**/.ammonite": true
          },
          "extensions.experimental.affinity": {
              "asvetliakov.vscode-neovim": 1
          },
          "vscode-neovim.neovimExecutablePaths.linux": "${config.home.homeDirectory}/.nix-profile/bin/nvim",
      }
    '';

    # file.".config/Code/User/keybindings.json".text = ''
    #   // Place your key bindings in this file to override the defaults
    #   [
    #   ]
    # '';


    packages = with pkgs; [
      # Shared CLI/dev packages are hoisted to users/gburd/default.nix.
      # Below: floki-specific packages only.
      _1password-gui
      cmake
      flatpak # CLI for the Orion browser bundle install below (flatpak run com.kagi.OrionGtk)
      mailspring # GUI mail client (patched: randomized Message-ID, see overlays/default.nix)
      plocate
      telegram-desktop
      unstable.element-desktop
      unstable.minio-client

      # AI tools
      kiro-cli # Kiro CLI agent for the terminal
      # kiro-ide    # Kiro IDE (download URLs return 404 — not yet publicly available)
      unstable.lmstudio # LM Studio (unstable: near-current; stable is stuck on 0.4.1)
      # maki installed (wrapped) by modules/home-manager/ai/maki.nix
      terax-ai # AI assistant UI (Bedrock support pending upstream issue #138)

      # PostgreSQL community
      pan # GTK NNTP newsreader (pg.ddx.io PostgreSQL mailing lists)
    ];

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    # Disabled: Conflicts with NixOS-level debug-symbols.nix (both provide /lib/debug/getconf)
    # enableDebugInfo = true;
  };
}
