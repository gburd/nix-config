{ ... }:
# ydotool — synthetic keyboard input via uinput, for the `dictate` voice
# script (home-manager/_mixins/desktop/voice.nix). GNOME/Mutter does NOT
# implement the wlr virtual-keyboard protocol that `wtype` needs, so ydotool
# (uinput) is the reliable way to type the transcription into the focused
# app on Wayland. programs.ydotool.enable runs ydotoold + sets uinput perms.
{
  programs.ydotool.enable = true;
}
