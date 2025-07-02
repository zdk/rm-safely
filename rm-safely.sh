#!/usr/bin/env bash

VERSION="1.0.7"
HOOK_FILE="$HOME/.rm-safely"

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
# rm-safely - rm alias that backups files to a trash directory before deletion

TRASH_DIR="$HOME/.local/share/Trash"
TRASH_FILES="$TRASH_DIR/files"
TRASH_INFO="$TRASH_DIR/info"

mkdir -p "$TRASH_DIR" "$TRASH_FILES" "$TRASH_INFO" 2>/dev/null

rm() {
    case "$1" in
        --rm)
            shift
            /bin/rm "$@"
            return $?
            ;;
        --empty-trash)
            /bin/rm -rf "$TRASH_FILES"/* "$TRASH_INFO"/*
            echo "Trash emptied"
            return 0
            ;;
        --list-trash)
            if [ -d "$TRASH_FILES" ] && [ "$(ls -A "$TRASH_FILES" 2>/dev/null)" ]; then
                echo "List Trash:"
                for file in "$TRASH_FILES"/*; do
                    if [ -e "$file" ]; then
                        basename="$(basename "$file")"
                        info_file="$TRASH_INFO/$basename.trashinfo"
                        if [ -f "$info_file" ]; then
                            original_path=$(grep "^Path=" "$info_file" 2>/dev/null | cut -d= -f2-)
                            deletion_date=$(grep "^DeletionDate=" "$info_file" 2>/dev/null | cut -d= -f2-)
                            echo "  $basename -> $original_path (deleted: $deletion_date)"
                        else
                            echo "  $basename (no info available)"
                        fi
                    fi
                done
            else
                echo "Trash is empty"
            fi
            return 0
            ;;
        --show-trash-path)
            echo "$TRASH_DIR"
            return 0
            ;;
        --version)
            echo "rm-safely version $VERSION"
            return 0
            ;;
        --help)
            echo "rm-safely - Files backed up to \$HOME/.local/share/Trash/files before deletion"
            echo "Usage: rm [any rm options] [files...]"
            echo "Special options:"
            echo "  --rm              Skip backup, execute real 'rm'"
            echo "  --list-trash      Show trash contents"
            echo "  --empty-trash     Empty the trash"
            echo "  --show-trash-path Display the trash directory path"
            echo "  --version         Show version information"
            echo "  --help            Show this help"
            return 0
            ;;
    esac

    backup_list=""
    failed_list=""
    backup_count=0

    if ! [ -w "$TRASH_FILES" ] || ! [ -w "$TRASH_INFO" ]; then
        echo "ERROR: Cannot write to trash directory: $TRASH_DIR"
        echo "Aborting operation to prevent data loss."
        return 1
    fi

    for arg in "$@"; do
        # Skip option arguments
        if [[ "$arg" == -* ]]; then
            continue
        fi

        # Check if file exists
        if [ ! -e "$arg" ] && [ ! -L "$arg" ]; then
            echo "File '$arg' does not exist"
            continue
        fi

        # Generate unique trash name
        basename=$(basename "$arg")
        timestamp=$(date +%s)
        counter=0
        trash_name="${basename}_${timestamp}"

        while [ -e "$TRASH_FILES/$trash_name" ]; do
            counter=$((counter + 1))
            trash_name="${basename}_${timestamp}_${counter}"
        done

        # Get absolute path of the file
        if [[ "$arg" = /* ]]; then
            absolute_path="$arg"
        else
            absolute_path="$(pwd)/$arg"
        fi

        # Create trash info file
        cat > "$TRASH_INFO/$trash_name.trashinfo" <<'TRASH_EOF'
[Trash Info]
Path=$absolute_path
DeletionDate=$(date -u +%Y-%m-%dT%H:%M:%S)
TRASH_EOF

        # Try to backup the file
        if cp -rp "$arg" "$TRASH_FILES/$trash_name" 2>/dev/null; then
            # Verify backup was successful
            if [ -e "$TRASH_FILES/$trash_name" ]; then
                backup_list="$backup_list|$arg:$trash_name"
                backup_count=$((backup_count + 1))
                if [ -d "$arg" ]; then
                    echo "Backed up directory '$arg' (and all contents) to trash"
                else
                    echo "Backed up '$arg' to trash"
                fi
            else
                echo "ERROR: Backup verification failed for '$arg'"
                /bin/rm -f "$TRASH_INFO/$trash_name.trashinfo"
                failed_list="$failed_list $arg"
            fi
        else
            # Backup failed - determine why and clean up
            if [ ! -r "$arg" ]; then
                echo "ERROR: Cannot read '$arg' - permission denied"
            else
                available_space=$(df "$TRASH_FILES" 2>/dev/null | awk 'NR==2 {print $4}')
                file_size=$(du -s "$arg" 2>/dev/null | awk '{print $1}')
                if [ -n "$file_size" ] && [ -n "$available_space" ] && [ "$file_size" -gt "$available_space" ]; then
                    echo "ERROR: Insufficient disk space to backup '$arg'"
                else
                    echo "ERROR: Failed to backup '$arg' to trash"
                fi
            fi
            # Clean up failed info file
            /bin/rm -f "$TRASH_INFO/$trash_name.trashinfo"
            failed_list="$failed_list $arg"
        fi
    done

    if [ -n "$failed_list" ]; then
        echo ""
        echo "OPERATION ABORTED: Cannot safely delete files due to backup failures:"
        for failed_file in $failed_list; do
            echo "  - $failed_file"
        done
        echo ""
        echo "Your files remain untouched. Please resolve the backup issues and try again."
        echo "Use 'rm --rm [files]' to skip backup and delete directly (DANGEROUS)."

        if [ -n "$backup_list" ]; then
            IFS='|'
            for backup_entry in $backup_list; do
                if [ -n "$backup_entry" ]; then
                    trash_name="${backup_entry#*:}"
                    if [ -e "$TRASH_FILES/$trash_name" ]; then
                        /bin/rm -rf "$TRASH_FILES/$trash_name"
                        /bin/rm -f "$TRASH_INFO/$trash_name.trashinfo"
                    fi
                fi
            done
            unset IFS
        fi

        return 1
    fi

    if [ $backup_count -gt 0 ]; then
        echo "Executing: rm $@"
        /bin/rm "$@"
        local rm_exit_code=$?

        if [ $rm_exit_code -ne 0 ]; then
            echo "Note: Original rm command failed, but backups are preserved in trash."
        fi

        return $rm_exit_code
    else
        /bin/rm "$@"
        return $?
    fi
}

export -f rm
EOF
}

install_hook() {
    print_info "Installing rm-safely hook for $SHELL_NAME..."

    TRASH_DIR="$HOME/.local/share/Trash"
    if [ -d "$TRASH_DIR" ]; then
        print_warning "Trash directory already exists at: $TRASH_DIR"

        DIR_OWNER=$(ls -ld "$TRASH_DIR" 2>/dev/null | awk '{print $3}')
        CURRENT_USER=$(whoami)

        if [ "$DIR_OWNER" != "$CURRENT_USER" ]; then
            print_warning "Trash directory is owned by '$DIR_OWNER', not current user '$CURRENT_USER'"
            print_warning "This may cause permission issues when backing up files"
        fi

        if [ ! -w "$TRASH_DIR" ]; then
            print_error "Trash directory exists but is not writable!"
            print_error "Please fix permissions"
            return 1
        fi
    else
        print_info "Trash directory will be created at: $TRASH_DIR"
    fi

    create_hook_file
    if ! grep -q "source.*\.rm-safely" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >>"$SHELL_CONFIG"
        echo "# rm-safely - Safe rm command" >>"$SHELL_CONFIG"
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
    echo "  rm --rm file.txt      # Skip backup, delete directly"
    echo "  rm --list-trash       # List trash contents"
    echo "  rm --show-trash-path  # Show trash directory path"
    echo "  rm --empty-trash      # Empty trash"
    echo "  rm --help             # Show help"
    echo ""
    echo " 'rm' commands and moves files to ~/.local/share/Trash instead of permanently deleting them."
    echo " "
    print_info " Please add the following line to your bashrc or zshrc file:"
    print_info ' source \"$HOME/.rm-safely\" >/dev/null 2>&1'
    print_info " Or, run the following commands:"
    print_info " For bash, ==> echo 'source \"$HOME/.rm-safely\" >/dev/null 2>&1' >> ~/.bashrc"
    print_info " For zsh,  ==> echo 'source \"$HOME/.rm-safely\" >/dev/null 2>&1' >> ~/.zshrc"
}

uninstall_hook() {
    print_info "Uninstalling rm-safely hook..."
    if [ -f "$HOOK_FILE" ]; then
        rm "$HOOK_FILE"
        print_info "Removed hook file: $HOOK_FILE"
    fi
    if [ -f "$SHELL_CONFIG" ]; then
        cp "$SHELL_CONFIG" "${SHELL_CONFIG}.backup"
        sed -i.bak '/# rm-safely - Safe rm command/d' "$SHELL_CONFIG"
        sed -i.bak '\|source.*\.rm-safely|d' "$SHELL_CONFIG"
        rm "${SHELL_CONFIG}.bak" 2>/dev/null # Remove sed backup file
        print_info "Removed hook from $SHELL_CONFIG"
        print_info "Backup created: ${SHELL_CONFIG}.backup"
    fi
    unset -f rm 2>/dev/null
    print_info "Uninstallation complete!"
    print_warning "Restart your terminal to fully remove the hook"
}

status_hook() {
    echo "rm-safely status:"
    echo "================="
    echo "Shell: $SHELL_NAME"
    echo "Config: $SHELL_CONFIG"
    echo ""

    if [ -f "$HOOK_FILE" ]; then
        print_info "Hook file exists: $HOOK_FILE"
    else
        print_error "Hook file not found: $HOOK_FILE"
    fi

    if grep -q "source.*\.rm-safely" "$SHELL_CONFIG" 2>/dev/null; then
        print_info "Hook is enabled in $SHELL_CONFIG"
    else
        print_error "Hook not found in $SHELL_CONFIG"
    fi

    if
        rm --help 2>&1 | grep -q "rm-safely"
        >/dev/null 2>&1
    then
        print_info "rm function is currently active"
        echo "Trash directory: $HOME/.local/share/Trash"
        if [ -d "$HOME/.local/share/Trash/files" ]; then
            file_count=$(find "$HOME/.local/share/Trash/files" -type f 2>/dev/null | wc -l)
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
version)
    echo "rm-safely version $VERSION"
    ;;
*)
    echo "rm-safely Installer"
    echo "==================="
    echo ""
    echo "Usage: $0 {install|uninstall|status|version}"
    echo ""
    echo "Commands:"
    echo "  install    Install the rm-safely hook"
    echo "  uninstall  Remove the rm-safely hook"
    echo "  status     Show installation status"
    echo "  version    Show version information"
    echo ""
    echo "The hook intercepts 'rm' commands and moves files to ~/.local/share/Trash"
    echo "instead of permanently deleting them."
    echo "Please add the following line to .bashrc or .zshrc files:"
    echo 'source \"$HOME/.rm-safely\" >/dev/null 2>&1'
    echo "For bash, run:"
    echo "echo 'source \"$HOME/.rm-safely\" >/dev/null 2>&1' >> ~/.bashrc"
    echo "For zsh, run:"
    echo "echo 'source \"$HOME/.rm-safely\" >/dev/null 2>&1' >> ~/.zshrc"
    ;;
esac
