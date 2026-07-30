_: {
  homebrew = {
    casks = [
      "discord"
      "firefox"
      "font-fira-code"
      "font-fira-mono-for-powerline"
      "font-fira-mono-nerd-font"
      "font-meslo-for-powerlevel10k"
      "font-sauce-code-pro-nerd-font"
      "github"
      "kaleidoscope"
      "keepassxc"
      "podman-desktop"
      "serial"
      "sublime-merge"
      "therm"
      "tla+-toolbox"
      "typora"
      "zed"
    ];

    # Formulae not yet in nixpkgs or easier via brew on macOS
    brews = [
      "ada-url"
      "bear"
      "duckdb"
      "lima"
      "minicom"
      "mise"
      "podman"
      "podman-compose"
      "podman-tui"
      "tea"
    ];

    masApps = {
      # Add Mac App Store apps by ID if needed
      # "Xcode" = 497799835;
    };
  };
}
