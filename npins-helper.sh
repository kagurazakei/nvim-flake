#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NPINS_DIR="${NPINS_DIR:-./npins}"
SOURCES_FILE="$NPINS_DIR/sources.json"
BACKUP_DIR="$NPINS_DIR/backups"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

backup_sources() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/sources-$(date +%Y%m%d-%H%M%S).json"
    cp "$SOURCES_FILE" "$backup_file"
    log_info "Backup created: $backup_file"
}

check_npins_init() {
    if [ ! -f "$SOURCES_FILE" ]; then
        log_error "npins not initialized in $NPINS_DIR"
        log_info "Run 'npins init' first"
        exit 1
    fi
}

# Add multiple entries
add_entries() {
    local entries=()
    local entry_file=""

    # Check if entries are provided via file or arguments
    if [ -f "$1" ]; then
        entry_file="$1"
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue
            entries+=("$line")
        done < "$entry_file"
        log_info "Reading entries from $entry_file"
    else
        entries=("$@")
    fi

    if [ ${#entries[@]} -eq 0 ]; then
        log_error "No entries provided"
        echo "Usage: add <type> <owner> <repo> [name] [rev]"
        echo "       add-file <file>"
        return 1
    fi

    backup_sources

    for entry in "${entries[@]}"; do
        # Parse entry
        IFS=' ' read -r type owner repo name rev <<< "$entry"

        if [ -z "$type" ] || [ -z "$owner" ] || [ -z "$repo" ]; then
            log_warning "Invalid entry format: $entry"
            continue
        fi

        # Set default name if not provided
        if [ -z "$name" ]; then
            name="$repo"
        fi

        # Set default rev if not provided
        if [ -z "$rev" ]; then
            rev="main"
        fi

        log_info "Adding $type/$owner/$repo as '$name'"

        if [ "$type" = "github" ]; then
            npins add github "$owner" "$repo" -n "$name" -b "$rev"
        elif [ "$type" = "git" ]; then
            npins add git "https://github.com/$owner/$repo.git" -n "$name" -b "$rev"
        else
            log_error "Unknown type: $type"
            continue
        fi

        log_success "Added $name"
    done
}

# Remove multiple entries
remove_entries() {
    local entries=()

    # Collect entries from arguments or stdin
    if [ $# -gt 0 ]; then
        entries=("$@")
    else
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            entries+=("$line")
        done
    fi

    if [ ${#entries[@]} -eq 0 ]; then
        log_error "No entries provided for removal"
        echo "Usage: remove <name1> [name2] ..."
        echo "       remove-file <file>"
        return 1
    fi

    backup_sources

    for entry in "${entries[@]}"; do
        if npins list | grep -q "^$entry$"; then
            log_info "Removing $entry"
            npins remove "$entry"
            log_success "Removed $entry"
        else
            log_warning "Entry '$entry' not found"
        fi
    done
}

# Update multiple entries
update_entries() {
    local entries=()

    if [ $# -gt 0 ]; then
        entries=("$@")
    else
        # Update all entries
        entries=$(npins list)
    fi

    if [ ${#entries[@]} -eq 0 ]; then
        log_warning "No entries to update"
        return
    fi

    backup_sources

    for entry in "${entries[@]}"; do
        log_info "Updating $entry"
        npins update "$entry"
        log_success "Updated $entry"
    done
}

# List entries with details
list_entries() {
    local format="${1:-simple}"

    case "$format" in
        json)
            if command -v jq &> /dev/null; then
                jq '.' "$SOURCES_FILE"
            else
                cat "$SOURCES_FILE"
            fi
            ;;
        table)
            if command -v jq &> /dev/null; then
                echo -e "${BLUE}Name\tType\tOwner/URL\tRepository/Path${NC}"
                echo "--------------------------------------------------------"
                jq -r '.sources | to_entries[] | "\(.key)\t\(.value.type)\t\(.value.owner // .value.url)\t\(.value.repository // "")"' "$SOURCES_FILE" | \
                while IFS=$'\t' read -r name type owner repo; do
                    printf "%-20s %-10s %-30s %-30s\n" "$name" "$type" "$owner" "$repo"
                done
            else
                npins list
            fi
            ;;
        simple|*)
            npins list
            ;;
    esac
}

# Import from file (bulk add)
import_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Importing entries from $file"
    add_entries "$file"
}

# Export to file
export_file() {
    local file="${1:-npins-export.txt}"

    backup_sources

    jq -r '.sources | to_entries[] | "\(.value.type) \(.value.owner // "") \(.value.repository // "") \(.key) \(.value.revision)"' "$SOURCES_FILE" > "$file"

    log_success "Exported to $file"
}

# Show diff between current and backup
show_diff() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        echo "Available backups:"
        ls -1 "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
        return 1
    fi

    if command -v jq &> /dev/null && command -v diff &> /dev/null; then
        diff -u <(jq -S '.' "$backup_file") <(jq -S '.' "$SOURCES_FILE")
    else
        diff "$backup_file" "$SOURCES_FILE"
    fi
}

# Interactive mode
interactive_mode() {
    echo -e "${GREEN}NPins Interactive Helper${NC}"
    echo "=========================="
    echo

    while true; do
        echo -e "${BLUE}Commands:${NC}"
        echo "  a - Add entries"
        echo "  r - Remove entries"
        echo "  u - Update entries"
        echo "  l - List entries"
        echo "  i - Import from file"
        echo "  e - Export to file"
        echo "  d - Show diff"
        echo "  b - Backup"
        echo "  q - Quit"
        echo
        read -p "Choice: " choice

        case "$choice" in
            a|add)
                echo "Enter entries (format: type owner repo [name] [rev])"
                echo "Type 'done' when finished:"
                entries=()
                while true; do
                    read -p "> " entry
                    [ "$entry" = "done" ] && break
                    [ -n "$entry" ] && entries+=("$entry")
                done
                add_entries "${entries[@]}"
                ;;
            r|remove)
                list_entries simple
                echo "Enter names to remove (space separated):"
                read -p "> " -a to_remove
                remove_entries "${to_remove[@]}"
                ;;
            u|update)
                list_entries simple
                echo "Enter names to update (space separated, empty for all):"
                read -p "> " -a to_update
                if [ ${#to_update[@]} -eq 0 ]; then
                    update_entries
                else
                    update_entries "${to_update[@]}"
                fi
                ;;
            l|list)
                echo -e "\nSelect format:"
                echo "  1 - Simple list"
                echo "  2 - Table format"
                echo "  3 - JSON format"
                read -p "Choice: " fmt_choice
                case "$fmt_choice" in
                    2) list_entries table ;;
                    3) list_entries json ;;
                    *) list_entries simple ;;
                esac
                ;;
            i|import)
                echo "Enter file path to import:"
                read -p "> " import_file_path
                import_file "$import_file_path"
                ;;
            e|export)
                echo "Enter export file path (default: npins-export.txt):"
                read -p "> " export_file_path
                export_file "${export_file_path:-npins-export.txt}"
                ;;
            d|diff)
                echo "Enter backup file to compare (empty to list backups):"
                read -p "> " backup_choice
                if [ -z "$backup_choice" ]; then
                    echo "Available backups:"
                    ls -1 "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
                else
                    show_diff "$BACKUP_DIR/$backup_choice"
                fi
                ;;
            b|backup)
                backup_sources
                log_success "Manual backup created"
                ;;
            q|quit)
                log_info "Exiting"
                break
                ;;
            *)
                log_warning "Unknown command: $choice"
                ;;
        esac
        echo
    done
}

