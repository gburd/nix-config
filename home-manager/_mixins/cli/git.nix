{ config, lib, pkgs, ... }:
let
  ssh = "${pkgs.openssh}/bin/ssh";

  git-gburd = pkgs.writeShellScriptBin "git-gburd" ''
    repo="$(git remote -v | grep git@burd.me | head -1 | cut -d ':' -f2 | cut -d ' ' -f1)"
    # Add a .git suffix if it's missing
    if [[ "$repo" != *".git" ]]; then
      repo="$repo.git"
    fi

    if [ "$1" == "init" ]; then
      if [ "$2" == "" ]; then
        echo "You must specify a name for the repo"
        exit 1
      fi
      ${ssh} -A git@burd.me << EOF
        git init --bare "$2.git"
        git -C "$2.git" branch -m main
    EOF
      git remote add origin git@burd.me:"$2.git"
    elif [ "$1" == "ls" ]; then
      ${ssh} -A git@burd.me ls
    else
      ${ssh} -A git@burd.me git -C "/srv/git/$repo" $@
    fi
  '';

  # Pre-commit guard: refuses to commit crash/profile dumps and large
  # binaries. Born from repeated leaks where `perf record` / Valgrind /
  # core dumps captured the shell environment (including a live
  # AWS_BEARER_TOKEN_BEDROCK) and got committed. A name + size guard
  # catches every one of those cases without the false positives of an
  # inline secret-regex. Installed globally via core.hooksPath; chains to
  # any repo-local .git/hooks/pre-commit so husky / pre-commit / lefthook
  # still run.
  #
  # Escape hatches:
  #   ALLOW_DUMP_COMMIT=1 git commit ...   (skip the guard, keep chaining)
  #   git commit --no-verify               (skip all hooks)
  #   DUMP_GUARD_MAX_MB=20 git commit ...  (raise the binary size ceiling)
  git-dump-guard = pkgs.writeShellApplication {
    name = "git-dump-guard";
    runtimeInputs = [ pkgs.git pkgs.gnugrep pkgs.coreutils ];
    text = ''
      chain_only=0
      if [ "''${ALLOW_DUMP_COMMIT:-}" = "1" ]; then
        chain_only=1
      fi

      block=0
      max_mb="''${DUMP_GUARD_MAX_MB:-5}"
      max_bytes=$(( max_mb * 1024 * 1024 ))

      # Crash dumps and profiling artifacts, matched on basename.
      dump_re='(^|/)(core|core\.[0-9]+|vgcore\.[^/]+|[^/]+\.core|perf\.data|perf\.data\.old|[^/]+\.perf\.data|[^/]+\.coredump|[^/]+\.hprof|[^/]+\.dmp|[^/]+\.mdmp)$'

      if [ "$chain_only" -eq 0 ]; then
        while IFS= read -r -d "" f; do
          if printf '%s\n' "$f" | grep -qE "$dump_re"; then
            printf 'dump-guard: BLOCKED %s (crash/profile dump)\n' "$f" >&2
            block=1
            continue
          fi
          size=$(git cat-file -s ":$f" 2>/dev/null || printf '0')
          if [ "$size" -gt "$max_bytes" ]; then
            # grep -I treats a file containing NUL as "binary, no match".
            # Process substitution avoids a SIGPIPE/pipefail race.
            if ! LC_ALL=C grep -Iq . < <(git show ":$f" 2>/dev/null); then
              printf 'dump-guard: BLOCKED %s (%s-byte binary > %s MiB; use git-lfs or .gitignore)\n' "$f" "$size" "$max_mb" >&2
              block=1
              continue
            fi
          fi
        done < <(git diff --cached --name-only -z --diff-filter=AM)

        if [ "$block" -ne 0 ]; then
          printf '\ndump-guard: commit aborted. Override: ALLOW_DUMP_COMMIT=1 git commit ...  or  git commit --no-verify\n' >&2
          exit 1
        fi
      fi

      # Chain to a repo-local hook so we never shadow project hook managers.
      git_dir=$(git rev-parse --git-dir 2>/dev/null || printf '.git')
      local_hook="$git_dir/hooks/pre-commit"
      self=$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")
      if [ -x "$local_hook" ]; then
        local_real=$(readlink -f "$local_hook" 2>/dev/null || printf '%s' "$local_hook")
        if [ "$local_real" != "$self" ]; then
          exec "$local_hook"
        fi
      fi
      exit 0
    '';
  };

  # Patterns that must never be committed in any repo. Crash/profile
  # dumps head the list (root cause of past AWS token leaks: perf /
  # Valgrind / core dumps captured the shell env). Used both for
  # programs.git.ignores (-> ~/.config/git/ignore) and to populate
  # ~/.gitignore_global, which a hand-maintained ~/.gitconfig still
  # points core.excludesFile at; writing both keeps them in sync no
  # matter which config file wins precedence.
  globalIgnores = [
    ".direnv"
    "result"
    # AI tool runtime dirs — contain state/sessions, not source
    ".memelord/"
    ".pi/agent/sessions/"
    ".kiro/sessions/"
    ".claude/settings.local.json"
    # Crash dumps & profiling artifacts — never commit these.
    "core"
    "core.[0-9]*"
    "*.core"
    "vgcore.*"
    "perf.data"
    "perf.data.old"
    "*.perf.data"
    "*.coredump"
    "*.hprof"
    "*.dmp"
    "*.mdmp"
    # Compiled build artifacts that have leaked into history before.
    # (Language-specific build dirs like target/ stay in per-repo
    # .gitignore to avoid surprising global excludes.)
    "*.o"
    "*.lo"
    "*.gcda"
    "*.gcno"
    "*.gcov"
    ".libs/"
  ];
in
{
  home.packages = [ git-gburd ];

  # Global pre-commit hook (core.hooksPath points here below).
  xdg.configFile."git/hooks/pre-commit".source =
    "${git-dump-guard}/bin/git-dump-guard";

  # Mirror the ignore list to ~/.gitignore_global. A hand-maintained
  # ~/.gitconfig (not managed here) sets core.excludesFile to this path
  # and, being read last, wins over home-manager's ~/.config/git/ignore.
  # Writing this file makes the patterns effective regardless.
  home.file.".gitignore_global".text =
    lib.concatStringsSep "\n" globalIgnores + "\n";

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCqHOIyYwbp42C7MxnRFxOcy+ZE8cNOWdsdvCgVFm1L";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Greg Burd";
        email = "greg@burd.me";
      };
      init.defaultBranch = "main";
      gpg.format = "ssh";
      "gpg.ssh".program = lib.mkDefault "/opt/1Password/op-ssh-sign";
      commit.gpgsign = true;
      tag.gpgsign = true;
      # Route all repos through the global dump guard. It chains to any
      # repo-local .git/hooks/pre-commit, so project hooks still run.
      core.hooksPath = "${config.xdg.configHome}/git/hooks";
    };
    lfs.enable = true;
    ignores = globalIgnores;
  };
}
