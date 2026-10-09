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

  # Pre-commit guard. Two layers, both run on staged changes:
  #   1. Dump/large-binary guard (name + size). Born from repeated leaks
  #      where perf record / Valgrind / core dumps captured the shell
  #      environment (including a live AWS_BEARER_TOKEN_BEDROCK) and got
  #      committed. A binary dump is invisible to text secret scanners.
  #   2. gitleaks protect --staged. Catches literal credentials typed
  #      into text files (tokens, keys, high-entropy strings).
  # Installed globally via core.hooksPath; chains to any repo-local
  # .git/hooks/pre-commit so husky / pre-commit / lefthook still run.
  #
  # Escape hatches:
  #   ALLOW_DUMP_COMMIT=1 git commit ...   (skip both checks, keep chaining)
  #   git commit --no-verify               (skip all hooks)
  #   DUMP_GUARD_MAX_MB=20 git commit ...  (raise the binary size ceiling)
  git-dump-guard = pkgs.writeShellApplication {
    name = "git-dump-guard";
    runtimeInputs = [ pkgs.git pkgs.gnugrep pkgs.coreutils pkgs.gitleaks ];
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

        # Secret scan of staged text changes. --no-banner keeps it quiet;
        # nonzero exit means a finding (or, with --exit-code, a leak).
        if ! gitleaks protect --staged --redact --no-banner 2>/dev/null; then
          printf '\ngitleaks: BLOCKED - a staged change looks like a secret.\n' >&2
          printf 'Review above. Override: ALLOW_DUMP_COMMIT=1 git commit ...  or  git commit --no-verify\n' >&2
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

  # Last line of defence before anything becomes public: scan the commits
  # actually being pushed. pre-commit alone is not enough -- a commit made
  # with --no-verify, created by a tool that bypasses hooks, or merged in
  # from another branch reaches the remote unchecked. That is how an
  # imapsync log containing credentials reached the public GitHub repo.
  #
  # git feeds pre-push "<local ref> <local sha> <remote ref> <remote sha>"
  # on stdin, one line per ref. For each, scan the range the remote does not
  # have yet. For a new branch (remote sha all zeroes) there is no base, so
  # scan the commits unique to it rather than its entire history.
  #
  # Escape hatches:
  #   ALLOW_DUMP_PUSH=1 git push ...   (skip the scan, keep chaining)
  #   git push --no-verify             (skip all hooks)
  git-push-guard = pkgs.writeShellApplication {
    name = "git-push-guard";
    runtimeInputs = [ pkgs.git pkgs.gnugrep pkgs.coreutils pkgs.gitleaks ];
    text = ''
      zero='0000000000000000000000000000000000000000'
      failed=0

      if [ "''${ALLOW_DUMP_PUSH:-}" != "1" ]; then
        while read -r _local_ref local_sha _remote_ref remote_sha; do
          # Deleting a ref pushes no content.
          [ "$local_sha" = "$zero" ] && continue

          if [ "$remote_sha" = "$zero" ]; then
            # New branch: only what no other remote-tracking ref already has.
            others=$(git for-each-ref --format='%(refname)' refs/remotes 2>/dev/null | tr '\n' ' ')
            log_opts="$local_sha --not $others"
          else
            log_opts="$remote_sha..$local_sha"
          fi

          # Nothing to scan (already up to date, or an unreadable range).
          # shellcheck disable=SC2086
          if [ -z "$(git rev-list $log_opts 2>/dev/null | head -1)" ]; then
            continue
          fi

          # gitleaks exits non-zero on a finding. --redact keeps the secret
          # itself out of the terminal and out of any CI log.
          if ! gitleaks git --log-opts "$log_opts" --redact --no-banner 2>/dev/null; then
            printf '\npush-guard: BLOCKED - a commit being pushed looks like it has a secret.\n' >&2
            printf 'Range: %s\n' "$log_opts" >&2
            failed=1
          fi
        done
      fi

      if [ "$failed" = "1" ]; then
        printf '\npush-guard: push aborted. False positive?\n' >&2
        printf '  ALLOW_DUMP_PUSH=1 git push ...   or   git push --no-verify\n' >&2
        printf 'If it is real, rewrite the history first -- a push to a public remote\n' >&2
        printf 'cannot be taken back; the object stays fetchable by its SHA.\n' >&2
        exit 1
      fi

      # Chain to a repo-local hook so we never shadow project hook managers.
      git_dir=$(git rev-parse --git-dir 2>/dev/null || printf '.git')
      local_hook="$git_dir/hooks/pre-push"
      self=$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")
      if [ -x "$local_hook" ]; then
        local_real=$(readlink -f "$local_hook" 2>/dev/null || printf '%s' "$local_hook")
        if [ "$local_real" != "$self" ]; then
          exec "$local_hook" "$@"
        fi
      fi
      exit 0
    '';
  };

  # Patterns that must never be committed in any repo. Crash/profile
  # dumps head the list (root cause of past AWS token leaks: perf /
  # Valgrind / core dumps captured the shell env). Used both for
  # programs.git.ignores (-> ~/.config/git/ignore) and to populate
  # ~/.gitignore_global for any tooling that references that path.
  globalIgnores = [
    ".direnv"
    "result"
    # AI tool runtime dirs — contain state/sessions, not source
    ".memelord/"
    ".pi/agent/sessions/"
    ".kiro/sessions/"
    ".claude/settings.local.json"
    # Per-project domain steering generated by `project-steering` (local,
    # host-path-specific) — not source. Both the Claude/Pi @import file and
    # the AGENTS.md-referenced inline file, plus Kiro's symlinked domain files.
    ".claude/steering-domains.md"
    ".agent-steering-domains.md"
    ".kiro/steering/domain-*"
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
  home.packages = [ git-gburd pkgs.gitleaks ];

  # Global pre-commit hook (core.hooksPath points here below).
  xdg.configFile."git/hooks/pre-commit".source =
    "${git-dump-guard}/bin/git-dump-guard";

  # Global pre-push hook: the same gitleaks scan over the commits being
  # pushed, so a secret that got committed anyway still cannot reach a
  # remote.
  xdg.configFile."git/hooks/pre-push".source =
    "${git-push-guard}/bin/git-push-guard";

  # Mirror the ignore list to ~/.gitignore_global so any tool or config
  # referencing that conventional path resolves to a real file.
  home.file.".gitignore_global".text =
    lib.concatStringsSep "\n" globalIgnores + "\n";

  # Retire the old hand-maintained ~/.gitconfig: everything in it now
  # lives in programs.git below, so the stray real file (which shadowed
  # home-manager's ~/.config/git/config) must be removed for HM's config
  # to take effect. Back it up once, then delete.
  home.activation.retireStrayGitconfig =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -e "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
        run mv -v "$HOME/.gitconfig" "$HOME/.gitconfig.pre-home-manager.bak"
      fi
    '';

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCqHOIyYwbp42C7MxnRFxOcy+ZE8cNOWdsdvCgVFm1L";
      signByDefault = true;
    };
    lfs.enable = true;
    # Aliases live in git-common.nix.
    settings = {
      gpg.format = "ssh";
      # Sign with the sops-deployed on-disk signing key via OpenSSH's own
      # ssh-keygen signer — no dependency on 1Password's op-ssh-sign (which
      # needed an unlocked GUI app). On hosts running the ssh-management
      # module (floki/meh) this is overridden with mkForce to the rotating
      # key + the matching program; the default here covers any other host.
      "gpg.ssh".program = lib.mkDefault "${pkgs.openssh}/bin/ssh-keygen";
      commit.gpgsign = true;
      tag.gpgsign = true;

      # Identity, aliases, push/pull policy, colours and format live in
      # git-common.nix (shared with the solnix hosts).
      core = {
        editor = "nvim";
        # core.pager is left to git's default (delta is disabled — see
        # programs.delta in console/default.nix). `git diff` shows a plain
        # colored diff through the normal pager, not the side-by-side TUI.
        # Route all repos through the global dump + gitleaks guard. It
        # chains to any repo-local .git/hooks/pre-commit, so project
        # hooks still run.
        hooksPath = "${config.xdg.configHome}/git/hooks";
      };
      "protocol \"file\"".allow = "always";
      diff.tool = "meld";
      difftool.prompt = false;
      "difftool \"meld\"".cmd = "meld \"$LOCAL\" \"$REMOTE\"";
      merge.tool = "meld";
      "mergetool \"meld\"".cmd = "meld \"$LOCAL\" \"$BASE\" \"$REMOTE\" --output \"$MERGED\"";
      # CRLF helper filter (referenced by per-repo .gitattributes that opt in).
      "filter \"cr\"" = {
        clean = "LC_CTYPE=C awk '{printf(\"%s\\n\", $0)}' | LC_CTYPE=C tr '\\r' '\\n'";
        smudge = "tr '\\n' '\\r'";
      };
    };
    ignores = globalIgnores;
  };
}
