# pathologic

A small bash utility for adding directories to `PATH` from a plain-text file.

## Setup

Run the install script:

```bash
bash install_pathologic.sh
```

Or with verbose output:

```bash
bash install_pathologic.sh -v
```

This installs the `pathologic` command and creates a shell function in your `~/.zshrc` so PATH changes persist in your current shell.

Then reload your shell:

```bash
source ~/.zshrc
```

## The paths file

Create `~/.pathologic` with one directory per line. Blank lines and lines beginning with `#` are ignored.

```
# My personal tools
~/bin
~/.local/bin

# Work stuff
/opt/company/tools
```

Entries may use `~` and environment variables; both are expanded at runtime.

## Usage

```bash
# Load from ~/.pathologic (default)
pathologic

# Load from a specific file
pathologic ~/my_dirs.txt

# Add a single directory directly
pathologic ~/bin

# Show help
pathologic --help
```

## Options

- `-v`, `--verbose` — Show informational messages (added/skipped directories, etc.)
- `-h`, `--help` — Show usage information

By default, pathologic runs silently and only shows errors (missing directories, invalid paths).

## Output

Without `-v`, only errors are shown:

```
Warning: directory does not exist, skipping: /home/tyler/missing
```

With `-v`, informational messages are shown:

```
Added: /home/tyler/bin
Already in PATH, skipping: /usr/local/bin
Warning: directory does not exist, skipping: /home/tyler/missing

Done: 1 added, 2 skipped.
```

## Environment Variables

Arguments support variable expansion:

```bash
pathologic "$HOME/projects/bin"
pathologic "$PROJECT_DIR/tools"
```
