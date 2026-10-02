{ lib, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    # Use neovim 0.12.x from nixpkgs-unstable (stable 25.11 is still on
    # 0.11.7). 0.12 unlocks the current plugin ecosystem (e.g. telescope
    # master, which moved to the 0.12-only vim.nonnil API) and the native
    # vim.lsp / vim.pack improvements.
    package = pkgs.unstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # 26.05 flipped these defaults true -> false. Pin them explicitly to keep
    # the prior (working) behavior rather than silently drop the ruby/python3
    # remote-plugin providers, and to silence the "default value changed"
    # eval warnings (we deliberately keep home.stateVersion < 26.05).
    withRuby = true;
    withPython3 = true;
    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nixd # Nix LSP (more complete than nil)
      # rust-analyzer is provided by rustup (via languages/rust.nix)
      # to avoid conflicts with rustup's wrapper
      clang-tools # provides clangd
      gopls # Go LSP
      pyright # Python LSP
      sqls # SQL LSP
      taplo # TOML LSP + formatter
      vscode-langservers-extracted # JSON, HTML, CSS, ESLint LSP
      yaml-language-server
      perlPackages.PLS # Perl LSP
      bash-language-server # nodePackages removed in 26.05; moved to top level
      harper # provides harper-ls: offline grammar/prose LSP (also wired into emacs + zed)

      # Formatters
      stylua
      nixpkgs-fmt
      black
      shfmt
      pgformatter # PostgreSQL formatter
      sqlfluff # SQL linter and formatter
      # rustfmt is provided by rustup (via languages/rust.nix)

      # Linters
      shellcheck
      python3Packages.ruff
      python3Packages.mypy
      markdownlint-cli

      # Debuggers
      # lldb comes from console/lldb/default.nix (llvmPackages_latest.lldb);
      # do NOT re-add plain `lldb` here -- on 26.05 it's a different version
      # (21.1.8 vs the module's 22.1.5) and both in home.packages collide.
      python3Packages.debugpy # Python debugger
      delve # Go debugger

      # Testing tools
      python3Packages.pytest

      # Build tools
      meson
      gnumake
      cmake
      cargo-nextest # Better Rust test runner

      # Utilities
      ripgrep
      fd
      # gcc  # Removed: provided by console/default.nix as gcc14
      nnn
      zig
    ];
  };
  xdg.configFile = {
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };
  # harper-ls user dictionary. harper reads prose in comments, docs and
  # commit messages, so PostgreSQL type names quoted in a comment
  # (HeapTuple, TupleDesc, BufferAccessStrategy, ...) were reported as
  # misspellings. Seed the dictionary from pgindent's typedefs.list, which
  # is exactly the set of type names that appear in PG prose, plus a few
  # personal words.
  #
  # Case: harper derives the capitalised form from a lowercase entry, so a
  # single lowercase "burd" covers both "Greg Burd" and "burd.me". Listing
  # both forms is worse than useless -- with "burd" followed by "Burd" the
  # word is flagged again, and "Burd" alone never matches (measured). Add
  # lowercase unless a word is only ever written capitalised.
  #
  # To refresh the vendored list (kept in sync by hand, like the rubo77
  # borgmatic excludes):
  #   cp ~/ws/postgres/master/src/tools/pgindent/typedefs.list \
  #     home-manager/_mixins/console/neovim/harper-dictionary-pgindent.txt
  # Vendored at postgres ddce1da5b1b (2026-09-15), 4572 entries,
  # sha256 83440bf71e27dfc819fdca5d7c14c666c4d08f1a3f87f4c728c7a276957204cd
  #
  # Editors read this via harper's userDictPath (set in
  # lua/kickstart/plugins/lspconfig.lua), so the "add to dictionary" code
  # action appends here too -- which means this file is REPLACED on every
  # switch and hand-added words are lost. Add durable words to
  # extraHarperWords below instead.
  xdg.configFile."harper-ls/dictionary.txt".text =
    let
      pgindentTypedefs = builtins.readFile ./harper-dictionary-pgindent.txt;
      extraHarperWords = [
        "burd" # surname; also covers "Burd" and burd.me
      ];
    in
    pgindentTypedefs + lib.concatMapStrings (w: w + "\n") extraHarperWords;

  # Global markdownlint config (nvim-lint runs markdownlint on .md buffers).
  # markdownlint's prose defaults are noisy: MD010 flags every leading hard
  # tab ("Hard tabs [Column: 1]"), MD013 flags long lines, MD041 demands an
  # H1 first. Silence the ones that fight normal note-taking; a repo-local
  # .markdownlint.json still overrides this if a project wants stricter rules.
  home.file.".markdownlint.json".text = builtins.toJSON {
    MD010 = false; # no-hard-tabs — allow tab indentation
    MD013 = false; # line-length — don't wrap prose
    MD041 = false; # first-line-h1 — not every doc starts with #
    MD024 = false; # duplicate headings (common in changelogs)
    MD033 = false; # inline HTML — allowed
  };
}
