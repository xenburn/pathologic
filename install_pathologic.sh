#!/usr/bin/env bash
# install_pathologic.sh
#
# Self-contained: installs pathologic and registers a 'pathologic' shell
# function in ~/.zshrc. No companion file needed.
#
# Usage:
#   bash install_pathologic.sh
#   bash install_pathologic.sh -v  # verbose mode

set -euo pipefail

VERBOSE=false
if [[ "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

SCRIPT_NAME="pathologic"
ZSHRC="$HOME/.zshrc"

CANDIDATE_DIRS=(
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.bin"
)

# ---- Pick an install directory ----
INSTALL_DIR=""
for dir in "${CANDIDATE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        INSTALL_DIR="$dir"
        break
    fi
done

if [[ -z "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    [[ "$VERBOSE" == true ]] && echo "No standard user bin directory found. Creating $INSTALL_DIR ..." || true
    mkdir -p "$INSTALL_DIR"
fi

INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# ---- Write the script ----
cat > "$INSTALL_PATH" << 'END_SCRIPT'
#!/usr/bin/env bash
# pathologic - Add directories to PATH from a file or a single argument
#
# Usage (must be sourced to affect your current shell):
#   pathologic                      # Add dirs from ~/.pathologic (default)
#   pathologic <file>               # Add all dirs listed in a file
#   pathologic <directory>          # Add a single directory
#   pathologic <file1> <file2> ...  # Add from multiple files (in order)
#   pathologic -v <file|dir>        # Verbose mode (show messages)
#   pathologic -d <directory>       # Scan directory for .txt files
#   pathologic --help
#
# File format: one directory per line; blank lines and '#' comments are ignored.

_pathologic_main() {
    local VERBOSE=false
    local DIR_MODE=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--directory)
                DIR_MODE=true
                shift
                ;;
            --help|-h)
                echo "Usage: pathologic [-v|--verbose] [-d|--directory] [file|directory ...]"
                echo ""
                echo "  -v, --verbose    Show informational messages"
                echo "  -d, --directory  Read all .txt and no-extension files from directory"
                echo "  <file>           Text file with one directory per line."
                echo "                   Blank lines and lines starting with '#' are ignored."
                echo "                   Defaults to ~/.pathologic if not provided."
                echo "  <directory>      A single directory to add directly (or with -d: scan for files)"
                echo "  Multiple files/directories can be provided; they are processed in order."
                return 0
                ;;
            -*)
                echo "Error: unknown option: $1" >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    [[ $# -eq 0 ]] && set -- "$HOME/.pathologic"

    local -a DIRS_TO_ADD=()
    local -A SEEN_DIRS=()
    local -A SEEN_FILES=()
    local added_count=0
    local skipped_count=0
    local original_path="$PATH"

    _add_dir() {
        local dir="${1/#\~/$HOME}"
        dir=$(eval echo "$dir")

        if [[ ! -d "$dir" ]]; then
            echo "Warning: directory does not exist, skipping: $dir" >&2
            ((skipped_count++)) || true
            return
        fi

        if [[ -n "${SEEN_DIRS[$dir]:-}" ]]; then
            [[ "$VERBOSE" == true ]] && echo "Already queued, skipping: $dir" || true
            ((skipped_count++)) || true
            return
        fi

        if [[ ":$original_path:" == *":$dir:"* ]]; then
            [[ "$VERBOSE" == true ]] && echo "Already in PATH, skipping: $dir" || true
            ((skipped_count++)) || true
            return
        fi

        DIRS_TO_ADD+=("$dir")
        SEEN_DIRS[$dir]=1
        [[ "$VERBOSE" == true ]] && echo "Queued: $dir" || true
        ((added_count++)) || true
    }

    _process_file() {
        local file="$1"
        local abs_path
        abs_path=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
        
        if [[ -n "${SEEN_FILES[$abs_path]:-}" ]]; then
            [[ "$VERBOSE" == true ]] && echo "Skipping already-processed file: $file" || true
            return
        fi
        SEEN_FILES[$abs_path]=1
        
        [[ "$VERBOSE" == true ]] && echo "Reading: $file" || true
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            _add_dir "$line"
        done < "$file"
    }

    _process_one() {
        local input="${1/#\~/$HOME}"
        input=$(eval echo "$input")

        if [[ "$DIR_MODE" == true && -d "$input" ]]; then
            local found_files=false
            for file in "$input"/*; do
                [[ -e "$file" ]] || continue
                [[ -f "$file" ]] || continue
                [[ -x "$file" ]] && continue
                local basename
                basename=$(basename "$file")
                [[ "$basename" == *.txt || ! "$basename" =~ \. ]] || continue
                
                found_files=true
                _process_file "$file"
            done
            if [[ "$found_files" == false ]]; then
                echo "Error: no .txt or no-extension non-executable files found in: $input" >&2
                return 1
            fi
        elif [[ -d "$input" ]]; then
            _add_dir "$input"
        elif [[ -f "$input" ]]; then
            _process_file "$input"
        else
            echo "Error: not a file or directory: $input" >&2
            return 1
        fi
    }

    # Process all arguments in order
    for input in "$@"; do
        _process_one "$input"
    done

    # Build new PATH with collected directories (in order, prepended)
    if [[ ${#DIRS_TO_ADD[@]} -gt 0 ]]; then
        local new_path=""
        for dir in "${DIRS_TO_ADD[@]}"; do
            if [[ -z "$new_path" ]]; then
                new_path="$dir"
            else
                new_path="$new_path:$dir"
            fi
        done
        export PATH="$new_path:$original_path"
    fi

    [[ "$VERBOSE" == true ]] && echo "" || true
    [[ "$VERBOSE" == true ]] && echo "Done: $added_count queued, $skipped_count skipped." || true
    [[ "$VERBOSE" == true ]] && echo "Final order: ${#DIRS_TO_ADD[@]} new directories prepended to PATH" || true
    unset -f _add_dir _process_one _process_file
    unset SEEN_DIRS SEEN_FILES
}

_pathologic_main "$@"
unset -f _pathologic_main
END_SCRIPT

chmod +x "$INSTALL_PATH"
[[ "$VERBOSE" == true ]] && echo "Installed: $INSTALL_PATH" || true

# ---- Add shell function to .zshrc (idempotent) ----
MARKER="# added by install_pathologic.sh"

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
    [[ "$VERBOSE" == true ]] && echo ".zshrc already contains the pathologic function, skipping." || true
else
    cat >> "$ZSHRC" <<EOF

$MARKER
pathologic() { source "$INSTALL_PATH" "\$@"; }
EOF
    [[ "$VERBOSE" == true ]] && echo "Added 'pathologic' function to $ZSHRC" || true
fi

# ---- Ensure install dir is on PATH in .zshrc (idempotent) ----
PATH_MARKER="# $INSTALL_DIR on PATH — added by install_pathologic.sh"

if grep -qF "$PATH_MARKER" "$ZSHRC" 2>/dev/null || [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    [[ "$VERBOSE" == true ]] && echo "$INSTALL_DIR is already on PATH, skipping." || true
else
    cat >> "$ZSHRC" <<EOF

$PATH_MARKER
export PATH="$INSTALL_DIR:\$PATH"
EOF
    [[ "$VERBOSE" == true ]] && echo "Added $INSTALL_DIR to PATH in $ZSHRC" || true
fi

[[ "$VERBOSE" == true ]] && echo "" || true
[[ "$VERBOSE" == true ]] && echo "All done! Reload your shell or run:  source ~/.zshrc" || true
[[ "$VERBOSE" == true ]] && echo "Then use:  pathologic ~/bin  or  pathologic ~/my_dirs.txt" || true
