# pathologic

A small bash/shell utility for adding directories to `PATH` from a plain-text file.

## Setup

Run the install script:

```bash
sh install_pathologic.sh
```

Or with verbose output:

```bash
sh install_pathologic.sh -v
```

This installs the `pathologic` command and creates a shell function in your `~/.zshrc` so PATH changes persist in your current shell.

Then reload your shell:

```bash
source ~/.zshrc
```

## The paths file

When called without arguments, pathologic reads from `~/.pathologic` by default. You can also pass any file as an argument to load a different list of paths.

Create your `~/.pathologic` file (or any paths file) with one directory per line. Blank lines and lines beginning with `#` are ignored.

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

# Load from multiple files/directories (processed in order)
pathologic ~/work_paths.txt ~/personal_paths.txt ~/extra/bin

# Load from all .txt and no-extension non-executable files in a directory
pathologic -d ~/config/pathologic.d/

# Show help
pathologic --help
```

**How it works:** pathologic collects directories from all arguments, removes duplicates, then prepends them to PATH **in the order specified**:
- If argument is a **directory** → adds that directory to the list
- If argument is a **file** → reads directories from the file and adds to the list  
- If no arguments → uses `~/.pathologic` by default
- Duplicate directories are automatically skipped
- The final PATH has directories in the same order you specified them

With `-d` flag:
- Scans directory for all `.txt` files and files without extension
- Skips executable files
- Processes each matching file as a path list
- Files are processed in sorted order within the directory

**Duplicate handling:** Files and directories are deduplicated. If you specify the same file twice, or a file appears both explicitly and in a scanned directory, it's only processed once:

```bash
# alpha.txt is processed first, then skipped when scanning the directory
pathologic -d ~/.pathologic.d ~/.pathologic.d/alpha.txt
```

**Note:** Flags must come before file/directory arguments:
```bash
# Correct: flags first
pathologic -v -d ~/config.d/ ~/extra.txt

# Incorrect: flags after files
pathologic ~/extra.txt -d ~/config.d/
```

## Options

- `-v`, `--verbose` — Show informational messages
- `-d`, `--directory` — Scan directory for .txt and no-extension non-executable files  
- `-h`, `--help` — Show usage information

By default, pathologic runs silently and only shows errors.

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
