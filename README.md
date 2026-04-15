# pathologic

A small bash utility for adding directories to `PATH` from a plain-text file.

## Setup

Copy the script somewhere convenient and create your paths file:

```bash
cp pathologic.sh ~/bin/pathologic.sh
touch ~/.pathologic
```

Then add it to your shell's startup file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source ~/bin/pathologic.sh
```

## The paths file

By default, `pathologic` reads from `~/.pathologic` — one directory per line. Blank lines and lines beginning with `#` are ignored.

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
source pathologic.sh

# Load from a specific file
source pathologic.sh ~/my_dirs.txt

# Add a single directory directly
source pathologic.sh ~/bin

# Show help
source pathologic.sh --help
```

> **Note:** The script must be *sourced*, not executed. Running it as a subprocess (`bash pathologic.sh` or `./pathologic.sh`) will modify PATH only in that subprocess and have no effect on your current shell.

## Output

For each entry the script reports whether it was added or skipped, and why:

```
Added: /home/tyler/bin
Already in PATH, skipping: /usr/local/bin
Warning: directory does not exist, skipping: /home/tyler/missing

Done: 1 added, 2 skipped.
```
