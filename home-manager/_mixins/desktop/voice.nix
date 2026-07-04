{ config, lib, pkgs, ... }:
# Voice dictation — a version-independent local speech-to-text that types the
# transcription into whatever app has focus. Replaces the GNOME whisper
# extensions (which lag the shell version and broke on GNOME 49). Uses
# whisper.cpp (local, no cloud) + ydotool (uinput typing, works on
# GNOME/Wayland where wtype doesn't). This is the Linux equivalent of Kun
# Chen's OpenSuperWhisper workflow.
#
# `dictate` is a TOGGLE: run it once to start recording, run it again to stop,
# transcribe, and type the text at the cursor. Bind it to a keyboard shortcut
# (a GNOME custom keybinding is added below) for push-to-talk-style use:
# tap the key, speak, tap again.
#
# Model + language are options. The model auto-downloads to
# ~/.local/share/whisper/ on first use.
let
  cfg = config.programs.ai.voice;
  inherit (lib) mkEnableOption mkOption mkIf types;

  dictate = pkgs.writeShellApplication {
    name = "dictate";
    runtimeInputs = [
      pkgs.whisper-cpp
      pkgs.pipewire # pw-record
      pkgs.ydotool
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.coreutils
      pkgs.procps
    ];
    text = ''
      set -euo pipefail
      MODEL_NAME="${cfg.model}"
      LANG_CODE="${cfg.language}"
      DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/whisper"
      RUN="''${XDG_RUNTIME_DIR:-/tmp}/dictate"
      WAV="$RUN/rec.wav"
      PIDF="$RUN/rec.pid"
      mkdir -p "$DATA" "$RUN"

      notify() { notify-send -t 2000 -a dictate "$1" "''${2:-}" 2>/dev/null || true; }

      # --- Toggle: if a recording is in progress, stop + transcribe ---------
      if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
        kill "$(cat "$PIDF")" 2>/dev/null || true
        rm -f "$PIDF"
        # give the recorder a moment to flush the WAV
        sleep 0.3
        notify "Transcribing…"
        MODEL="$DATA/ggml-$MODEL_NAME.bin"
        if [ ! -f "$MODEL" ]; then
          notify "Downloading whisper model" "$MODEL_NAME (one-time)"
          whisper-cpp-download-ggml-model "$MODEL_NAME" "$DATA" >/dev/null 2>&1 || {
            notify "dictate: model download failed"; exit 1; }
        fi
        # Transcribe to a text file, no timestamps.
        OUT="$RUN/out"
        whisper-cli -m "$MODEL" -f "$WAV" -l "$LANG_CODE" -nt -otxt -of "$OUT" >/dev/null 2>&1 || {
          notify "dictate: transcription failed"; exit 1; }
        TEXT="$(tr -d '\r' < "$OUT.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
        [ -n "$TEXT" ] || { notify "dictate: (nothing heard)"; exit 0; }
        # Copy to clipboard as a fallback, then type it at the cursor.
        printf '%s' "$TEXT" | wl-copy 2>/dev/null || true
        if ! ydotool type -- "$TEXT" 2>/dev/null; then
          notify "dictate: typed to clipboard (paste with Ctrl+V)" "$TEXT"
        fi
        exit 0
      fi

      # --- Otherwise: start recording (16kHz mono, whisper's native rate) ---
      rm -f "$WAV"
      notify "Listening…" "run dictate again to stop"
      pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
      echo $! > "$PIDF"
    '';
  };
in
{
  options.programs.ai.voice = {
    enable = mkEnableOption "local voice dictation (whisper.cpp + ydotool)";
    model = mkOption {
      type = types.str;
      default = "base.en";
      description = ''
        whisper.cpp model (tiny.en / base.en / small.en / medium.en / …).
        Bigger = more accurate + slower. Auto-downloaded on first use.
      '';
    };
    language = mkOption {
      type = types.str;
      default = "en";
      description = "Spoken language code ('auto' to auto-detect).";
    };
    keybinding = mkOption {
      type = types.str;
      default = "<Super>d";
      description = "GNOME custom shortcut bound to `dictate` (toggle record).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ dictate ];

    # GNOME custom keybinding -> dictate (toggle). Appended to the custom
    # keybindings list. NOTE: this assumes GNOME (dconf); harmless elsewhere.
    dconf.settings = {
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dictate/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dictate" = {
        name = "Dictate (voice to text)";
        command = "${dictate}/bin/dictate";
        binding = cfg.keybinding;
      };
    };
  };
}
