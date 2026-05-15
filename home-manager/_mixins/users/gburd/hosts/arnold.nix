{ lib, pkgs, ... }:
with lib.hm.gvariant;
{
  # Arnold is a Fedora system running home-manager via Nix (not NixOS)
  # No sops-nix, no GNOME desktop, no email/calendar services
  imports = [
    # console and cli are imported by users/gburd/default.nix for all hosts
    ../../../console/ai         # AI tools (opt-in; sops `or null` fallbacks safe without sops)
    ../../../services/borgmatic.nix
  ];

  home.sessionVariables = {
    AWS_PROFILE = "isengard";
  };

  # Arnold-specific SSH hosts
  programs.ssh.matchBlocks = {
    "agora-deploy" = lib.hm.dag.entryBefore [ "*" ] {
      host = "fra fra.postgr.esq 89.145.162.3 gva gva.postgr.esq 185.19.30.253";
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
      repeat-interval = mkUint32 17;  # ~60 keys/sec
      delay = mkUint32 200;           # 200ms initial delay
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
    luajitPackages.luarocks  # for neovim (LuaJIT)
    luarocks                 # for standalone Lua 5.1
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
    bitnet        # BitNet b1.58 2B-4T 1-bit LLM inference (CPU-optimized)
    lmstudio      # Local LLM runner (LM Studio)
    maki          # AI coding agent from gburd/maki
    terax-ai      # AI assistant UI (Bedrock support pending upstream issue #138)
  ];
}
