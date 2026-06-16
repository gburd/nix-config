{ inputs, lib, pkgs, config, ... }:
with lib.hm.gvariant;
{
  # Arnold is a Fedora system running home-manager via Nix (not NixOS)
  imports = [
    # console and cli are imported by users/gburd/default.nix for all hosts
    ../../../console/ai # AI tools (opt-in; sops `or null` fallbacks safe without sops)
    ../../../services/borgmatic.nix
    # Sublime Text + Merge (GUI; arnold forwards X11) and their licenses
    ../../../desktop/sublime.nix
    ../../../desktop/sublime-merge.nix
    ../../../desktop/sublime-license.nix
  ];

  # Sops secrets — reuses floki's secrets.yaml (encrypted to gburd-user age key)
  sops = {
    defaultSopsFile = "${inputs.self}/nixos/workstation/floki/secrets.yaml";
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      "aws/bearer_token_bedrock" = {
        path = "${config.home.homeDirectory}/.config/claude-code/.bearer_token";
      };
      # Crates.io API token (exposed as $CARGO_REGISTRY_TOKEN by console/cargo.nix)
      "cargo/crates_io_token" = { };

      # Borgmatic backup secrets — mirrors floki/meh. Fixes nightly
      # borgmatic.service failure ("cat: ~/.config/borgmatic/.passphrase: No
      # such file or directory") on arnold. The borg-keyfile already exists on
      # arnold from a manual provision; sops will rewrite it byte-identically.
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
    };
  };

  home.sessionVariables = {
    AWS_PROFILE = "asbxbedrock";
  };

  # arnold runs Fedora, whose /etc/ssh/ssh_config Includes
  # /etc/crypto-policies/back-ends/openssh.config. That file sets
  # GSSAPIKexAlgorithms — GSSAPI *key exchange*, a Debian/Fedora downstream
  # patch that is NOT in upstream OpenSSH. nixpkgs' default openssh is
  # built without it (withKerberos defaults to false, and even with it the
  # KexAlgorithms patch is absent), so the Nix ssh that git uses from its
  # own closure fatals with "Bad configuration option: gssapikexalgorithms
  # ... terminating" before it can connect — surfacing as the confusing
  # "Could not read from remote repository".
  #
  # nixpkgs ships pkgs.openssh_gssapi (10.3p1 + Debian gssapi.patch), which
  # DOES understand GSSAPIKexAlgorithms and parses Fedora's crypto-policies
  # file fine. Point git at it (pure-Nix, no dependency on Fedora's
  # /usr/bin/ssh) and make it the interactive ssh too. (This was never a
  # 1Password fault; the 1P SSH agent at ~/.1password/agent.sock — wired
  # via IdentityAgent in ~/.ssh/config — signs fine once the app is
  # unlocked.)
  programs.ssh.package = pkgs.openssh_gssapi;
  programs.git.extraConfig.core.sshCommand = "${pkgs.openssh_gssapi}/bin/ssh";

  # Arnold-specific SSH hosts
  programs.ssh.matchBlocks = {
    "agora-deploy" = lib.hm.dag.entryBefore [ "*" ] {
      host = "fra fra.pg.ddx.io 89.145.162.3 gva gva.pg.ddx.io 185.19.30.253";
      user = "root";
      identityFile = "~/.ssh/agora-deploy";
      identitiesOnly = true;
      extraOptions.IdentityAgent = "none";
    };
    "nuc" = lib.hm.dag.entryBefore [ "*" ] {
      host = "nuc";
      identityFile = "~/.ssh/id_ed25519";
      identitiesOnly = true;
    };
  };

  # Match floki/meh fast keyboard repeat (set in gnome.nix for NixOS hosts)
  dconf.settings = {
    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      repeat-interval = mkUint32 17; # ~60 keys/sec
      delay = mkUint32 200; # 200ms initial delay
    };
  };

  # Create .Xauthority so X11-forwarded SSH connections don't print a warning
  home.activation.createXauthority = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    [ -f "$HOME/.Xauthority" ] || touch "$HOME/.Xauthority"
    chmod 600 "$HOME/.Xauthority"
  '';

  home.file.".inputrc".text = ''
    "\C-v": ""
    set enable-bracketed-paste off
  '';

  home.file.".config/direnv/direnv.toml".text = ''
    [global]
    load_dotenv = true
  '';

  home.packages = with pkgs; [
    # gcc / gdb / gnumake / pkg-config / ripgrep / tig / tree / cmake / autoconf / libtool provided by console
    # clang-tools / pyright / gopls / nixd / lldb / strace / ltrace / valgrind etc. provided by console/neovim
    # awscli2 / ssm-session-manager-plugin / flyctl provided by console/ai and console
    _1password-cli # `op` — headless 1Password CLI (desktop-app integration for SSH agent unlock)
    bash
    bison
    cfssl
    dig
    elixir
    emacs
    erlang
    file
    flex
    go
    htop
    lsof
    lua5_1
    luajitPackages.luarocks # for neovim (LuaJIT) and standalone use
    m4
    ninja
    openssl
    perl
    python3
    readline
    rebar3
    tree-sitter
    xclip
    zlib

    # AI tools
    lmstudio # Local LLM runner (LM Studio)
    # maki installed (wrapped) by modules/home-manager/ai/maki.nix
    # terax-ai   # Disabled: pnpm fetch OOMs on arnold (8GB RAM)
  ];
}
