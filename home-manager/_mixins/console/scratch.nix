{ config, lib, pkgs, ... }:
let
  user = config.home.username;
in
{
  # Per-shell-session TMPDIR under /scratch
  # ---------------------------------------
  # Point TMPDIR / TMP / TEMP at a fresh `mktemp -d` directory under
  # /scratch/<user>/ at every interactive shell start. nix-shell, build
  # tools, tests, and benchmarks land on real disk instead of /tmp (which
  # may be tmpfs / RAM-backed on some systems, and gives misleading IO
  # numbers for database/storage code regardless).
  #
  # Lifecycle:
  #   - shell starts:  mktemp /scratch/$USER/tmp-YYYYMMDD-XXXXXX, export.
  #   - shell exits:   rmdir if empty (best-effort; never recursive — we
  #                    deliberately keep crash artefacts for triage).
  # See `scripts/scratch-prune.sh` for periodic cleanup of old/empty
  # session dirs.
  #
  # Activation script ensures /scratch/<user> exists and is user-owned; if
  # /scratch itself is missing or unwritable, log a clear warning telling
  # the user how to fix it (NixOS hosts get it via
  # nixos/_mixins/services/scratch.nix; on Fedora-style hosts: sudo install
  # -d -m 1777 /scratch).

  home.activation.ensureScratchDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d /scratch ] && [ -w /scratch ]; then
        ${pkgs.coreutils}/bin/mkdir -p /scratch/${user}
        ${pkgs.coreutils}/bin/chmod 700 /scratch/${user}
      else
        echo "scratch: /scratch missing or not writable for ${user}." >&2
        echo "scratch: on NixOS this is created by nixos/_mixins/services/scratch.nix." >&2
        echo "scratch: on Fedora etc., run once: sudo install -d -m 1777 /scratch" >&2
      fi
    '';

  programs.bash.initExtra = ''
    # /scratch-backed TMPDIR (see home-manager/_mixins/console/scratch.nix).
    # Only for interactive shells; non-interactive systemd-user/cron jobs
    # keep the default /tmp so our session cleanup trap can't strand them.
    if [ -n "$PS1" ] && [ -d "/scratch/$USER" ] && [ -w "/scratch/$USER" ]; then
      _SCRATCH_TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d "/scratch/$USER/tmp-$(date +%Y%m%d)-XXXXXX" 2>/dev/null) || _SCRATCH_TMPDIR=""
      if [ -n "$_SCRATCH_TMPDIR" ]; then
        export TMPDIR="$_SCRATCH_TMPDIR"
        export TMP="$_SCRATCH_TMPDIR"
        export TEMP="$_SCRATCH_TMPDIR"
        # Best-effort: rmdir only succeeds when empty. Anything left behind
        # (crash dumps, partial builds someone wanted to inspect) survives.
        trap '${pkgs.coreutils}/bin/rmdir "$_SCRATCH_TMPDIR" 2>/dev/null' EXIT
      fi
    fi
  '';

  programs.fish.interactiveShellInit = ''
    # /scratch-backed TMPDIR (see home-manager/_mixins/console/scratch.nix).
    if test -d /scratch/$USER -a -w /scratch/$USER
      set -l _scratch_tmpdir (${pkgs.coreutils}/bin/mktemp -d /scratch/$USER/tmp-(date +%Y%m%d)-XXXXXX 2>/dev/null)
      if test -n "$_scratch_tmpdir"
        set -gx TMPDIR $_scratch_tmpdir
        set -gx TMP $_scratch_tmpdir
        set -gx TEMP $_scratch_tmpdir
        function _scratch_cleanup_on_exit --on-event fish_exit
          ${pkgs.coreutils}/bin/rmdir $TMPDIR 2>/dev/null
        end
      end
    end
  '';
}
