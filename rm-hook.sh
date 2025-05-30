#!/bin/bash

HOOK_FILE="$HOME/.rm-hook"

detect_shell() {
  if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
    SHELL_NAME="zsh"
  elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_NAME="bash"
  else
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_NAME="bash"
  fi
}

detect_shell

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

create_hook_file() {
  cat >"$HOOK_FILE" <<'EOF'
#!/bin/bash
# RM Hook - rm command hook

TRASH_DIR="/tmp/.rm-trash"
mkdir -p "$TRASH_DIR"

rm() {
    case "$1" in
        --real-rm)
            shift
            /bin/rm "$@"
            return $?
            ;;
        --empty-trash)
            /bin/rm -rf "$TRASH_DIR"/*
            echo "Trash emptied"
            return 0
            ;;
        --list-trash)
            if [ -d "$TRASH_DIR" ] && [ "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
                ls -la "$TRASH_DIR"
            else
                echo "Trash is empty"
            fi
            return 0
            ;;
        --help)
            echo "rm-hook - Files backed up to $TRASH_DIR before deletion"
            echo "Usage: rm [any rm options] [files...]"
            echo "Special options:"
            echo "  --real-rm     Skip backup, use rm directly"
            echo "  --list-trash  Show trash contents"
            echo "  --empty-trash Empty the trash"
            echo "  --help        Show this help"
            return 0
            ;;
    esac
    
    for arg in "$@"; do
        # Skip options (anything starting with -)
        if [[ "$arg" != -* ]]; then
            if [ -e "$arg" ] || [ -L "$arg" ]; then
                basename=$(basename "$arg")
                timestamp=$(date +%s)
                counter=0
                trash_name="${basename}_${timestamp}"
                
                while [ -e "$TRASH_DIR/$trash_name" ]; do
                    counter=$((counter + 1))
                    trash_name="${basename}_${timestamp}_${counter}"
                done
                
                if cp -rp "$arg" "$TRASH_DIR/$trash_name" 2>/dev/null; then
                    if [ -d "$arg" ]; then
                        echo "Backed up directory '$arg' (and all contents) to trash"
                    else
                        echo "Backed up '$arg' to trash"
                    fi
                else
                    echo "Warning: Could not backup '$arg' to trash"
                fi
            fi
        fi
    done
    # Call the real rm command to delete the files 
    /bin/rm "$@"
}

export -f rm
EOF
}

install_hook() {
  print_info "Installing RM hook for $SHELL_NAME..."
  create_hook_file
  if ! grep -q "source.*\.rm-hook" "$SHELL_CONFIG" 2>/dev/null; then
    echo "" >>"$SHELL_CONFIG"
    echo "# RM Hook - Safe rm command" >>"$SHELL_CONFIG"
    echo "source \"$HOOK_FILE\" >/dev/null 2>&1" >>"$SHELL_CONFIG"
    print_info "Added hook to $SHELL_CONFIG"
  else
    print_warning "Hook already exists in $SHELL_CONFIG"
  fi

  source "$HOOK_FILE"

  print_info "Installation complete!"
  print_info "Hook file created at: $HOOK_FILE"

  if [ "$SHELL" = "/bin/zsh" ]; then
    print_warning "Restart your terminal or run 'source ~/.zshrc' to activate in new sessions"
  else
    print_warning "Restart your terminal or run 'source ~/.bashrc' to activate in new sessions"
  fi

  echo ""
  print_info "Usage:"
  echo "  rm file.txt           # Backup and delete"
  echo "  rm --real-rm file.txt # Skip backup, delete directly"
  echo "  rm --list-trash       # List trash contents"
  echo "  rm --empty-trash      # Empty trash"
  echo "  rm --help             # Show help"
  echo ""
  echo " 'rm' commands and moves files to /tmp/.rm-trash instead of permanently deleting them."
  echo " "
  print_info " Please add the following line to your bashrc or zshrc file:"
  print_info ' source \"$HOME/.rm-hook\" >/dev/null 2>&1'
  print_info " For bash, run: ==> echo 'source \"$HOME/.rm-hook\" >/dev/null 2>&1' >> ~/.bashrc"
  print_info " For zsh, run:  ==> echo 'source \"$HOME/.rm-hook\" >/dev/null 2>&1' >> ~/.zshrc"
}

uninstall_hook() {
  print_info "Uninstalling RM hook..."
  if [ -f "$HOOK_FILE" ]; then
    rm "$HOOK_FILE"
    print_info "Removed hook file: $HOOK_FILE"
  fi
  if [ -f "$SHELL_CONFIG" ]; then
    cp "$SHELL_CONFIG" "${SHELL_CONFIG}.backup"
    sed -i.bak '/# RM Hook - Safe rm command/d' "$SHELL_CONFIG"
    sed -i.bak '\|source.*\.rm-hook|d' "$SHELL_CONFIG"
    rm "${SHELL_CONFIG}.bak" 2>/dev/null # Remove sed backup file
    print_info "Removed hook from $SHELL_CONFIG"
    print_info "Backup created: ${SHELL_CONFIG}.backup"
  fi
  unset -f rm 2>/dev/null
  print_info "Uninstallation complete!"
  print_warning "Restart your terminal to fully remove the hook"
}

status_hook() {
  echo "rm-hook status:"
  echo "==============="
  echo "Shell: $SHELL_NAME"
  echo "Config: $SHELL_CONFIG"
  echo ""

  if [ -f "$HOOK_FILE" ]; then
    print_info "Hook file exists: $HOOK_FILE"
  else
    print_error "Hook file not found: $HOOK_FILE"
  fi

  if grep -q "source.*\.rm-hook" "$SHELL_CONFIG" 2>/dev/null; then
    print_info "Hook is enabled in $SHELL_CONFIG"
  else
    print_error "Hook not found in $SHELL_CONFIG"
  fi

  if
    rm --help 2>&1 | grep -q "rm-hook"
    >/dev/null 2>&1
  then
    print_info "rm function is currently active"
    echo "Trash directory: /tmp/.rm-trash"
    if [ -d "/tmp/.rm-trash" ]; then
      file_count=$(find /tmp/.rm-trash -type f 2>/dev/null | wc -l)
      echo "Files in trash: $file_count"
    fi
  else
    print_warning "rm function is not active in current session"
  fi
}

case "${1:-}" in
install)
  install_hook
  ;;
uninstall)
  uninstall_hook
  ;;
status)
  status_hook
  ;;
*)
  echo "RM Hook Installer"
  echo "=================="
  echo ""
  echo "Usage: $0 {install|uninstall|status}"
  echo ""
  echo "Commands:"
  echo "  install    Install the rm hook"
  echo "  uninstall  Remove the rm hook"
  echo "  status     Show installation status"
  echo ""
  echo "The hook intercepts 'rm' commands and moves files to /tmp/.rm-trash"
  echo "instead of permanently deleting them."
  echo "Please add the following line to .bashrc or .zshrc files:"
  echo 'source \"$HOME/.rm-hook\" >/dev/null 2>&1'
  echo "For bash, run:"
  echo "echo 'source \"$HOME/.rm-hook\" >/dev/null 2>&1' >> ~/.bashrc"
  echo "For zsh, run:"
  echo "echo 'source \"$HOME/.rm-hook\" >/dev/null 2>&1' >> ~/.zshrc"
  ;;
esac
