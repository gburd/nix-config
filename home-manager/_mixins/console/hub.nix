# `hub-push`: back up every git repo under ~/ws and ~/src to the git hub
# (gburd@meh:~/hub/<name>.git, see nixos/workstation/meh/hub.nix).
#
#   hub-push [repo-dir...]   default: every repo with history in ~/ws, ~/src
#
# Branches, tags and the stash go to refs/hosts/<this host>/... (this host's
# namespace on the hub, where force updates are allowed), so a rebase on one
# host never rewrites another host's copy. Hourly via hub-push.timer.
#
# Repo names: ~/ws/postgres -> ws-postgres. Nested repos (ws/postgres/undo is
# a worktree, not a repo) are covered by their main repo's refs.
{ pkgs, lib, hostname, ... }:
let
  hubUrl = "gburd@meh.ts.burd.me:hub";
  hubPush = pkgs.writeShellScriptBin "hub-push" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils pkgs.findutils ]}:$PATH
    host=${hostname}
    if [ $# -eq 0 ]; then
      set -- $(for d in "$HOME"/ws/*/ "$HOME"/src/*/; do
        d=''${d%/}; [ -d "$d/.git" ] && git -C "$d" rev-parse -q --verify HEAD >/dev/null 2>&1 && echo "$d"
      done)
    fi
    ok=0; fail=0
    for d in "$@"; do
      rel=''${d#"$HOME"/}; name=$(printf '%s' "$rel" | tr '/' '-')
      ssh -n -o BatchMode=yes meh.ts.burd.me "hub-init $name" || { echo "hub-push: $rel: hub-init failed" >&2; fail=$((fail+1)); continue; }
      refspecs=("+refs/heads/*:refs/hosts/$host/heads/*" "+refs/tags/*:refs/hosts/$host/tags/*")
      git -C "$d" rev-parse -q --verify refs/stash >/dev/null && refspecs+=("+refs/stash:refs/hosts/$host/stash")
      if git -C "$d" push -q --no-verify -o "host=$host" "${hubUrl}/$name.git" "''${refspecs[@]}" 2>/tmp/hub-push.$$; then
        ok=$((ok+1))
      else
        echo "hub-push: $rel: $(head -c 300 /tmp/hub-push.$$)" >&2; fail=$((fail+1))
      fi
    done
    rm -f /tmp/hub-push.$$
    echo "hub-push: $ok pushed, $fail failed"
    [ $fail -eq 0 ]
  '';
in
{
  home.packages = [ hubPush ];
  systemd.user.services.hub-push = {
    Unit.Description = "Push every ~/ws and ~/src git repo to the hub on meh";
    Service = {
      Type = "oneshot";
      ExecStart = "${hubPush}/bin/hub-push";
      Nice = 10;
    };
  };
  systemd.user.timers.hub-push = {
    Unit.Description = "Hourly push of git repos to the hub";
    Timer = {
      OnBootSec = "15min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
