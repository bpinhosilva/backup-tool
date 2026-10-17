#!/usr/bin/env bash
# Simple test suite for lbackup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LBACKUP="${SCRIPT_DIR}/../bin/lbackup"

BASE_TMP="${TMPDIR:-/tmp}"
[ -w "$BASE_TMP" ] || BASE_TMP="$SCRIPT_DIR"
TMP_ROOT="$(mktemp -d "${BASE_TMP}/lbackup_test.XXXXXX")"
export GNUPGHOME="${TMP_ROOT}/gnupg"
mkdir -m 700 "$GNUPGHOME"

cleanup() {
  gpgconf --homedir "$GNUPGHOME" --kill all >/dev/null 2>&1 || true
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

# 1. Syntax check
bash -n "$LBACKUP" && pass "Syntax check passed"

# 2. Prepare test files
SRC="${TMP_ROOT}/data"
OUT="${TMP_ROOT}/backups"
RESTORE="${TMP_ROOT}/restored"
mkdir -p "$SRC/.cache" "$SRC/tmp" "$SRC/node_modules" "$SRC/ignore_dir" "$SRC/sub"

echo "hello world" > "$SRC/file.txt"
echo "secret dotfile" > "$SRC/.env"
echo "nested file" > "$SRC/sub/notes.txt"
echo "cached" > "$SRC/.cache/junk"
echo "temp dir" > "$SRC/tmp/junk"
echo "temp file" > "$SRC/test.tmp"
echo "pkg" > "$SRC/node_modules/pkg.js"
echo "custom ignored" > "$SRC/ignore_dir/skip.txt"
echo "log file" > "$SRC/app.log"

# 3. Backup with CLI password and custom -e excludes
"$LBACKUP" backup -s "$SRC" -o "$OUT" -p "testpass123" -e "ignore_dir" -e "*.log"
archives=("$OUT"/data_*.tar.gz.gpg)
ARCHIVE="${archives[0]}"
[ -f "$ARCHIVE" ] && pass "Backup archive created: $(basename "$ARCHIVE")"

# 4. Restore with CLI password
"$LBACKUP" restore -i "$ARCHIVE" -o "$RESTORE" -p "testpass123"

# 5. Verify included files
[ "$(cat "$RESTORE/data/file.txt")" = "hello world" ] || fail "file.txt mismatch"
[ "$(cat "$RESTORE/data/.env")" = "secret dotfile" ] || fail ".env mismatch"
[ "$(cat "$RESTORE/data/sub/notes.txt")" = "nested file" ] || fail "notes.txt mismatch"
pass "Included files restored accurately"

# 6. Verify default and CLI excludes were ignored
[ ! -e "$RESTORE/data/.cache" ]       || fail ".cache should be excluded"
[ ! -e "$RESTORE/data/tmp" ]          || fail "tmp should be excluded"
[ ! -e "$RESTORE/data/test.tmp" ]     || fail "*.tmp should be excluded"
[ ! -e "$RESTORE/data/node_modules" ] || fail "node_modules should be excluded"
[ ! -e "$RESTORE/data/ignore_dir" ]   || fail "CLI -e ignore_dir should be excluded"
[ ! -e "$RESTORE/data/app.log" ]      || fail "CLI -e *.log should be excluded"
pass "Default and CLI exclusions verified"

# 7. Verify --no-default-excludes keeps cache/temp
ARCHIVE_ALL="${OUT}/all.tar.gz.gpg"
RESTORE_ALL="${TMP_ROOT}/restored_all"
"$LBACKUP" backup -s "$SRC" -o "$ARCHIVE_ALL" -p "testpass123" --no-default-excludes
"$LBACKUP" restore -i "$ARCHIVE_ALL" -o "$RESTORE_ALL" -p "testpass123"
[ -f "$RESTORE_ALL/data/.cache/junk" ] && [ -f "$RESTORE_ALL/data/test.tmp" ] || fail "--no-default-excludes failed"
pass "--no-default-excludes verified"

# 8. Verify output archive inside source directory excludes only the archive itself
ARCHIVE_INSIDE="$SRC/sub/inside.tar.gz.gpg"
RESTORE_INSIDE="${TMP_ROOT}/restored_inside"
"$LBACKUP" backup -s "$SRC" -o "$ARCHIVE_INSIDE" -p "testpass123"
"$LBACKUP" restore -i "$ARCHIVE_INSIDE" -o "$RESTORE_INSIDE" -p "testpass123"
[ "$(cat "$RESTORE_INSIDE/data/sub/notes.txt")" = "nested file" ] || fail "Sibling file in sub/ should be preserved"
[ ! -e "$RESTORE_INSIDE/data/sub/inside.tar.gz.gpg" ] || fail "Output archive inside source should be excluded"
pass "Output archive inside source directory handled properly"

# 9. Verify wrong password & missing argument handling
if "$LBACKUP" restore -i "$ARCHIVE" -o "${TMP_ROOT}/bad" -p "wrongpass" >/dev/null 2>&1; then
  fail "Restore with wrong password should fail"
fi
if "$LBACKUP" backup -s >/dev/null 2>&1; then
  fail "Missing option argument should fail"
fi
pass "Wrong password and missing option arguments rejected as expected"

# 10. Verify prompting for password when -p is omitted
ARCHIVE_PROMPT="${OUT}/prompted.tar.gz.gpg"
RESTORE_PROMPT="${TMP_ROOT}/restored_prompt"
echo "promptedpass" | "$LBACKUP" backup -s "$SRC" -o "$ARCHIVE_PROMPT"
echo "promptedpass" | "$LBACKUP" restore -i "$ARCHIVE_PROMPT" -o "$RESTORE_PROMPT"
[ "$(cat "$RESTORE_PROMPT/data/file.txt")" = "hello world" ] || fail "Prompted password backup/restore failed"
pass "Password prompt (when -p omitted) verified"

# 11. Verify --dry-run estimates size in GB without prompting for password
DRY_OUT="$("$LBACKUP" backup -s "$SRC" --dry-run)"
echo "$DRY_OUT" | grep -q "GB" || fail "--dry-run did not output size in GB"
pass "Dry run (--dry-run) size estimation in GB verified"

echo "All tests passed!"
