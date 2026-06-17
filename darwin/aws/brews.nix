_: {
  homebrew = {
    casks = [
      "alacritty"
      "firefox"
      "font-fira-code"
      "font-fira-mono-for-powerline"
      "font-fira-mono-nerd-font"
      "font-sauce-code-pro-nerd-font"
      "github"
      "keepassxc"
      "sublime-merge"
      "zed"
    ];

    # Formulae not yet in nixpkgs or easier via brew on macOS
    brews = [
      "mise"
    ];

    masApps = {
      # Add Mac App Store apps by ID if needed
      # "Xcode" = 497799835;
    };
  };
}
