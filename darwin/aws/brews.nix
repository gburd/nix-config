_: {
  homebrew = {
    casks = [
      "discord"
      "firefox"
      "font-fira-code"
      # NOTE: font-fira-mono-for-powerline and font-meslo-for-powerlevel10k were
      # dropped -- they were powerline-glyph fonts for prompts we no longer run
      # (powerline-go is disabled; powerlevel10k was never used). The Nerd Font
      # casks below stay: Zed asks for "JetBrainsMono Nerd Font" and neovim's
      # mini.statusline keys off have_nerd_font.
      "font-fira-mono-nerd-font"
      "font-sauce-code-pro-nerd-font"
      "github"
      "kaleidoscope"
      "keepassxc"
      # Mailspring GUI mail client, darwin ONLY. This is the upstream cask (a
      # notarized .app), unrelated to the Linux build, which was REMOVED from
      # floki: the nixpkgs .deb wrapper is broken at runtime (a renderer-side
      # dlopen of libstdc++.so.6 fails because upstream's runtimeDependencies
      # omits the C++ runtime, so the app never finishes loading). The cask
      # does not share that packaging and is unaffected.
      #
      # It also never carried the Nix asar patches the Linux build applied
      # (Message-ID domain from sender, "Mailspring" -> "Other" mailbox), so
      # mail sent from here still advertises @getmailspring.com in its
      # Message-ID. Revisit if that matters on this host.
      "mailspring"
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
