{ writeShellScriptBin
, symlinkJoin
, python3
, nodejs
}:

# memelord MCP server (persistent memory for coding agents) from npm
# (https://github.com/glommer/memelord), plus a local `memelord-rollup` tool
# that distills memelord's flat per-project memory pile into high-signal
# pattern summaries (see rollup.py). Both land on PATH.
let
  memelord = writeShellScriptBin "memelord" ''
    exec ${nodejs}/bin/npx -y memelord "$@"
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
