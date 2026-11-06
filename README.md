# chest

A simple, single-file Bash script to archive (`tar.gz`), encrypt (`AES-256` via `gpg`), and restore directories on Linux.

## Requirements

Standard tools pre-installed on almost every Linux distribution:
- `bash`, `tar`, `gzip`, `gpg`

## Installation

### Option 1: Install with curl

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/bpinhosilva/backup-tool/main/bin/chest -o ~/.local/bin/chest
chmod +x ~/.local/bin/chest
```

Make sure `~/.local/bin` is in your `$PATH`.

### Option 2: Install from a local clone

Copy the script anywhere in your `$PATH` (or run `./bin/chest` directly):

```bash
mkdir -p ~/.local/bin
cp bin/chest ~/.local/bin/chest
chmod +x ~/.local/bin/chest
```

## Usage

### 1. Create a Backup

By default, `-s` backs up `$HOME` and `-o` saves to `~/backups/<name>_YYYYmmdd_HHMMSS.tar.gz.gpg` (automatically excluding `~/backups` so old backups are never re-archived):

```bash
# Dry run: check estimated backup size in GB (after excludes) without backing up
chest backup --dry-run

# Back up your home directory ($HOME -> ~/backups)
chest backup -p "mySecretPassword"

# Back up a specific folder with verbose file-by-file output (-v)
chest backup -s ~/Documents -o ~/backups -p "mySecretPassword" -v

# Or specify an exact output file name (any -o path ending in .gpg or .enc)
chest backup -s /etc -o ~/backups/etc-backup.tar.gz.gpg -p "mySecretPassword"
```

- **Password prompt**: If you omit `-p`, the script prompts you interactively (with confirmation on backup) so your password won't appear in your shell history.
- **Progress & Verbose (`-v` / `--verbose`)**: By default, `chest` shows a live progress status line in the terminal and total bytes written. Pass `-v` to print every file path as it is processed.

### 2. Ignore Cache & Temp Directories

By default, `chest` automatically ignores common cache, temp, and virtual folders (`.cache`, `Cache`, `tmp`, `temp`, `*.tmp`, `*.swp`, `.local/share/Trash`, `node_modules`, `__pycache__`, `.venv`, `lost+found`, `/proc`, `/sys`, `/dev`, `/run`, and any directory containing a `CACHEDIR.TAG` file).

- **Ignore extra directories or patterns via CLI (`-e` / `--exclude`):**
  ```bash
  chest backup -s ~ -o ~/backups -p "mySecretPassword" -e "Downloads" -e "*.iso" -e ".steam"
  ```
- **Edit default excludes in the script:**
  Open `bin/chest` and edit the `DEFAULT_EXCLUDES` array right at the top of the file.
- **Disable default excludes:**
  ```bash
  chest backup -s ~/Documents -o ~/backups -p "mySecretPassword" --no-default-excludes
  ```

### 3. Exclude File (optional)

You can keep your exclusions in a file instead of repeating `-e` flags. The file is **optional**: `chest` looks for `~/.config/chest/excludes` and silently uses the built-in defaults if it doesn't exist. To use a file from anywhere else, pass `-E` / `--exclude-file`:

```bash
mkdir -p ~/.config/chest
cp examples/excludes ~/.config/chest/excludes

chest backup --exclude-file /path/to/my-excludes -p "mySecretPassword"
```

The file has **one pattern per line** (tar `--exclude` syntax); blank lines and lines starting with `#` are ignored:

```text
# ~/.config/chest/excludes
.cache
node_modules
Downloads
*.iso
VirtualBox VMs
```

A sample is provided in [`examples/excludes`](examples/excludes).

| Situation | Result |
|-----------|--------|
| No exclude file | Built-in default excludes are used |
| Exclude file with patterns | Those patterns **replace** the built-in defaults |
| Exclude file exists but has no patterns | No exclusions are used, and a warning is printed |
| `--exclude-file` points to a missing file | Error |

Notes:
- `-e` patterns are always added on top.
- `--no-default-excludes` disables only the built-in defaults; exclude-file and `-e` patterns still apply.
- `--no-exclude-file` ignores the exclude file entirely.
- Directories containing a `CACHEDIR.TAG` file are skipped whenever built-in defaults are enabled, even if the exclude file is empty or custom.

### 4. Restore a Backup

Pass the encrypted archive (`-i`), the target directory (`-o`), and the password (`-p`), with optional `-v` for verbose file listing:

```bash
chest restore -i ~/backups/user_20261017_153000.tar.gz.gpg -o /tmp/restored -p "mySecretPassword" -v
```

### 5. Manual Decryption (Without `chest`)

Archives are standard `gpg` + `tar.gz` files, so you can always restore them manually on any Linux machine:

```bash
mkdir -p /tmp/restored
gpg -d archive.tar.gz.gpg | tar -xzpf - -C /tmp/restored
```

## Running Tests

```bash
bash tests/run_tests.sh
```
