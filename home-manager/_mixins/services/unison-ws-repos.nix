# The ~/ws repos that are NOT part of the single ~/ws tree (they use git
# worktrees, or are too large to sync as part of it), synced one by one.
# Imported by every mesh host so the list lives in one place.
#
# Each entry syncs the repo's working tree plus its .git/config and
# .git/info/exclude (history goes through git: the repos were seeded with a
# bundle, see .agent/werk-migration.md). Worktree checkouts inside a repo dir
# have their own `.git` file and are ignored here; they are per host
# (`git worktree add`), as are /scratch worktrees. sessionRoots = true carries
# the project's pi/claude sessions with it.
#
# Hosts: floki and werk only for now. meh has ~100 GB free and can't hold
# postgres (about 140 GB with undo/.agent/round2); arnold joins once werk is
# the primary and floki is retired.
{ lib, ... }:
let
  hosts = [ "floki" "werk" ];
  # Build output, at any depth (`Name`). Only names no repo tracks files
  # under, bar the `keep` exceptions: `results` and `log` hid 947 tracked
  # files (libdb, mentat, pg_weave ...) and were dropped (2026-10-30).
  build = [ "build" "build-*" "builddir" "tmp_install" "result" "testrun" ".zvec-grep" ];
  repo = name: extra: keep: {
    inherit name hosts;
    path = "~/ws/${name}";
    ignoreNames = build;
    ignores = extra;
    ignoreNot = keep;
  };
  # postgres's linked worktrees under ~/ws/postgres (59, from `git worktree
  # list` on floki 2026-10-30). Each is a separate checkout with a `.git`
  # FILE holding an absolute path to the main repo's .git/worktrees/<n>, so
  # it can't be synced as files: werk gets its own `git worktree add` of the
  # same branch (seed step), and the files inside travel with the branch
  # (commit/push) or via the worktree's own sync entry when added here.
  # `ignores` entries are `Path <x>` relative to the repo root.
  postgresWorktrees = [
    "adaptive-buffer-mgmt"
    "agents"
    "arc"
    "bcs"
    "bf/icarus"
    "bits"
    "cat-catam-p0"
    "cat-catam-p1"
    "cat-catam-p2"
    "cat-catam-p3"
    "cat-catam-p4"
    "cat-tu-refactor"
    "catam"
    "catup"
    "cf-5556"
    "cf-6221"
    "dan"
    "deolasee/warm"
    "edb/undo-record-set"
    "edb/zheap"
    "elastic"
    "flake"
    "fts"
    "hash-metapage-overflow-signal"
    "hash-pinonly-buffer-rework"
    "heap-prune-freq"
    "hegel"
    "heikki/threading"
    "heikki/zedstore"
    "htbl"
    "idxam"
    "ivmdf"
    "lime"
    "llvm21"
    "lrlck"
    "master"
    "multi-toast"
    "nbm"
    "nbm-build"
    "nbtkpc"
    "nikhil/zstd-dict"
    "ntsv"
    "orioledb/ext"
    "orioledb/postgres"
    "orvos"
    "osic"
    "pgindent"
    "phot"
    "recno"
    "scratch"
    "sqh"
    "swizzle"
    "tepid"
    "thomas/stdatomic"
    "thr"
    "toast"
    "undo"
    "wick/arc"
    "xtc"
  ];
in
{
  programs.ai.sync.directories = lib.mkAfter [
    (repo "improv" [ ] [ ])
    (repo "libdb" [ ] [ ])
    (repo "libxtc" [ ] [ ])
    (repo "mentat" [ ] [ "crates/sqlite/mentat/build" ])
    (repo "pg_tre" [ ] [ ])
    (repo "pg_weave" [ ] [ ])
    (repo "ra" [ ] [ ])
    # osv/.local holds 1761 tracked notes (7 MB) next to 18 GB of untracked
    # runs and toolchains; only the big untracked trees stay per host, and
    # bench24/wt is a gitlink with no .gitmodules entry (its own checkout).
    (repo "osv" [ ".local/readiness-audit" ".local/teams" ".local/pg18" ".local/bench24/wt" ] [ ])
    # solnix/scratch (28 GB) synced, per the plan.
    (repo "solnix" [ ] [ "scratch/nix224/src-mod/src/libstore/unix/build" "scratch/nix224/src-orig/src/libstore/unix/build" "scratch/nix224/verify/src/libstore/unix/build" ])
    # postgres: its in-repo worktrees are per host (see postgresWorktrees).
    (repo "postgres" postgresWorktrees [ ])
  ];
  # pi/claude sessions of the postgres worktrees (~/ws/postgres/undo, /xtc,
  # ...) are keyed by their own path, one level below ~/ws/postgres, so the
  # ~/ws session tree doesn't reach them.
  programs.ai.sync.sessionTrees = lib.mkAfter [{ path = "~/ws/postgres"; inherit hosts; }];
}
