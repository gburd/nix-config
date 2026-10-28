{ writeShellScriptBin
, symlinkJoin
, python3
, nodejs
, coreutils
, psmisc
, stdenvNoCC
, cacert
}:

# memelord MCP server (persistent memory for coding agents) from npm
# (https://github.com/glommer/memelord), plus a local `memelord-rollup` tool
# that distills memelord's flat per-project memory pile into high-signal
# pattern summaries (see rollup.py). Both land on PATH.
let
  # Pinned. 0.1.5 is the version every host has been running.
  version = "0.1.5";

  # memelord + its 4 runtime deps, installed ONCE into the Nix store (a
  # fixed-output derivation that runs `npm install` with network access,
  # pinned by outputHash). This replaces the old runtime `npx -y memelord`,
  # which hit the npm registry and raced on the shared ~/.npm/_npx cache on
  # every agent launch -- under many concurrent agents across ~/ws projects
  # that caused intermittent "Failed to connect to memelord" errors. Now the
  # wrapper runs `node <store>/dist/cli.mjs` directly: no network, no npx, no
  # shared-cache race. Bump `version` + re-run to refresh outputHash.
  memelordNodeModules = stdenvNoCC.mkDerivation {
    pname = "memelord-node-modules";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = [ nodejs cacert ];
    buildPhase = ''
      export HOME=$TMPDIR
      mkdir -p $TMPDIR/app && cd $TMPDIR/app
      npm install --no-audit --no-fund --prefix $TMPDIR/app memelord@${version}
    '';
    installPhase = ''
      mkdir -p $out
      cp -R $TMPDIR/app/node_modules $out/node_modules
    '';
    # Fixed-output: allows network for the npm install. The hash pins the
    # resolved dependency closure; if npm resolves different transitive deps
    # (a ^range float) the build fails and the hash must be refreshed.
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-wfhMeFNhWkWBL7Khj1wAyfcQ6ddG7/tro31rbdJzZyU=";
  };

  memelord = writeShellScriptBin "memelord" ''
    # Self-heal before serving. memelord stores memory in Turso (libSQL), whose
    # multiprocess WAL is indexed by a `-tshm` file. Any tool that opens the
    # DB with STOCK sqlite (the `sqlite3` CLI, Python's sqlite3, the old
    # rollup) does not know that format. It can checkpoint and truncate
    # memory.db-wal to 0 bytes while -tshm still points at frames inside it.
    # Every later open then dies with
    #   failed to open database .../memory.db: I/O error:
    #   short read on WAL frame at offset N: expected 4096 bytes, got 0
    #   { code: 'GenericFailure' }
    # and agents see only "MCP: Failed to connect to memelord: Connection
    # closed (code: 'GenericFailure' ...)". On 2026-10-16, 19 project DBs were
    # in that state.
    #
    # A clean Turso shutdown never leaves a 0-byte WAL (measured: a fresh DB
    # after one write and a clean exit has a ~57 KB WAL). So "WAL is empty but
    # -tshm exists" is always the broken state. memory.db itself is intact in
    # that state (integrity_check ok). Recovery is to move the stale WAL index
    # aside so Turso rebuilds it. Only done when NO process has the DB open,
    # so a live server is never touched. Moved, not deleted, for forensics.
    d="''${MEMELORD_DIR:-.memelord}"
    if [ "''${1:-serve}" = serve ] && [ -f "$d/memory.db" ] && [ -f "$d/memory.db-tshm" ] \
       && [ -f "$d/memory.db-wal" ] && [ ! -s "$d/memory.db-wal" ] \
       && ! ${psmisc}/bin/fuser -s "$d/memory.db" "$d/memory.db-wal" "$d/memory.db-tshm" 2>/dev/null; then
      ts=$(${coreutils}/bin/date +%Y%m%d-%H%M%S)
      for f in memory.db-wal memory.db-tshm memory.db-shm; do
        [ -e "$d/$f" ] && ${coreutils}/bin/mv -f "$d/$f" "$d/$f.stale-$ts"
      done
      echo "[memelord] repaired $d: empty WAL with a stale -tshm (moved aside as *.stale-$ts)" >&2
    fi
    # @huggingface/transformers (0.1.5's embedding dep) writes a FileCache to a
    # `.cache` dir INSIDE its own package and ignores HF_HOME/TRANSFORMERS_CACHE
    # for that path. That worked under the old `npx` (package lived in writable
    # ~/.npm) but fails from the read-only Nix store (ENOENT mkdir). So stage a
    # WRITABLE copy of the pinned store node_modules once, under the user cache,
    # and run node from there. The store derivation stays the single pinned
    # source (no npx, no network, no shared-cache race); the per-user copy just
    # gives transformers.js somewhere to write. Refreshed when the store path
    # (version) changes, detected via a stamp file.
    stage="''${XDG_CACHE_HOME:-$HOME/.cache}/memelord-nm"
    src=${memelordNodeModules}
    if [ "$(${coreutils}/bin/cat "$stage/.srcpath" 2>/dev/null)" != "$src" ]; then
      ${coreutils}/bin/rm -rf "$stage" 2>/dev/null || true
      ${coreutils}/bin/mkdir -p "$stage"
      ${coreutils}/bin/cp -R "$src/node_modules" "$stage/node_modules"
      ${coreutils}/bin/chmod -R u+w "$stage/node_modules"
      ${coreutils}/bin/echo "$src" > "$stage/.srcpath"
    fi
    exec ${nodejs}/bin/node "$stage/node_modules/memelord/dist/cli.mjs" "$@"
  '';

  # memelord-rollup: stdlib-only Python (sqlite3 + urllib), no extra deps.
  # Reads .memelord/memory.db (L0), writes distilled cluster summaries to a
  # separate rollup_summaries table (L1) -- never touches memelord's own
  # tables, so a memelord upgrade can't break on it.
  memelord-rollup = writeShellScriptBin "memelord-rollup" ''
    exec ${python3}/bin/python3 ${./rollup.py} "$@"
  '';
in
symlinkJoin {
  name = "memelord-with-rollup";
  paths = [ memelord memelord-rollup ];
}
