# lbackup

A simple, single-file Bash script to archive (`tar.gz`), encrypt (`AES-256` via `gpg`), and restore directories on Linux.

## Requirements

Standard tools pre-installed on almost every Linux distribution:
- `bash`, `tar`, `gzip`, `gpg`

## Installation

Copy the script anywhere in your `$PATH` (or run `./bin/lbackup` directly):

```bash
mkdir -p ~/.local/bin
cp bin/lbackup ~/.local/bin/lbackup
chmod +x ~/.local/bin/lbackup
```

## Usage

### 1. Create a Backup

By default, `-s` backs up `$HOME` and `-o` saves to `~/backups/<name>_YYYYmmdd_HHMMSS.tar.gz.gpg` (automatically excluding `~/backups` so old backups are never re-archived):

```bash
# Dry run: check estimated backup size in GB (after excludes) without backing up
lbackup backup --dry-run

# Back up your home directory ($HOME -> ~/backups)
lbackup backup -p "mySecretPassword"

# Back up a specific folder with verbose file-by-file output (-v)
lbackup backup -s ~/Documents -o ~/backups -p "mySecretPassword" -v

# Or specify an exact output file name (any -o path ending in .gpg or .enc)
lbackup backup -s /etc -o ~/backups/etc-backup.tar.gz.gpg -p "mySecretPassword"
```

- **Password prompt**: If you omit `-p`, the script prompts you interactively (with confirmation on backup) so your password won't appear in your shell history.
- **Progress & Verbose (`-v` / `--verbose`)**: By default, `lbackup` shows a live progress status line in the terminal and total bytes written. Pass `-v` to print every file path as it is processed.

### 2. Ignore Cache & Temp Directories

By default, `lbackup` automatically ignores common cache, temp, and virtual folders (`.cache`, `Cache`, `tmp`, `temp`, `*.tmp`, `*.swp`, `.local/share/Trash`, `node_modules`, `__pycache__`, `.venv`, `lost+found`, `/proc`, `/sys`, `/dev`, `/run`, and any directory containing a `CACHEDIR.TAG` file).

- **Ignore extra directories or patterns via CLI (`-e` / `--exclude`):**
  ```bash
  lbackup backup -s ~ -o ~/backups -p "mySecretPassword" -e "Downloads" -e "*.iso" -e ".steam"
  ```
- **Edit default excludes in the script:**
  Open `bin/lbackup` and edit the `DEFAULT_EXCLUDES` array right at the top of the file.
- **Disable default excludes:**
  ```bash
  lbackup backup -s ~/Documents -o ~/backups -p "mySecretPassword" --no-default-excludes
  ```

### 3. Restore a Backup

Pass the encrypted archive (`-i`), the target directory (`-o`), and the password (`-p`), with optional `-v` for verbose file listing:

```bash
lbackup restore -i ~/backups/user_20261017_153000.tar.gz.gpg -o /tmp/restored -p "mySecretPassword" -v
```

### 4. Manual Decryption (Without `lbackup`)

Archives are standard `gpg` + `tar.gz` files, so you can always restore them manually on any Linux machine:

```bash
mkdir -p /tmp/restored
gpg -d archive.tar.gz.gpg | tar -xzpf - -C /tmp/restored
```

## Running Tests

```bash
bash tests/run_tests.sh
```
