_:
# ydotool — synthetic keyboard input via uinput, for the `dictate` voice
# script (types the whisper transcription at the cursor on Wayland). Enabled
# now that the voice feature is safe: the old "(keyboard clicking)…" feedback
# loop is bounded by dictate's record cap, min-transcript floor, and the
# STT<->TTS mutual-exclusion lock (see home-manager .../desktop/voice.nix).
# programs.ydotool.enable runs ydotoold as a SYSTEM service (needs uinput)
# with the socket at /run/ydotoold/socket and exports YDOTOOL_SOCKET so
# `ydotool` clients find it.
{
  programs.ydotool.enable = true;
}
