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
#   4. the repo's .git/config and .git/info/exclude ONLY (not the rest of
#      .git). This keeps remotes, branch tracking, core settings and the
#      local-only ignore list identical across hosts, while each host keeps
#      its OWN objects/refs/HEAD/index (synced via git push/pull, not here).
#      FIRST TIME a synced repo lands on a host, `git clone` it once so the
#      object store/refs exist and git commands work; thereafter the two .git
#      dirs are independent except for config + info/exclude. Do NOT add a
#      repo that uses `git worktree` on some host -- that writes an absolute
#      [core] worktree path into .git/config, which would then fight.
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
  # we must not sync). `Name` matches a path component anywhere; `Path` is the
  # full path from the replica root.
  #
  # .git is NOT ignored wholesale. git's history is per-host (each host has its
  # own objects/refs/HEAD/index and keeps them in step via git push/pull), so
  # syncing those would corrupt the index or fight the per-host checkout. But a
  # repo's IDENTITY -- its remotes, branch tracking, core settings, and the
  # local-only .git/info/exclude ignore list -- should match across hosts and
  # is static enough to sync safely. So we sync exactly .git/config and
  # .git/info/exclude and ignore every other .git child. (Proven: with these
  # per-path ignores unison copies only those two and leaves HEAD/index/
  # objects/refs untouched.) NB the first time a repo lands on a host you still
  # `git clone` it once to populate objects/refs so git commands work; after
  # that the two .git dirs are independent except for config + info/exclude.
  # A host that runs `git worktree add` writes an absolute [core] worktree path
  # into .git/config -- don't sync such repos, or that path will fight.
  gitChildIgnores = [
    "Path */.git/HEAD"
    "Path */.git/index"
    "Path */.git/objects"
    "Path */.git/refs"
    "Path */.git/logs"
    "Path */.git/packed-refs"
    "Path */.git/ORIG_HEAD"
    "Path */.git/FETCH_HEAD"
    "Path */.git/MERGE_HEAD"
    "Path */.git/COMMIT_EDITMSG"
    "Path */.git/hooks"
    "Path */.git/worktrees"
    "Path */.git/branches"
    "Path */.git/modules"
    "Path */.git/lfs"
    # .git/*.lock transient locks, matched narrowly by Path (NOT a blanket
    # Name *.lock, which would swallow flake.lock / Cargo.lock).
    "Path */.git/config.lock"
    "Path */.git/index.lock"
    "Path */.git/HEAD.lock"
    "Path .git/config.lock"
    "Path .git/index.lock"
    "Path .git/HEAD.lock"
    # The repo's own .git (root of the synced dir) uses unprefixed paths too.
    "Path .git/HEAD" "Path .git/index" "Path .git/objects" "Path .git/refs"
    "Path .git/logs" "Path .git/packed-refs" "Path .git/ORIG_HEAD"
    "Path .git/FETCH_HEAD" "Path .git/MERGE_HEAD" "Path .git/COMMIT_EDITMSG"
    "Path .git/hooks" "Path .git/worktrees" "Path .git/branches"
    "Path .git/modules" "Path .git/lfs"
  ];
  baseIgnores = [
    "Name .memelord" # live SQLite DB -- see header
    "Name .direnv"
    "Name target" # rust/C build output
    "Name node_modules"
    "Name .DS_Store"
    "Name *.o"
    # NB do NOT ignore *.lock by Name as a blanket -- that swallowed flake.lock,
    # which must stay in sync (it pins dependencies). The .git/*.lock case is
    # handled narrowly above. unison's own lock is covered by .unison* below.
    "Path .unison*"
  ] ++ gitChildIgnores;

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
      # The roots that travel together for this directory. With
      # sessionRoots = true (default) that is the project tree PLUS its pi and
      # claude session state (single-project entries). With false it is JUST
      # the tree -- used for PARENT trees like ~/ws and ~/src whose own path
      # has no meaningful session dir; per-project session state under them is
      # handled by the separate sessionTrees mechanism (mkSessionService).
      roots = [ a ]
        ++ lib.optionals entry.sessionRoots [
          "${config.home.homeDirectory}/.pi/agent/sessions/${piSlug a}"
          "${config.home.homeDirectory}/.claude/projects/${claudeSlug a}"
        ];
      sshUser = entry.sshUser or "gburd";
      sshArgs = "-o IdentitiesOnly=yes -i ${config.home.homeDirectory}/.ssh/id_ed25519";
      # Common unison flags. Paths are identical on both sides (same $HOME),
      # so local root == remote root for each of the three.
      commonArgs = root: ''\
          ${lib.escapeShellArg root} \
          "ssh://${sshUser}@${peer}.ts.burd.me/${root}" \
          -batch -prefer newer -times -perms 0 -auto \
          -sshargs ${lib.escapeShellArg sshArgs} \
          -servercmd ${lib.escapeShellArg "${pkgs.unison}/bin/unison"} \
          ${ignoreArgs}'';
      # A one-time NON-watch sync, to SEED a root. unison -repeat watch dies
      # immediately if a local root is missing ('Filesystem watcher error:
      # Path ... does not exist'); a plain run instead creates the absent side
      # from the present one. Run until it succeeds once, so it also waits out
      # a peer that is mid-switch.
      seedOne = root: ''
        until ${pkgs.unison}/bin/unison ${commonArgs root}; do
          echo "seed ${root} -> ${peer} failed; retrying in 30s" >&2
          sleep 30
        done'';
      # The long-lived watcher for one root, backgrounded and self-restarting.
      # The trailing `&` MUST close the final continued line.
      watchOne = root: ''
        ( while :; do
            ${pkgs.unison}/bin/unison ${commonArgs root} -repeat watch -ui text
            echo "watch ${root} -> ${peer} exited ($?); restarting in 30s" >&2
            sleep 30
          done ) &'';
      syncScript = pkgs.writeShellScript "unison-${entry.name}-${peer}" ''
        set -u
        # Ensure the local parents exist so a first sync has somewhere to land.
        ${lib.concatMapStringsSep "\n        "
          (r: "mkdir -p ${lib.escapeShellArg (builtins.dirOf r)}") roots}
        # SEED each root once (no watcher), so both sides exist before watching.
        # These run in series; each waits out a peer that is mid-switch.
        ${lib.concatMapStringsSep "\n        " seedOne roots}
        # Now the live watchers (each self-restarting), held by `wait`.
        ${lib.concatMapStringsSep "\n        " watchOne roots}
        wait
      '';
    in
    lib.nameValuePair "unison-${entry.name}-${peer}" {
      Unit = {
        Description = "Unison live sync of ${entry.path}"
          + lib.optionalString entry.sessionRoots " (+ pi/claude session state)"
          + " to ${peer}";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${syncScript}";
        Restart = "always";
        RestartSec = 30;
        # unison -repeat watch is long-lived; fsmonitor must be on PATH.
        # unison -repeat watch is long-lived; fsmonitor must be on PATH, and
        # the seed/watch retry loops use sleep/echo (coreutils).
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.unison pkgs.openssh pkgs.coreutils ]}" ];
      };
      Install.WantedBy = [ "default.target" ];
    };

  # All (entry, peer) services where this host participates.
  services = lib.listToAttrs (lib.flatten (map
    (entry: map (peer: mkPairService entry peer) (peersOf entry))
    (lib.filter participates cfg.directories)));

  # ---- Per-project session sync (pi/claude) under a PARENT tree -----------
  # The ~/ws and ~/src trees are synced as single roots (sessionRoots = false),
  # so their per-project pi/claude session state is NOT carried by those
  # entries. This service fills that gap: at runtime it enumerates the
  # immediate sub-projects under each configured sessionTrees parent (on BOTH
  # sides), and for each sub-project that already HAS a pi or claude session
  # dir on either side, syncs those small roots. Enumeration is at START time
  # + a slow re-poll, so projects can come and go without a rebuild.
  #
  # maki/codex/zed session state is NOT handled: maki keys projects by
  # name+opaque-hash (not a path slug; confirmed not md5/sha1/sha256 of the
  # path), codex/zed store cwd inside flat files / a global LMDB. Only pi and
  # claude key sessions by the absolute path, so only they are mappable.
  #
  # SAFETY: this service NEVER pre-creates (mkdir) a session root. It only
  # runs unison for a root that exists on >=1 side, letting unison CREATE the
  # absent side from the present one (never delete the present side). This is
  # what keeps the empty-replica deletion hazard (which gutted ~/src in an
  # earlier incident) from recurring. No -nodeletion (reverted upstream).
  sessionHost = host;
  sessionPeersOf = tree: lib.filter (h: h != sessionHost) tree.hosts;
  sessionParticipates = tree: lib.elem sessionHost tree.hosts;
  # For a peer, the trees that include BOTH this host and that peer.
  treesForPeer = peer:
    lib.filter (t: sessionParticipates t && lib.elem peer t.hosts) cfg.sessionTrees;
  allSessionPeers =
    lib.unique (lib.concatMap sessionPeersOf (lib.filter sessionParticipates cfg.sessionTrees));

  mkSessionService = peer:
    let
      trees = treesForPeer peer;
      sshUser = (builtins.head trees).sshUser or "gburd";
      sshArgs = "-o IdentitiesOnly=yes -i ${config.home.homeDirectory}/.ssh/id_ed25519";
      # "<absParent>|<space-joined-excludes>" per tree.
      treeSpecs = map (t: "${abs t.path}|${lib.concatStringsSep " " t.exclude}") trees;
      script = pkgs.writeShellScript "unison-sessions-${peer}" ''
        set -u
        PEER=${lib.escapeShellArg peer}
        SSHUSER=${lib.escapeShellArg sshUser}
        SSHARGS=${lib.escapeShellArg sshArgs}
        UNISON=${pkgs.unison}/bin/unison
        REMOTE="$SSHUSER@$PEER.ts.burd.me"

        # Sync one session root if it exists on EITHER side. Never mkdir it:
        # unison creates the absent side from the present one (no deletion of
        # the present side). $1 = absolute root (identical path both hosts).
        sync_root() {
          root="$1"
          here=0; [ -d "$root" ] && here=1
          there=0
          if ssh $SSHARGS "$REMOTE" "test -d '$root'" 2>/dev/null; then there=1; fi
          [ "$here" = 0 ] && [ "$there" = 0 ] && return 0
          "$UNISON" "$root" "ssh://$REMOTE/$root" \
            -batch -prefer newer -times -perms 0 -auto \
            -sshargs "$SSHARGS" -servercmd "$UNISON" \
            -ignore 'Path .unison*' \
            || echo "session sync $root -> $PEER failed" >&2
        }

        enumerate_once() {
          for spec in ${lib.concatMapStringsSep " " lib.escapeShellArg treeSpecs}; do
            parent="''${spec%%|*}"
            excl=" ''${spec#*|} "
            names=$( { ls -1 "$parent" 2>/dev/null; \
                       ssh $SSHARGS "$REMOTE" "ls -1 '$parent' 2>/dev/null"; } \
                     | sort -u )
            for n in $names; do
              case "$excl" in *" $n "*) continue ;; esac
              p="$parent/$n"
              # pi slug: only '/' -> '-', leading+trailing '--'.
              pislug="--$(printf '%s' "''${p#/}" | tr '/' '-')--"
              # claude slug: EVERY non-alnum -> '-' (claude's real rule;
              # '.' and '_' included), single leading '-'.
              claudeslug="-$(printf '%s' "''${p#/}" | sed 's/[^A-Za-z0-9]/-/g')"
              sync_root "$HOME/.pi/agent/sessions/$pislug"
              sync_root "$HOME/.claude/projects/$claudeslug"
            done
          done
        }

        # Re-enumerate on a slow loop: the SET of session roots changes as
        # projects are created, so unison runs one-shot per root here (not
        # -repeat watch, which binds a fixed root list at launch). ~2min
        # latency is fine for session state (a handoff artifact).
        while :; do
          enumerate_once
          sleep 120
        done
      '';
    in
    lib.nameValuePair "unison-sessions-${peer}" {
      Unit = {
        Description = "Unison per-project pi/claude session sync to ${peer}";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${script}";
        Restart = "always";
        RestartSec = 30;
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.unison pkgs.openssh pkgs.coreutils pkgs.gnused ]}" ];
      };
      Install.WantedBy = [ "default.target" ];
    };

  sessionServices = lib.listToAttrs (map mkSessionService allSessionPeers);

  # The synced project roots this host participates in (absolute paths). Used
  # by the git-ff helper below.
  syncedRoots = map (e: abs e.path) (lib.filter participates cfg.directories);

  # unison syncs the working TREE but not git history (see header), so after a
  # sync a repo's files can be ahead of its own .git HEAD until you pull. This
  # helper fast-forwards each synced repo's branch to its upstream, but ONLY
  # when it is safe: a clean tree (ignoring untracked), a real upstream, and an
  # actual fast-forward. It never merges, rebases, stashes or discards; a
  # dirty or diverged repo is reported and skipped. Safe to run on a timer.
  gitFfHelper = pkgs.writeShellApplication {
    name = "ai-sync-git-ff";
    runtimeInputs = [ pkgs.git ];
    text = ''
      set -u
      roots=(${lib.concatMapStringsSep " " lib.escapeShellArg syncedRoots})
      rc=0
      for d in "''${roots[@]}"; do
        [ -d "$d/.git" ] || { echo "skip (no .git): $d"; continue; }
        cd "$d" || { echo "skip (cd failed): $d"; rc=1; continue; }
        # A unison-synced .git holds only config + info/exclude until the
        # one-time `git clone` populates objects/refs; guard the hollow case.
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
          || { echo "skip (hollow .git, needs one-time git clone): $d"; continue; }
        br=$(git symbolic-ref --quiet --short HEAD) || { echo "skip (detached HEAD): $d"; continue; }
        up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) \
          || { echo "skip (no upstream for $br): $d"; continue; }
        # Dirty tracked tree means a human is mid-edit; leave it alone.
        if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
          echo "skip (dirty): $d"; continue
        fi
        git fetch --quiet "''${up%%/*}" 2>/dev/null || { echo "skip (fetch failed): $d"; rc=1; continue; }
        local_sha=$(git rev-parse HEAD); up_sha=$(git rev-parse "$up")
        if [ "$local_sha" = "$up_sha" ]; then
          continue # already current
        elif git merge-base --is-ancestor HEAD "$up"; then
          if git merge --ff-only --quiet "$up"; then
            echo "ff: $d  $br -> $(git rev-parse --short HEAD)"
          else
            echo "skip (ff-only merge failed): $d"; rc=1
          fi
        else
          echo "skip (diverged, needs manual reconcile): $d"
        fi
      done
      exit "$rc"
    '';
  };
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
          sessionRoots = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to also sync pi/claude session state keyed to this exact
              path. true (default): sync the tree AND the ~/.pi + ~/.claude
              session dirs for this path (single-project entries like
              pure-lang). false: sync ONLY the tree -- use for PARENT trees
              like ~/ws and ~/src whose own path has no meaningful session
              dir; per-project session state under them is handled by
              programs.ai.sync.sessionTrees instead.
            '';
          };
          sshUser = lib.mkOption {
            type = lib.types.str;
            default = "gburd";
            description = "SSH user on the peer.";
          };
        };
      });
    };
    sessionTrees = lib.mkOption {
      default = [ ];
      description = ''
        Parent directories (e.g. ~/ws, ~/src) whose IMMEDIATE sub-projects
        should have their pi/claude session state synced per-project, at
        runtime (so projects can come and go without a rebuild). The parent
        tree itself is synced by a normal `directories` entry with
        sessionRoots = false. maki/codex/zed session state is NOT handled
        (not path-mappable). See the mkSessionService comment.
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Parent dir (absolute or ~/-relative).";
          };
          hosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Short names of the hosts that share these sessions.";
          };
          exclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Sub-project basenames to skip (worktree repos, nix-config, etc.).";
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
    home.packages = [ pkgs.unison gitFfHelper ];
    systemd.user.services = services // sessionServices // {
      # Periodic safe fast-forward of each synced repo (see gitFfHelper).
      ai-sync-git-ff = {
        Unit.Description = "Fast-forward unison-synced git repos to upstream";
        Service = {
          Type = "oneshot";
          ExecStart = "${gitFfHelper}/bin/ai-sync-git-ff";
          Environment = [ "PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh ]}" ];
        };
      };
    };
    systemd.user.timers.ai-sync-git-ff = {
      Unit.Description = "Periodic fast-forward of unison-synced git repos";
      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "30min";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
