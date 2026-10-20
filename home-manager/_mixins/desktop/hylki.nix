{ pkgs, ... }:
# Hylki — GNOME-native email client (GTK4/libadwaita/relm4), built from
# source in pkgs/hylki.
#
# GUI hosts only, and Linux only: upstream publishes no macOS artifact and
# the stack is GTK4/libadwaita against the GNOME 50 runtime, so the aws Mac
# cannot run it. Imported by floki (GNOME) and arnold (Fedora + home-manager,
# which runs GUI apps over X11).
#
# It is a mail CLIENT, not a transport: like neomutt it talks to the local
# Proton Bridge (127.0.0.1:1143 IMAP / 1025 SMTP), so the bridge must be
# running and logged in for it to reach a mailbox. Account setup is
# interactive and per-host; nothing here configures an account.
#
# SPELL CHECK: Hylki composes in a WebKitGTK editable web view, and WebKit's
# spell checker runs through enchant -> hunspell. Hylki enables checking and
# feeds enchant the language (src/ui/rich_editor.rs), but enchant underlines
# nothing until a dictionary exists -- and /run/current-system/sw/share/
# hunspell was empty. Shipping the en_US hunspell dict (and enchant) in this
# profile puts share/hunspell/en_US.{dic,aff} on XDG_DATA_DIRS, where
# enchant's hunspell provider finds it. Verified: with the dict on
# XDG_DATA_DIRS, `enchant-lsmod-2` lists "en_US (hunspell)" and enchant flags
# "speling". Turn it on per-compose from the composer's right-click
# "Spelling" menu (the Spelling Language choice is wired in rich_editor.rs).
#
# GRAMMAR: your prose/grammar checker is harper (harper-ls), an LSP used by
# neovim/zed/emacs. It CANNOT integrate here -- a WebKit compose view has no
# LSP client -- so Hylki gets spell-check only, not harper grammar. Compose
# long prose in an editor when you want harper's grammar checking.
{
  home.packages = [
    pkgs.hylki
    # WebKit spell-check backend + the dictionary it was missing.
    pkgs.enchant
    pkgs.hunspellDicts.en_US
  ];
}
