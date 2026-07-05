{ ... }:
# ydotool — synthetic keyboard input via uinput, for the `dictate` voice
# script. DISABLED: the voice feature is off (see floki.nix) after the
# dictate toggle + ydotool auto-typing created a "(keyboard clicking)…"
# feedback loop. Re-enable together with a reworked, safe dictate (push-to-
# hold, hard record cap, no auto-type feedback path).
{
  programs.ydotool.enable = false;
}
