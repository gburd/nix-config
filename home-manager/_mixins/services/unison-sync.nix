# Unison bidirectional sync for a set of project directories across a chosen
# subset of hosts, plus the agent session state that is rooted in each one.
#
# WHAT IT SYNCS, per declared directory (e.g. ~/ws/pure-lang between arnold
# and floki):
#   1. the project tree itself;
#   2. pi's session state for that tree, at
#      ~/.pi/agent/sessions/--<slug>--/  (pi keys sessions by the ABSOLUTE
#      path, slugged '/'->'-' with leading+trailing '--'; the path is the
#      same on both hosts, so the slug matches);
#   3. claude's session state, at ~/.claude/projects/-<slug>  (same idea,
#      single leading '-', no trailing).
#
# WHAT IT DELIBERATELY DOES NOT SYNC, and why:
#   * <project>/.memelord/ -- memelord's SQLite (libSQL) DB. No file-sync tool
#     can merge a database both hosts write live; unison would see two changed
#     binary blobs and flag an unresolvable conflict, and libSQL's WAL
#     (memory.db-tshm) corrupts under anything that isn't memelord itself (see
#     nix-config 4c5ae6f). Ignored outright. Each host keeps its own project
#     memory. If you ever want shared memory, run ONE memelord as a network
#     service both hosts talk to -- a deployment change, not a sync change.
#   * maki -- its project memories live under ~/.maki/projects/<name>-<hash>/
#     where <hash> is maki's own opaque id (NOT a slug of the path), and its
#     sessions are flat ~/.maki/sessions/<uuid>.jsonl with the cwd recorded
#     INSIDE the file. Neither can be mapped to a directory by its path, so
#     "all state rooted in this folder" is not expressible for maki.
#   * zed -- a single global LMDB (threads-db.1.mdb, db/) holding every
#     project together; it cannot be split per-folder, and syncing a live LMDB
#     would corrupt it.
#   * codex -- ~/.codex/sessions/<date>/<uuid>.jsonl, a date tree with cwd
#     inside; not groupable by path either.
# The agents above still work on each host; only pi and claude session state
# follows the directory across hosts.
#
# CONCURRENT-EDIT WARNING (applies to session state too): if the SAME project
# is edited on two hosts at once -- the tree, or a pi/claude session for it --
# unison records a conflict and syncs neither side of that file until you
# resolve it (prefer=newer handles the common "I moved to the other laptop"
# case; a true simultaneous edit still conflicts). This is sync, not a
# distributed database.
#
# TRANSPORT: unison over ssh, driven by `unison -repeat watch` (needs
# unison-fsmonitor, shipped in the nixpkgs unison). One systemd USER service
# per (directory, peer) pair, named unison-<dir>-<peer>.

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ai.sync;

  # pi/claude slug of an absolute path: '/home/gburd/ws/pure-lang'.
  # pi:     --home-gburd-ws-pure-lang--
  # claude: -home-gburd-ws-pure-lang
  slugDashes = p: lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" p);
  piSlug = p: "--" + slugDashes ("/" + lib.removePrefix "/" p) + "--";
  claudeSlug = p: "-" + slugDashes p;

  # Expand a declared path (may use ~) to an absolute path.
  abs = p:
    if lib.hasPrefix "/" p then p
    else "${config.home.homeDirectory}/${lib.removePrefix "~/" (lib.removePrefix "./" p)}";

  # unison ignore patterns common to every root (build cruft + the DBs/state
  # we must not sync). `Name` matches a path component anywhere.
  baseIgnores = [
    "Name .git" # git handles its own history; syncing .git races the index
    "Name .memelord" # live SQLite DB -- see header
    "Name .direnv"
    "Name target" # rust/C build output
    "Name node_modules"
    "Name .DS_Store"
    "Name *.o"
    "Name *.lock"
    "Path .unison*"
  ];

  # The host this config is being built for. We can't read `hostname` at
  # eval, so each host sets programs.ai.sync.host explicitly (its short name).
  inherit (cfg) host;

  # For a directory entry, the peers that are NOT this host.
  peersOf = entry: lib.filter (h: h != host) entry.hosts;

  # Does this host participate in this entry?
  participates = entry: lib.elem host entry.hosts;

  mkPairService = entry: peer:
    let
      a = abs entry.path;
      ignores = baseIgnores ++ (map (i: "Name ${i}") entry.ignores);
      ignoreArgs = lib.concatMapStringsSep " " (p: "-ignore ${lib.escapeShellArg p}") ignores;
      # The three roots that travel together for this directory.
      roots = [
        a
        "${config.home.homeDirectory}/.pi/agent/sessions/${piSlug a}"
        "${config.home.homeDirectory}/.claude/projects/${claudeSlug a}"
      ];
      sshUser = entry.sshUser or "gburd";
      # unison profile-less invocation: two roots at a time. We sync each of
      # the three roots to the peer in its own unison call so an absent
      # session dir on one side doesn't block the project tree.
      # One unison invocation, backgrounded, resilient to its own failure.
      # `-repeat watch` is long-lived; the trailing `|| true &` MUST sit on
      # the same logical line as the command (hence it closes the final
      # backslash-continued line), or bash sees the command end at the newline.
      unisonFor = localRoot: remoteRoot: ''
        ${pkgs.unison}/bin/unison \
          ${lib.escapeShellArg localRoot} \
          "ssh://${sshUser}@${peer}.ts.burd.me/${remoteRoot}" \
          -batch -prefer newer -times -perms 0 \
          -sshargs ${lib.escapeShellArg "-o IdentitiesOnly=yes -i ${config.home.homeDirectory}/.ssh/id_ed25519"} \
          -servercmd ${lib.escapeShellArg "${pkgs.unison}/bin/unison"} \
          ${ignoreArgs} \
          -repeat watch -ui text || true &'';
      # The remote absolute paths equal the local ones (same $HOME layout).
      # Each of the three roots syncs in its own backgrounded watcher so an
      # absent session dir on one side doesn't block the project tree.
      syncScript = pkgs.writeShellScript "unison-${entry.name}-${peer}" ''
        set -u
        # Project tree (always present on at least one side).
        ${unisonFor (builtins.elemAt roots 0) (builtins.elemAt roots 0)}
        # pi session state for this tree, if the dirs exist on either side.
        ${unisonFor (builtins.elemAt roots 1) (builtins.elemAt roots 1)}
        # claude session state for this tree.
        ${unisonFor (builtins.elemAt roots 2) (builtins.elemAt roots 2)}
        wait
      '';
    in
    lib.nameValuePair "unison-${entry.name}-${peer}" {
      Unit = {
        Description = "Unison live sync of ${entry.path} (+ pi/claude session state) to ${peer}";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${syncScript}";
        Restart = "always";
        RestartSec = 30;
        # unison -repeat watch is long-lived; fsmonitor must be on PATH.
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.unison pkgs.openssh ]}" ];
      };
      Install.WantedBy = [ "default.target" ];
    };

  # All (entry, peer) services where this host participates.
  services = lib.listToAttrs (lib.flatten (map
    (entry: map (peer: mkPairService entry peer) (peersOf entry))
    (lib.filter participates cfg.directories)));
in
{
  options.programs.ai.sync = {
    enable = lib.mkEnableOption "unison sync of project dirs + agent session state";
    host = lib.mkOption {
      type = lib.types.str;
      description = "This host's short name, as used in <name>.ts.burd.me.";
    };
    directories = lib.mkOption {
      default = [ ];
      description = ''
        Directories to keep in sync, each across its own set of hosts. For
        each one, the project tree plus the pi and claude session state rooted
        in it travel together. See the module header for what is and is not
        synced.
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Short id for the systemd unit (e.g. \"pure-lang\").";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "Absolute (or ~/-relative) directory to sync.";
          };
          hosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Short names of the hosts that share this directory.";
          };
          ignores = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra unison `Name` ignore patterns for this dir.";
          };
          sshUser = lib.mkOption {
            type = lib.types.str;
            default = "gburd";
            description = "SSH user on the peer.";
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unison ];
    systemd.user.services = services;
  };
}
