_: {
  # Declarative Homebrew for the "aws" work laptop.
  #
  # Split of responsibility:
  #   - Homebrew owns macOS GUI apps (casks), fonts, and a few formulae that are
  #     container-runtime / macOS-specific and awkward via nixpkgs.
  #   - Everything else (ripgrep, jq, eza, neovim, git, gh, cmake, meson, go,
  #     rust/rustup, shellcheck, tree, htop, wget, coreutils, ...) comes from
  #     nixpkgs via the home-manager profile — NOT declared here.
  #   - Amazon Builder Toolbox (brazil, ada, cr, toolbox, q, ...) is NOT managed
  #     by Homebrew or Nix; it self-updates under ~/.toolbox (see the AmznNix
  #     overlay / PATH wiring). Do not add it here.
  #
  # onActivation.cleanup is intentionally left at the default ("none") via
  # ../_mixins/console/homebrew.nix while the full 198-formula reconcile is in
  # progress; flip to "zap" only once this list is complete and verified.
  homebrew = {
    casks = [
      # Actually installed today (capture-what-I-have)
      "podman-desktop"
      "therm"
      "tla+-toolbox"
      "font-fira-code"
      "font-fira-mono-for-powerline"
      "font-fira-mono-nerd-font"
      "font-meslo-for-powerlevel10k"
      "font-sauce-code-pro-nerd-font"

      # Wanted going forward (from the host stub; harmless with cleanup=none)
      "alacritty"
      "firefox"
      "github"
      "keepassxc"
      "sublime-merge"
      "zed"
    ];

    # Formulae kept on Homebrew (container/macOS-preferred); the rest -> nixpkgs.
    brews = [
      "mise"
      "podman"
      "podman-compose"
      "podman-tui"
      "lima"
      "minicom"
      "bear"
      "aws-sam-cli"
      "unison"
    ];

    masApps = {
      # Add Mac App Store apps by ID if needed, e.g.:
      # "Xcode" = 497799835;
    };
  };
}
