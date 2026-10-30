{ pkgs, ... }:
# `agents` -- run the coding agents in tmux, one session per project, the way
# they ran in terminals on floki. Pi sessions resume (`pi -c`), and their
# state follows the project between hosts through unison's sessionTrees, so a
# project started on floki continues on werk where it left off.
#
#   agents up [proj...]   start (or keep) a session per project, `pi -c` in it.
#                         With no args: every project listed in
#                         ~/.config/agents/projects (one path under ~ per line).
#   agents ls             sessions with their project and whether pi is running
#   agents attach <proj>  attach (or switch, inside tmux)
#   agents stop <proj>    end that session
#   agents from <host>    write ~/.config/agents/projects from the projects that
#                         have a pi running on <host> right now (e.g. floki)
#
# Session names are the project path with `/` -> `_` (tmux forbids `.` and
# `:`), so ws/postgres/undo is `ws_postgres_undo`.
let
  agents = pkgs.writeShellApplication {
    name = "agents";
    runtimeInputs = with pkgs; [ tmux coreutils gnused gnugrep procps openssh ];
    text = ''
      list="$HOME/.config/agents/projects"
      sname() { printf '%s' "$1" | sed 's#^/*##; s#[/.:]#_#g'; }
      projects() {
        if [ $# -gt 0 ]; then printf '%s\n' "$@"
        elif [ -s "$list" ]; then grep -vE '^\s*(#|$)' "$list"
        else echo "agents: no projects given and $list is empty (try: agents from floki)" >&2; return 1
        fi
      }
      cmd=''${1:-ls}; shift || true
      case "$cmd" in
        up)
          projects "$@" | while IFS= read -r p; do
            p=''${p#"$HOME"/}; dir="$HOME/$p"
            [ -d "$dir" ] || { echo "skip $p: no such directory"; continue; }
            s=$(sname "$p")
            if tmux has-session -t "=$s" 2>/dev/null; then echo "up   $s (already)"; continue; fi
            # Login shell so direnv and hm-session-vars load, then resume pi;
            # the shell stays when pi exits so the window survives.
            tmux new-session -d -s "$s" -c "$dir" -n pi "bash -lc 'pi -c; exec bash -l'"
            echo "up   $s ($p)"
          done ;;
        ls)
          tmux list-sessions -F '#{session_name} #{session_path} #{session_attached}' 2>/dev/null \
            | while read -r s path att; do
                # pi runs as `node .../pi-coding-agent` somewhere under the
                # pane's shell; look at the whole process tree, not one level.
                pid=$(tmux list-panes -t "=$s" -F '#{pane_pid}' | head -1)
                pi=-
                for c in $(pgrep -f 'pi-coding-agent' || true); do
                  q=$c
                  while [ -n "$q" ] && [ "$q" -gt 1 ]; do
                    [ "$q" = "$pid" ] && { pi=pi; break 2; }
                    q=$(ps -o ppid= -p "$q" | tr -d ' ')
                  done
                done
                printf '%-34s %-4s %s%s\n' "$s" "$pi" "''${path#"$HOME"/}" "$([ "$att" != 0 ] && echo ' (attached)')"
              done ;;
        attach)
          s=$(sname "''${1:?usage: agents attach <project>}"); s=''${s#ws_}; tmux has-session -t "=$s" 2>/dev/null || s="ws_$s"
          if [ -n "''${TMUX:-}" ]; then tmux switch-client -t "=$s"; else tmux attach -t "=$s"; fi ;;
        stop)
          s=$(sname "''${1:?usage: agents stop <project>}"); tmux kill-session -t "=$s" 2>/dev/null || tmux kill-session -t "=ws_$s" ;;
        from)
          h=''${1:?usage: agents from <host>}; mkdir -p "$(dirname "$list")"
          ssh -n "$h" 'for p in $(pgrep -f "pi-coding-agent"); do readlink /proc/$p/cwd; done' \
            | sed "s#^$HOME/##" | grep -v "^$HOME\$" | sort -u > "$list.new"
          mv "$list.new" "$list"; echo "wrote $(wc -l < "$list") projects to $list:"; sed 's/^/  /' "$list" ;;
        *) echo "usage: agents up|ls|attach|stop|from" >&2; exit 64 ;;
      esac
    '';
  };
in
{
  home.packages = [ agents ];
}
