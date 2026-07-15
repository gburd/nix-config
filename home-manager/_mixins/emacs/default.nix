{ pkgs, config, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-gtk;

    overrides = final: _prev: {
      nix-theme = final.callPackage ./theme.nix { inherit config; };
    };
    # burd.org uses `use-package-always-ensure t`. On a pure/offline nix Emacs
    # (floki/meh/arnold) every :ensure'd package must be provided HERE or Emacs
    # errors on startup trying to fetch from ELPA. Keep this in sync with the
    # (use-package ...) forms in burd.org. Built-ins (server, eglot, cc-mode,
    # js, sh-script, conf-mode, make-mode, sql) are :ensure nil and need nothing.
    extraPackages = epkgs: with epkgs; [
      # theme + core
      nix-theme
      solarized-theme
      which-key
      mmm-mode
      exec-path-from-shell
      # evil
      evil
      evil-org
      evil-collection
      evil-surround
      # modern completion / UI
      vertico
      orderless
      marginalia
      consult
      company
      company-c-headers
      # org + writing
      org
      writegood-mode
      deft
      graphviz-dot-mode
      # vcs / project / lint / lsp
      magit
      lsp-mode
      flycheck
      flycheck-rust
      editorconfig
      ag
      paredit
      # language modes
      nix-mode
      cmake-mode
      meson-mode
      erlang
      elixir-mode
      rust-mode
      cargo
      go-mode
      python-mode
      markdown-mode
      yaml-mode
      toml-mode
      web-mode
      dockerfile-mode
      coffee-mode
      feature-mode
      haml-mode
      haskell-mode
      lua-mode
      php-mode
      scala-mode
      sml-mode
      terraform-mode
    ];

    extraConfig = builtins.readFile ./init.el;
  };
  services.emacs = {
    enable = true;
    client.enable = true;
    defaultEditor = true;
    socketActivation.enable = true;
  };
}
