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
    $VERBOSE && echo "No standard user bin directory found. Creating $INSTALL_DIR ..."
    mkdir -p "$INSTALL_DIR"
fi

INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# ---- Write the script ----
cat > "$INSTALL_PATH" << 'END_SCRIPT'
#!/usr/bin/env bash
# pathologic - Add directories to PATH from a file or a single argument
#
# Usage (must be sourced to affect your current shell):
#   pathologic                  # Add dirs from ~/.pathologic (default)
#   pathologic <file>           # Add all dirs listed in a file
#   pathologic <directory>      # Add a single directory
#   pathologic -v <file|dir>    # Verbose mode (show messages)
#   pathologic --help
#
# File format: one directory per line; blank lines and '#' comments are ignored.

_pathologic_main() {
    local VERBOSE=false

    # Check for -v flag first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: pathologic [-v|--verbose] [file|directory]"
                echo ""
                echo "  -v, --verbose  Show informational messages"
                echo "  <file>         Text file with one directory per line."
                echo "                 Blank lines and lines starting with '#' are ignored."
                echo "                 Defaults to ~/.pathologic if not provided."
                echo "  <directory>    A single directory to add directly."
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

    local input="${1:-$HOME/.pathologic}"

    if [[ -z "$input" ]]; then
        echo "Usage: pathologic [-v|--verbose] <file|directory>"
        echo ""
        echo "  -v, --verbose  Show informational messages"
        echo "  <file>         Text file with one directory per line."
        echo "                 Blank lines and lines starting with '#' are ignored."
        echo "                 Defaults to ~/.pathologic if not provided."
        echo "  <directory>    A single directory to add directly."
        return 0
    fi
    local added=0
    local skipped=0

    input="${input/#\~/$HOME}"
    input=$(eval echo "$input")

    _pathologic_add_one() {
        local dir="${1/#\~/$HOME}"
        dir=$(eval echo "$dir")

        if [[ ! -d "$dir" ]]; then
            echo "Warning: directory does not exist, skipping: $dir" >&2
            ((skipped++)) || true
            return
        fi

        if [[ ":$PATH:" == *":$dir:"* ]]; then
            $VERBOSE && echo "Already in PATH, skipping: $dir"
            ((skipped++)) || true
            return
        fi

        export PATH="$dir:$PATH"
        $VERBOSE && echo "Added: $dir"
        ((added++)) || true
    }

    if [[ -d "$input" ]]; then
        _pathologic_add_one "$input"
    elif [[ -f "$input" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            _pathologic_add_one "$line"
        done < "$input"
    else
        echo "Error: not a file or directory: $input" >&2
        return 1
    fi

    $VERBOSE && echo ""
    $VERBOSE && echo "Done: $added added, $skipped skipped."
    unset -f _pathologic_add_one
}

_pathologic_main "$@"
unset -f _pathologic_main
END_SCRIPT

chmod +x "$INSTALL_PATH"
$VERBOSE && echo "Installed: $INSTALL_PATH"

# ---- Add shell function to .zshrc (idempotent) ----
MARKER="# added by install_pathologic.sh"

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
    $VERBOSE && echo ".zshrc already contains the pathologic function, skipping."
else
    cat >> "$ZSHRC" <<EOF

$MARKER
pathologic() { source "$INSTALL_PATH" "\$@"; }
EOF
    $VERBOSE && echo "Added 'pathologic' function to $ZSHRC"
fi

# ---- Ensure install dir is on PATH in .zshrc (idempotent) ----
PATH_MARKER="# $INSTALL_DIR on PATH — added by install_pathologic.sh"

if grep -qF "$PATH_MARKER" "$ZSHRC" 2>/dev/null || [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    $VERBOSE && echo "$INSTALL_DIR is already on PATH, skipping."
else
    cat >> "$ZSHRC" <<EOF

$PATH_MARKER
export PATH="$INSTALL_DIR:\$PATH"
EOF
    $VERBOSE && echo "Added $INSTALL_DIR to PATH in $ZSHRC"
fi

$VERBOSE && echo ""
$VERBOSE && echo "All done! Reload your shell or run:  source ~/.zshrc"
$VERBOSE && echo "Then use:  pathologic ~/bin  or  pathologic ~/my_dirs.txt"
