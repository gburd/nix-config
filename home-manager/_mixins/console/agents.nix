{ pkgs, ... }:
# `agents` -- run the coding agents in tmux, one session per project, the way
# they ran in terminals on floki. Sessions resume where they left off (pi -c /
# maki -c), and their state follows the project between hosts through
# unison's sessionTrees, so a project started on floki continues on werk.
#
#   agents up [proj...]          start (or keep) a pi session per project.
#                                With no args: every project listed in
#                                ~/.config/agents/projects (one path per line).
#   agents up --maki [proj...]   the same with maki instead of pi
#   agents maki [proj...]        shorthand for `agents up --maki`
#   agents ls                    sessions, their agent, and whether it's running
#   agents attach <proj>         attach (or switch, inside tmux)
#   agents stop <proj>           end that session
#   agents from <host>           write ~/.config/agents/projects from the
#                                projects with a pi running on <host> now
#
# <proj> is a path in any spelling: ~/ws/libumem, /home/gburd/ws/libumem,
# ws/libumem, ., or a bare name under ~/ws (libumem). The session is named by
# the project path under ~ (ws/libumem); a maki session gets a `+maki`
# suffix (ws/libumem+maki) so pi and maki can run side by side in one project.
let
  agents = pkgs.writeShellApplication {
    name = "agents";
    runtimeInputs = with pkgs; [ tmux coreutils gnused gnugrep procps openssh ];
    text = ''
      list="$HOME/.config/agents/projects"

      # Normalise any spelling of a project to its path under $HOME
      # (ws/libumem). Absolute paths outside $HOME stay absolute.
      proj() {
        local p=$1 tilde="~"
        # a literal ~ arrives when the caller quoted it (agents attach "~/ws/x")
        if [ "$p" = "$tilde" ]; then p=$HOME
        elif [ "''${p:0:2}" = "$tilde/" ]; then p="$HOME/''${p:2}"
        fi
        if [ -d "$p" ]; then p=$(cd "$p" && pwd -P)
        elif [ -d "$HOME/$p" ]; then p=$(cd "$HOME/$p" && pwd -P)
        elif [ -d "$HOME/ws/$p" ]; then p=$(cd "$HOME/ws/$p" && pwd -P)
        else echo "agents: no such project: $1" >&2; return 1
        fi
        local home; home=$(cd "$HOME" && pwd -P)
        case "$p" in
          "$home") echo "~" ;;
          "$home"/*) echo "''${p#"$home"/}" ;;
          *) echo "$p" ;;
        esac
      }
      dir_of() { case "$1" in "~") echo "$HOME" ;; /*) echo "$1" ;; *) echo "$HOME/$1" ;; esac; }
      # tmux treats `:` as a window separator and a leading `=` as exact-match;
      # everything else in a path (/ . -) is fine in a session name. Targets
      # are written `=name:` -- without the trailing `:`, pane commands read
      # ws/solnix.io as session ws/solnix, pane io.
      sname() { printf '%s' "$1" | sed 's#:#_#g'; }
      projects() {
        if [ $# -gt 0 ]; then printf '%s\n' "$@"
        elif [ -s "$list" ]; then grep -vE '^\s*(#|$)' "$list"
        else echo "agents: no projects given and $list is empty (try: agents from floki)" >&2; return 1
        fi
      }
      # Find the session for a project: pi's name first, then maki's.
      session_for() {
        local p s; p=$(proj "$1") || return 1; s=$(sname "$p")
        if tmux has-session -t "=$s:" 2>/dev/null; then echo "$s"
        elif tmux has-session -t "=$s+maki:" 2>/dev/null; then echo "$s+maki"
        else echo "agents: no session for $p (agents ls)" >&2; return 1
        fi
      }
      up() {
        local agent=$1; shift
        projects "$@" | while IFS= read -r raw; do
          p=$(proj "$raw") || continue
          dir=$(dir_of "$p"); s=$(sname "$p")
          [ "$agent" = maki ] && s="$s+maki"
          if tmux has-session -t "=$s:" 2>/dev/null; then echo "up   $s (already)"; continue; fi
          # Login shell so direnv and hm-session-vars load, then resume the
          # agent's last session; the shell stays when it exits so the
          # window survives.
          tmux new-session -d -s "$s" -c "$dir" -n "$agent" "bash -lc '$agent -c; exec bash -l'"
          echo "up   $s"
        done
      }

      cmd=''${1:-ls}; shift || true
      case "$cmd" in
        up)
          if [ "''${1:-}" = --maki ]; then shift; up maki "$@"; else up pi "$@"; fi ;;
        maki) up maki "$@" ;;
        ls)
          tmux list-sessions -F '#{session_name}	#{session_path}	#{session_attached}' 2>/dev/null \
            | while IFS=$'\t' read -r s path att; do
                # The agent runs somewhere under the pane's shell; walk each
                # agent process's parents looking for the pane.
                pid=$(tmux list-panes -t "=$s:" -F '#{pane_pid}' | head -1)
                run=-
                # pi is the `pi` binary (nix) or `node .../pi-coding-agent` (npx)
                for c in $(pgrep -x 'pi|maki' || true) $(pgrep -f 'pi-coding-agent' || true); do
                  q=$c
                  while [ -n "$q" ] && [ "$q" -gt 1 ]; do
                    if [ "$q" = "$pid" ]; then
                      case "$(cat "/proc/$c/comm" 2>/dev/null)" in
                        maki) run=maki ;; *) run=pi ;;
                      esac
                      break 2
                    fi
                    q=$(ps -o ppid= -p "$q" | tr -d ' ')
                  done
                done
                printf '%-40s %-5s %s%s\n' "$s" "$run" "''${path#"$HOME"/}" "$([ "$att" != 0 ] && echo ' (attached)')"
              done ;;
        attach)
          s=$(session_for "''${1:?usage: agents attach <project>}") || exit 1
          if [ -n "''${TMUX:-}" ]; then tmux switch-client -t "=$s:"; else tmux attach -t "=$s:"; fi ;;
        stop)
          s=$(session_for "''${1:?usage: agents stop <project>}") || exit 1
          tmux kill-session -t "=$s:" && echo "stopped $s" ;;
        from)
          h=''${1:?usage: agents from <host>}; mkdir -p "$(dirname "$list")"
          ssh -n "$h" 'for p in $(pgrep -x pi) $(pgrep -f "pi-coding-agent"); do readlink /proc/$p/cwd; done' \
            | sed "s#^$HOME/##" | grep -v "^$HOME\$" | sort -u > "$list.new"
          mv "$list.new" "$list"; echo "wrote $(wc -l < "$list") projects to $list:"; sed 's/^/  /' "$list" ;;
        *) echo "usage: agents up [--maki] [proj...] | maki [proj...] | ls | attach <proj> | stop <proj> | from <host>" >&2; exit 64 ;;
      esac
    '';
  };
in
{
  home.packages = [ agents ];
}