# Main script
main() {
    check_npins_init

    case "${1:-}" in
        add)
            shift
            add_entries "$@"
            ;;
        add-file)
            shift
            import_file "$1"
            ;;
        remove)
            shift
            remove_entries "$@"
            ;;
        remove-file)
            shift
            while IFS= read -r line; do
                remove_entries "$line"
            done < "$1"
            ;;
        update)
            shift
            update_entries "$@"
            ;;
        list)
            shift
            list_entries "${1:-simple}"
            ;;
        import)
            shift
            import_file "$1"
            ;;
        export)
            shift
            export_file "$1"
            ;;
        diff)
            shift
            show_diff "$1"
            ;;
        backup)
            backup_sources
            ;;
        interactive|i)
            interactive_mode
            ;;
        help|--help|-h)
            echo "NPins Helper Script"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  add <type> <owner> <repo> [name] [rev] ...   Add multiple entries"
            echo "  add-file <file>                               Add entries from file"
            echo "  remove <name1> [name2] ...                    Remove multiple entries"
            echo "  remove-file <file>                            Remove entries from file"
            echo "  update [name1] [name2] ...                    Update entries (all if empty)"
            echo "  list [simple|table|json]                      List entries"
            echo "  import <file>                                 Import entries from file"
            echo "  export [file]                                 Export entries to file"
            echo "  diff <backup-file>                            Show diff with backup"
            echo "  backup                                        Create manual backup"
            echo "  interactive|i                                 Interactive mode"
            echo ""
            echo "Examples:"
            echo "  $0 add github nixos nixpkgs nixpkgs-unstable main"
            echo "  $0 add-file entries.txt"
            echo "  $0 remove neovim-nightly lazy-nvim"
            echo "  $0 update nixpkgs nvim-flake"
            echo "  $0 list table"
            echo "  $0 interactive"
            echo ""
            echo "File format for add-file/import:"
            echo "  # Comments are ignored"
            echo "  github nixos nixpkgs nixpkgs-unstable main"
            echo "  github kagurazakei nvim-flake nvim-flake master"
            echo "  github nix-community neovim-nightly-overlay"
            ;;
        *)
            if [ -z "${1:-}" ]; then
                interactive_mode
            else
                log_error "Unknown command: $1"
                echo "Run '$0 help' for usage"
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@"
