{ config, lib, pkgs, ... }:
# Voice I/O — local speech-to-text (dictation) and text-to-speech, both
# fully local/offline (whisper.cpp + piper), no cloud APIs.
#
# SAFETY (the reason this file structures things the way it does): STT
# listening to the mic while TTS is talking out loud is a feedback-loop
# hazard -- piper's own output could be picked up by the mic and
# mis-transcribed as a dictation command, which could itself trigger more
# speech, etc. `voiceLock` is a single, shared lock directory that BOTH
# `dictate` and `speak` acquire before doing anything with audio hardware,
# and BOTH refuse to proceed if the other already holds it. This makes
# "STT running while TTS is producing audio" structurally impossible, not
# just unlikely -- there's no code path in either tool that touches the
# mic/speaker without holding the lock first.
#
# dictate: local speech-to-text that types the transcription into whatever
# app has focus. whisper.cpp (STT) + ydotool (uinput typing, works on
# GNOME/Wayland where wtype doesn't). Toggle: run once to start recording,
# run again to stop/transcribe/type. GNOME custom keybindings only fire on
# key-DOWN (no key-up event is exposed to a shortcut command), so a literal
# push-to-HOLD isn't achievable without a raw-input-watching daemon running
# with elevated privileges (architecturally a keylogger) -- out of scope.
# Instead: a hard `maxRecordSeconds` cap (recording runs as a systemd-run
# --user unit with RuntimeMaxSec, so "forgot to tap again" can't run the mic
# forever) + a minimum transcript length before auto-typing (so a burst of
# ambient noise mis-transcribed as a garbage word never gets typed).
#
# speak: local text-to-speech via piper (onnxruntime, CPU). A plain nixpkgs
# package -- no pipx/venv/PyTorch. Voice model is Nix-fetched + pinned.
# NPU note: nixpkgs' piper/onnxruntime ship CPUExecutionProvider only, so
# this runs on CPU; the Intel AI Boost NPU would need an onnxruntime built
# with the OpenVINO EP (or a direct-OpenVINO runner), neither in nixpkgs.
#
# Both DISABLED by default. Enabling either is a per-host opt-in
# (programs.ai.voice.enable / programs.ai.voice.tts.enable).
let
  cfg = config.programs.ai.voice;
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;

  # Shared lock dir both dictate and speak acquire/check. A directory (not
  # a plain file) so mkdir's atomicity gives us a race-free "acquire"
  # primitive for free (mkdir fails if it already exists), same trick
  # POSIX advisory-locking tools have used forever.
  lockDirExpr = ''"''${XDG_RUNTIME_DIR:-/tmp}/voice-lock"'';

  # Shared shell functions, sourced (via `.`) by both dictate and speak, so
  # the acquire/release/holder-check logic exists in exactly one place --
  # no risk of the two tools' lock logic drifting apart.
  voiceLockLib = pkgs.writeText "voice-lock.sh" ''
    VOICE_LOCK=${lockDirExpr}

    # Acquire the lock for $1 ("stt" or "tts"). $2 is an optional liveness
    # token: a `systemd --user` unit name whose active-state defines whether
    # the holder is still alive. This matters because dictate hands recording
    # off to a transient unit and then EXITS -- so its own PID ($$) dies
    # immediately and can't represent "recording in progress". When a unit
    # token is given we record it and the staleness check consults systemd;
    # otherwise we fall back to the holder PID (speak holds the lock for its
    # own lifetime, so $$ is correct there).
    # Returns 1 (caller should abort) if already held by a LIVE holder;
    # a stale lock (holder gone -- e.g. a crash) is reclaimed automatically
    # rather than wedging voice I/O forever.
    voice_lock_acquire() {
      local kind="$1" unit="''${2:-}"
      if [ -d "$VOICE_LOCK" ]; then
        local holder_pid holder_kind holder_unit alive=1
        holder_pid="$(cat "$VOICE_LOCK/pid" 2>/dev/null || echo "")"
        holder_kind="$(cat "$VOICE_LOCK/kind" 2>/dev/null || echo "unknown")"
        holder_unit="$(cat "$VOICE_LOCK/unit" 2>/dev/null || echo "")"
        if [ -n "$holder_unit" ]; then
          systemctl --user --quiet is-active "$holder_unit.service" 2>/dev/null || alive=0
        elif [ -n "$holder_pid" ] && kill -0 "$holder_pid" 2>/dev/null; then
          alive=1
        else
          alive=0
        fi
        if [ "$alive" = "1" ]; then
          echo "voice: $holder_kind is active -- refusing to start $kind to avoid a feedback loop" >&2
          return 1
        fi
        # Stale lock (holder gone) -- reclaim it.
        find "$VOICE_LOCK" -delete 2>/dev/null || true
      fi
      if ! mkdir "$VOICE_LOCK" 2>/dev/null; then
        # Lost a race to acquire; treat as held.
        echo "voice: lock acquisition race -- another voice tool just started, refusing to start $kind" >&2
        return 1
      fi
      echo "$$" > "$VOICE_LOCK/pid"
      echo "$kind" > "$VOICE_LOCK/kind"
      [ -n "$unit" ] && echo "$unit" > "$VOICE_LOCK/unit"
      return 0
    }

    voice_lock_release() {
      find "$VOICE_LOCK" -delete 2>/dev/null || true
    }
  '';

  # Piper TTS voice model (en_US amy medium) + its config, fetched from
  # rhasspy/piper-voices and pinned. Piper voices aren't packaged in
  # nixpkgs; this is the same fetchurl-pins-a-blob approach used elsewhere.
  # To change voice: swap the name + both hashes (a voice is always a
  # paired .onnx + .onnx.json).
  #
  # CRITICAL: piper 1.4.2 IGNORES --config and derives the config path as
  # "<model>.onnx.json" right beside the model -- so the two files MUST be
  # co-located in ONE directory with matching basenames. Two separate
  # fetchurl store paths don't satisfy that (confirmed live: piper emitted
  # a 32-byte stub, no audio, exit 0 -> silent failure). symlinkJoin-style
  # runCommand puts both under one dir so `--model <dir>/<name>.onnx`
  # finds its sibling config.
  piperVoiceName = "en_GB-southern_english_female-low";
  piperVoiceBase = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/southern_english_female/low";
  piperVoiceModelFile = pkgs.fetchurl {
    url = "${piperVoiceBase}/${piperVoiceName}.onnx";
    hash = "sha256-8vN67Rs6CTR29xnRN5ugwLGxz28e+ZKI4uv1ApcaB8M=";
  };
  piperVoiceConfigFile = pkgs.fetchurl {
    url = "${piperVoiceBase}/${piperVoiceName}.onnx.json";
    hash = "sha256-oa9DMQ+HVhYVBuhJooY9NCqYsIU6+eJDdYHTnpki0OU=";
  };
  # Co-located voice dir: <dir>/en_US-amy-medium.onnx + .onnx.json
  piperVoiceDir = pkgs.runCommand "piper-voice-${piperVoiceName}" { } ''
    mkdir -p "$out"
    ln -s ${piperVoiceModelFile}  "$out/${piperVoiceName}.onnx"
    ln -s ${piperVoiceConfigFile} "$out/${piperVoiceName}.onnx.json"
  '';
  piperVoiceModel = "${piperVoiceDir}/${piperVoiceName}.onnx";
  piperVoiceConfig = "${piperVoiceDir}/${piperVoiceName}.onnx.json";

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
      pkgs.systemd # systemd-run/systemctl --user: run pw-record as a unit that
      # survives the transient gsd-media-keys scope that launches dictate
    ];
    text = ''
      set -euo pipefail
      # shellcheck source=/dev/null
      . ${voiceLockLib}
      # ydotoold runs as a SYSTEM service (programs.ydotool.enable in
      # nixos/_mixins/desktop/ydotool.nix) with its socket here. Set it
      # explicitly: the transient gsd-media-keys scope that launches dictate
      # doesn't reliably inherit the session-wide YDOTOOL_SOCKET env var, and
      # ydotool would otherwise fall back to the wrong ~/.ydotool_socket path
      # and fail with "check if ydotoold is running".
      export YDOTOOL_SOCKET="''${YDOTOOL_SOCKET:-/run/ydotoold/socket}"
      MODEL_NAME="${cfg.model}"
      LANG_CODE="${cfg.language}"
      MAX_SECONDS="${toString cfg.maxRecordSeconds}"
      MIN_CHARS="${toString cfg.minTranscriptChars}"
      DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/whisper"
      RUN="''${XDG_RUNTIME_DIR:-/tmp}/dictate"
      WAV="$RUN/rec.wav"
      PIDF="$RUN/rec.pid"
      mkdir -p "$DATA" "$RUN"

      notify() { notify-send -t 2000 -a dictate "$1" "''${2:-}" 2>/dev/null || true; }

      # pw-record runs as this transient --user unit (NOT a raw backgrounded
      # PID): gsd-media-keys launches `dictate` inside a transient systemd
      # SCOPE, and when dictate's short-lived main process exits, systemd
      # reaps that scope's whole cgroup -- which would instantly kill a
      # plain `pw-record &` child (confirmed live: recorder + pidfile
      # vanished within 2s). A `systemd-run --user` service is owned by the
      # user manager, not the launching scope, so it outlives dictate
      # returning. "Recording in progress?" == "is this unit active?".
      REC_UNIT="dictate-rec"

      # --- Toggle: if a recording is in progress, stop + transcribe ---------
      if systemctl --user --quiet is-active "$REC_UNIT.service" 2>/dev/null; then
        systemctl --user stop "$REC_UNIT.service" 2>/dev/null || true
        rm -f "$PIDF"
        voice_lock_release
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
        # Refuse to auto-type suspiciously short output: a stray cough,
        # ambient noise, or a mic pop often transcribes as one short/garbage
        # "word" -- typing that unattended is exactly the kind of runaway
        # behavior that got voice.enable turned off in the first place.
        # Below the floor, surface it via notification only (never typed).
        if [ -z "$TEXT" ] || [ "''${#TEXT}" -lt "$MIN_CHARS" ]; then
          notify "dictate: too short, not typed" "$TEXT"
          exit 0
        fi
        # Copy to clipboard as a fallback, then type it at the cursor.
        printf '%s' "$TEXT" | wl-copy 2>/dev/null || true
        if ! ydotool type -- "$TEXT" 2>/dev/null; then
          notify "dictate: typed to clipboard (paste with Ctrl+V)" "$TEXT"
        fi
        exit 0
      fi

      # --- Otherwise: start recording ----------------------------------------
      # Refuse to start if `speak` currently holds the lock (i.e. TTS audio
      # may be playing) -- see the SAFETY comment at the top of this file.
      # Pass REC_UNIT as the liveness token: recording lives in that unit
      # after dictate exits, so the lock's staleness check must track the
      # unit's active-state, not dictate's (already-dead) PID -- otherwise
      # `speak` could wrongly reclaim the lock mid-recording.
      if ! voice_lock_acquire stt "$REC_UNIT"; then
        notify "dictate: blocked" "text-to-speech is active"
        exit 1
      fi
      rm -f "$WAV"
      notify "Listening…" "run dictate again to stop (auto-stops after ''${MAX_SECONDS}s)"
      # Clear any lingering/half-collected unit of the same name before
      # starting -- rapid double-presses (gsd-media-keys fired several
      # invocations within the same second, confirmed live) otherwise race
      # on the fixed unit name and fail with "Unit dictate-rec.service was
      # already loaded or has a fragment file". stop + reset-failed makes
      # start idempotent; the voice_lock above already serializes the
      # start-vs-stop decision, this just cleans systemd's own residue.
      systemctl --user stop "$REC_UNIT.service" 2>/dev/null || true
      systemctl --user reset-failed "$REC_UNIT.service" 2>/dev/null || true
      # Run pw-record as a transient --user service so it survives the
      # gsd-media-keys scope that launched us (see REC_UNIT comment above).
      # RuntimeMaxSec is the hard cap: systemd stops the unit after
      # MAX_SECONDS even if the toggle is never pressed again (replaces the
      # old `timeout` wrapper + watcher subshell, both of which died with
      # the scope anyway). --collect so the unit auto-clears when it stops,
      # leaving is-active correctly false for the next invocation.
      if ! systemd-run --user --quiet --collect \
          --unit="$REC_UNIT" \
          --property=RuntimeMaxSec="$MAX_SECONDS" \
          pw-record --rate 16000 --channels 1 --format s16 "$WAV"; then
        notify "dictate: could not start recording"
        voice_lock_release
        exit 1
      fi
      echo "$REC_UNIT" > "$PIDF"
    '';
  };

  speak = pkgs.writeShellApplication {
    name = "speak";
    runtimeInputs = [ pkgs.piper-tts pkgs.pipewire pkgs.libnotify pkgs.coreutils ];
    text = ''
      # shellcheck source=/dev/null
      . ${voiceLockLib}
      RUN="''${XDG_RUNTIME_DIR:-/tmp}/speak"
      mkdir -p "$RUN"

      notify() { notify-send -t 2000 -a speak "$1" "''${2:-}" 2>/dev/null || true; }

      if [ $# -eq 0 ]; then
        echo "usage: speak <text>" >&2
        exit 2
      fi
      TEXT="$*"

      # Refuse to speak if `dictate` currently holds the lock (i.e. the mic
      # may be recording) -- see the SAFETY comment at the top of this file.
      if ! voice_lock_acquire tts; then
        notify "speak: blocked" "dictation is active"
        exit 1
      fi
      trap voice_lock_release EXIT

      # piper (onnxruntime, CPU) -- tiny + sub-second, no PyTorch. The voice
      # model .onnx + its .onnx.json config are Nix-fetched (see
      # piperVoiceModel below), pinned + reproducible. Piper streams raw
      # 16-bit PCM to stdout; feed it straight to pw-play with the model's
      # sample rate. NPU note: nixpkgs' piper/onnxruntime have no OpenVINO
      # execution provider (CPUExecutionProvider only -- verified), so this
      # runs on CPU; targeting the Intel NPU would need an onnxruntime built
      # with the OpenVINO EP or a direct-OpenVINO runner, neither of which
      # exists in nixpkgs today.
      RATE=$(${pkgs.jq}/bin/jq -r '.audio.sample_rate // 22050' "${piperVoiceConfig}" 2>/dev/null || echo 22050)
      if ! printf '%s' "$TEXT" | piper \
            --model "${piperVoiceModel}" \
            --config "${piperVoiceConfig}" \
            --output-raw 2>/dev/null \
          | pw-play --rate "$RATE" --channels 1 --format s16 --raw -; then
        notify "speak: generation failed"
        exit 1
      fi
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
    maxRecordSeconds = mkOption {
      type = types.int;
      default = 60;
      description = ''
        Hard cap on a single recording. GNOME custom keybindings only fire
        on key-down (no key-up event is exposed to a shortcut command), so
        a true push-to-hold isn't achievable here -- this bounds the worst
        case of "tapped once, forgot to tap again" instead.
      '';
    };
    minTranscriptChars = mkOption {
      type = types.int;
      default = 4;
      description = ''
        Minimum transcript length (characters) before it's auto-typed.
        Shorter transcripts are surfaced via notification only, never
        typed -- guards against a short burst of ambient noise/mic pop
        being mis-transcribed as a word or two and typed unattended.
      '';
    };

    tts = {
      enable = mkEnableOption "local text-to-speech (piper, CPU/onnxruntime)";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
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
    })

    (mkIf cfg.tts.enable {
      # piper is a plain nixpkgs package (pulled in via speak's runtimeInputs)
      # -- no pipx/venv/PyTorch dance like pocket-tts needed. The voice model
      # is Nix-fetched (piperVoiceModel/Config above).
      home.packages = [ speak ];
    })
  ];
}
