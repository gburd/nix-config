{ pkgs, ... }:
let
  taskbook = pkgs.writeShellScriptBin "taskbook" ''
    #!/usr/bin/env bash
    # Markdown-based task management

    TASK_DIR="$HOME/ProtonDrive/Tasks"
    TASK_FILE="$TASK_DIR/tasks.md"
    ARCHIVE_FILE="$TASK_DIR/archive.md"

    mkdir -p "$TASK_DIR"
    [ -f "$TASK_FILE" ] || echo "# Tasks" > "$TASK_FILE"

    case "$1" in
      add|a)
        shift
        echo "- [ ] $* ($(date +%Y-%m-%d))" >> "$TASK_FILE"
        echo "✓ Task added: $*"
        ;;

      list|l)
        grep "^\- \[ \]" "$TASK_FILE" 2>/dev/null | nl || echo "No open tasks"
        ;;

      done|d)
        if [ -z "$2" ]; then
          echo "Usage: taskbook done <number>"
          exit 1
        fi
        sed -i "''${2}s/\- \[ \]/- [x]/" "$TASK_FILE"
        echo "✓ Task $2 marked as done"
        ;;

      archive)
        grep "^\- \[x\]" "$TASK_FILE" >> "$ARCHIVE_FILE" 2>/dev/null
        sed -i '/^\- \[x\]/d' "$TASK_FILE"
        echo "✓ Completed tasks archived"
        ;;

      edit|e)
        ${pkgs.neovim}/bin/nvim "$TASK_FILE"
        ;;

      *)
        cat <<EOF
Usage: taskbook <command> [args]

Commands:
  add  <task>   Add a new task
  list          List open tasks
  done <num>    Mark task as done
  archive       Archive completed tasks
  edit          Edit tasks in nvim

Shortcuts:
  t, ta, tl, td, te  (via shell aliases)
EOF
        ;;
    esac
  '';
in
{
  home.packages = [ taskbook ];

  # Shell aliases for fish
  programs.fish.shellAliases = {
    t = "taskbook";
    ta = "taskbook add";
    tl = "taskbook list";
    td = "taskbook done";
    te = "taskbook edit";
  };

  # Shell aliases for bash
  programs.bash.shellAliases = {
    t = "taskbook";
    ta = "taskbook add";
    tl = "taskbook list";
    td = "taskbook done";
    te = "taskbook edit";
  };

  # Create directory structure
  home.file = {
    "ProtonDrive/Notes/.keep".text = "";
    "ProtonDrive/Notes/work/.keep".text = "";
    "ProtonDrive/Notes/personal/.keep".text = "";
    "ProtonDrive/Notes/projects/.keep".text = "";
    "ProtonDrive/Tasks/.keep".text = "";
  };
}
