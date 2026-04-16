#!/usr/bin/env bash
set -euo pipefail

TEST_ID="38208"
TEST_DIR="$HOME/.pathologic.tmp"
BACKUP_FILE="$HOME/.pathologic.backup.$TEST_ID"

# Find where pathologic is installed
if [[ -f "$HOME/bin/pathologic" ]]; then
    PATHOLOGIC_BIN="$HOME/bin/pathologic"
elif [[ -f "$HOME/.local/bin/pathologic" ]]; then
    PATHOLOGIC_BIN="$HOME/.local/bin/pathologic"
else
    echo "Error: pathologic not installed. Run: bash install_pathologic.sh"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass_count=0
fail_count=0

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((pass_count++)) || true; }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((fail_count++)) || true; }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

# Create pathologic function like zshrc does
pathologic() { source "$PATHOLOGIC_BIN" "$@"; }

cleanup() {
    info "Cleaning up..."
    rm -rf "$TEST_DIR"
    # Restore original .pathologic if backup exists, otherwise leave as-is
    if [[ -f "$BACKUP_FILE" ]]; then
        mv "$BACKUP_FILE" "$HOME/.pathologic"
        info "Restored original ~/.pathologic"
    fi
    info "Done"
}

trap cleanup EXIT

setup() {
    info "Setting up test environment..."
    
    # Backup original .pathologic if it exists
    if [[ -f "$HOME/.pathologic" && ! -f "$BACKUP_FILE" ]]; then
        cp "$HOME/.pathologic" "$BACKUP_FILE"
        info "Backed up original ~/.pathologic"
    fi
    
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/"{alpha,beta,gamma,delta}
    
    for dir in alpha beta gamma delta; do
        printf '#!/bin/bash\necho %s\n' "$dir" > "$TEST_DIR/$dir/identify"
        chmod +x "$TEST_DIR/$dir/identify"
    done
    
    printf '%s\n' "$TEST_DIR/alpha" > "$TEST_DIR/paths-alpha.txt"
    printf '%s\n' "$TEST_DIR/beta" > "$TEST_DIR/paths-beta.txt"
    printf '%s\n' "$TEST_DIR/gamma" > "$TEST_DIR/paths-gamma"
    printf '%s\n' "$TEST_DIR/delta" > "$TEST_DIR/paths-delta.txt"
    
    mkdir -p "$TEST_DIR/pathologic.d"
    cp "$TEST_DIR/paths-alpha.txt" "$TEST_DIR/paths-beta.txt" "$TEST_DIR/paths-gamma" "$TEST_DIR/pathologic.d/"
    
    printf '#!/bin/bash\n' > "$TEST_DIR/pathologic.d/executable.sh"
    chmod +x "$TEST_DIR/pathologic.d/executable.sh"
    
    printf '%s\n%s\n' "$TEST_DIR/alpha" "$TEST_DIR/beta" > "$HOME/.pathologic"
    
    info "Setup complete (using $PATHOLOGIC_BIN)"
}

test_basic_file() {
    info "Test 1: Basic file processing"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    pathologic "$TEST_DIR/paths-alpha.txt" 2>/dev/null || true
    
    if [[ ":$PATH:" == *":$TEST_DIR/alpha:"* ]]; then
        pass "Single file processed"
    else
        fail "Alpha not in PATH"
    fi
}

test_default_pathologic() {
    info "Test 2: Default ~/.pathologic usage (no args)"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    pathologic 2>/dev/null || true
    
    if [[ ":$PATH:" == *":$TEST_DIR/alpha:"* && ":$PATH:" == *":$TEST_DIR/beta:"* ]]; then
        pass "Default ~/.pathologic works"
    else
        fail "Default ~/.pathologic failed"
    fi
}

test_multiple_files() {
    info "Test 3: Multiple files in order"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    pathologic "$TEST_DIR/paths-gamma" "$TEST_DIR/paths-alpha.txt" "$TEST_DIR/paths-beta.txt" 2>/dev/null || true
    
    local order
    order=$(echo "$PATH" | tr ':' '\n' | grep -E 'alpha|beta|gamma' | head -3)
    
    local first second third
    first=$(echo "$order" | head -1)
    second=$(echo "$order" | sed -n '2p')
    third=$(echo "$order" | sed -n '3p')
    
    [[ "$first" == *"gamma"* ]] && pass "First is gamma" || fail "Expected gamma, got $first"
    [[ "$second" == *"alpha"* ]] && pass "Second is alpha" || fail "Expected alpha, got $second"
    [[ "$third" == *"beta"* ]] && pass "Third is beta" || fail "Expected beta, got $third"
}

test_directory_mode() {
    info "Test 4: Directory mode (-d flag)"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    local output
    output=$(pathologic -v -d "$TEST_DIR/pathologic.d" 2>&1) || true
    
    local file_count
    file_count=$(echo "$output" | grep -c "Reading:" || echo "0")
    
    [[ "$file_count" -eq 3 ]] && pass "-d found 3 files" || fail "Expected 3, found $file_count"
}

test_duplicate_skip() {
    info "Test 5: Duplicate file skipping"
    
    bash -c "
        export TEST_DIR='$TEST_DIR'
        export PATH='/usr/local/bin:/usr/bin:/bin'
        pathologic() { source '$PATHOLOGIC_BIN' \"\$@\"; }
        pathologic -v -d \"\$TEST_DIR/pathologic.d\" \"\$TEST_DIR/pathologic.d/paths-alpha.txt\" 2>&1 | grep -q 'Skipping'
    " && pass "Duplicate skipped" || fail "Duplicate not detected"
}

test_silent_mode() {
    info "Test 6: Silent by default"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    local output
    output=$(pathologic "$TEST_DIR/paths-alpha.txt" 2>&1) || true
    
    [[ -z "$output" ]] && pass "Silent mode" || fail "Unexpected output: $output"
}

test_error() {
    info "Test 7: Error handling"
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    local output
    output=$(pathologic /nonexistent 2>&1) || true
    
    echo "$output" | grep -q "Error:" && pass "Error shown" || fail "No error"
}

main() {
    echo "========================================"
    echo "Pathologic Test Suite (ID: $TEST_ID)"
    echo "========================================"
    echo ""
    
    setup
    test_basic_file
    test_default_pathologic
    test_multiple_files
    test_directory_mode
    test_duplicate_skip
    test_silent_mode
    test_error
    
    echo ""
    echo "========================================"
    echo "Results: $pass_count passed, $fail_count failed"
    echo "========================================"
    
    [[ $fail_count -eq 0 ]] && exit 0 || exit 1
}

main "$@"
