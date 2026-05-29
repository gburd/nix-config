{ lib }:
# Single source of truth for the AI agents' bash command allowlist.
#
# kiro-cli (regex), Claude Code (Bash(...) globs in ~/.claude/settings.json),
# and maki (TOML globs) all need the same "auto-approve these safe command
# heads" policy. Historically each agent carried its own copy and they drifted
# (notably maki's was much narrower, so it prompted for git/npm/grep/etc. that
# the others auto-allowed). This module derives every form from one `heads`
# list so they stay in sync.
#
#   heads        -> plain command tokens (what the user types)
#   kiroRegex    -> kiro-cli execute_bash.allowedCommands (anchored ^...$ regex)
#   makiAllow    -> maki ~/.config/maki/permissions.toml [bash].allow (globs)
#   makiDeny     -> maki [bash].deny, matching the Claude/kiro destructive-op set
#
# `dd`/`mkfs`/force-push/etc. live in the deny set (deny wins over allow).
let
  # Canonical safe command heads. Keep alphabetically grouped-ish; order does
  # not affect matching. `[` and `[[` are shell test builtins; `TZ=` (env-var
  # prefix) is handled as a regex special below since it needs `\S+`.
  heads = [
    "7z"
    "asdf"
    "avahi-browse"
    "aws"
    "az"
    "bc"
    "bunzip2"
    "bzip2"
    "cat"
    "claude"
    "column"
    "cp"
    "createdb"
    "crontab"
    "csplit"
    "date"
    "df"
    "direnv"
    "disown"
    "docker"
    "dropdb"
    "dstat"
    "du"
    "echo"
    "expr"
    "false"
    "file"
    "fold"
    "for"
    "free"
    "gcloud"
    "getfacl"
    "git"
    "grep"
    "gsutil"
    "gunzip"
    "gzip"
    "heroku"
    "http-server"
    "if"
    "iftop"
    "iostat"
    "iotop"
    "jest"
    "join"
    "journalctl"
    "less"
    "lsof"
    "make"
    "md5sum"
    "mdns-scan"
    "mongo"
    "mongod"
    "mongodump"
    "mongoexport"
    "mongoimport"
    "mongorestore"
    "mongosh"
    "mysql"
    "mysqladmin"
    "mysqldump"
    "mysqlimport"
    "nano"
    "nc"
    "nethogs"
    "netlify"
    "netstat"
    "nohup"
    "npm"
    "npx"
    "ntl"
    "nvm"
    "open"
    "openssl"
    "paste"
    "pg_dump"
    "pg_dumpall"
    "pg_restore"
    "pidof"
    "pip"
    "pip3"
    "pnpm"
    "printf"
    "psql"
    "pstree"
    "pwgen"
    "pyenv"
    "python"
    "python3"
    "rbenv"
    "redis-cli"
    "rvm"
    "["
    "[["
    "screen"
    "seq"
    "sha1sum"
    "sha256sum"
    "sha512sum"
    "shasum"
    "shuf"
    "split"
    "sqlite3"
    "ss"
    "stat"
    "strace"
    "tail"
    "tar"
    "tee"
    "test"
    "time"
    "timedatectl"
    "timeout"
    "tmux"
    "tr"
    "true"
    "unxz"
    "unzip"
    "uuidgen"
    "vc"
    "vercel"
    "view"
    "vim"
    "vmstat"
    "watch"
    "while"
    "xargs"
    "xz"
    "yarn"
    "yes"
    "zip"
    # Dev/build toolchain (NixOS + Rust workstation). Previously only maki
    # allowed these; promoted to the shared list so kiro/claude auto-approve
    # them too. `sudo` stays in the deny set, so `sudo nixos-rebuild` still
    # prompts; bare `nixos-rebuild`/`home-manager`/`cargo`/`nix` are allowed.
    "cargo"
    "nix"
    "nix-build"
    "nix-shell"
    "nixos-rebuild"
    "home-manager"
  ];

  escapeRegex = builtins.replaceStrings
    [ "[" "]" "(" ")" "." "*" "+" "?" "{" "}" "|" "^" "$" ]
    [ "\\[" "\\]" "\\(" "\\)" "\\." "\\*" "\\+" "\\?" "\\{" "\\}" "\\|" "\\^" "\\$" ];

  # kiro evaluates each entry as ^...$; (\s.*)? lets it match "head" or "head args".
  kiroRegex = (map (h: "^${escapeRegex h}(\\s.*)?$") heads)
    # TZ=<value> <cmd> — env-var assignment prefix (needs \S+ after TZ=).
    ++ [ "^TZ=\\S+(\\s.*)?$" ];

  # maki matches globs against the command line. Emit both the bare command
  # (e.g. "make") and the with-args form ("make *") so a no-arg invocation is
  # also auto-approved, matching kiro's (\s.*)? behavior.
  makiAllow = (lib.concatMap (h: [ h "${h} *" ]) heads)
    ++ [ "TZ=* *" ];

  # Destructive operations — denied for every agent. Mirrors the Claude Code
  # permissions.deny set and kiro's deniedCommands, expressed as maki globs
  # (deny takes precedence over allow).
  makiDeny = [
    "rm -rf *"
    "rm -fr *"
    "rm -Rf *"
    "rm --recursive *"
    "sudo *"
    "git push --force*"
    "git push *--force*"
    "git push --force-with-lease*"
    "git push -f *"
    "git push *-f *"
    "git reset --hard*"
    "git filter-branch*"
    "git filter-repo*"
    "curl *|bash*"
    "curl *|sh*"
    "wget *|bash*"
    "wget *|sh*"
    "mkfs *"
    "dd * of=/dev/*"
    "dd of=/dev/*"
  ];
in
{
  inherit heads kiroRegex makiAllow makiDeny;
}
