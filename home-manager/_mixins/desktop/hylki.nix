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
{
  home.packages = [ pkgs.hylki ];
}
