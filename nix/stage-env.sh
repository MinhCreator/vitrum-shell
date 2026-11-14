# shellcheck shell=bash
# Sourced by the Nix builds (nix/*.nix) that need a file the installer writes:
# the session wrapper, the launchers, the polkit rules, the SDDM and Plymouth
# themes. They run the installer's own stage functions against a throwaway
# home and a throwaway root, and the package takes the files from there, so
# what such a file says is written in one place, lib/stages.
#
#   VITRUM_DIR        the source tree (set by the caller)
#   VITRUM_NIX_ROOT   where the root-owned files land (set by the caller)
#
# After this, a caller sources the stages it needs and calls their functions.
set -euo pipefail

: "${VITRUM_DIR:?}" "${VITRUM_NIX_ROOT:?}"
export HOME="$TMPDIR/vitrum-home"
mkdir -p "$HOME" "$VITRUM_NIX_ROOT"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME VITRUM_LOG VITRUM_TEST
export NO_COLOR=1 DRY_RUN=0 ASSUME_YES=1 VITRUM_DEVICE_LOCALE=en_US.UTF-8
export USER=vitrum-nix-user BUILD_DIR="$TMPDIR/vitrum-build"

# shellcheck source=lib/common.sh
source "$VITRUM_DIR/lib/common.sh"

# The stages' own name for another root. lib/common.sh drops it from the
# environment outside the tests, so it is set here, after.
VITRUM_SYSROOT="$VITRUM_NIX_ROOT"

# Root is this build: sudo runs the command as it is, and a file written as
# root goes under VITRUM_NIX_ROOT (the stages that know of VITRUM_SYSROOT put
# it there themselves; the others name a path from /). A path a caller already
# pointed into its output or the build's own folder stays where it is.
sudo() {
  while [[ "${1:-}" == -* ]]; do shift; done
  "$@"
}
sudo_refresh() { :; }
sudo_keepalive() { :; }
sudo_write() {
  local dest="$1" mode="${2:-0644}" content
  content="$(cat)"
  case "$dest" in
    "$VITRUM_NIX_ROOT"/*|"${out:-/nonexistent}"/*|"$TMPDIR"/*) ;;
    *) dest="$VITRUM_NIX_ROOT$dest" ;;
  esac
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" > "$dest"
  chmod "$mode" "$dest"
}

# need_file <path>… — the build stops when a stage no longer writes a file the
# package is made of, rather than ship without it.
need_file() {
  local f
  for f in "$@"; do
    [[ -s "$f" ]] || { echo "vitrum (nix): the stage did not write $f" >&2; exit 1; }
  done
}

# replace_in <file> <from> <to> — a literal replacement that must happen: a
# stage whose text moved on fails the build here, not at somebody's login.
replace_in() {
  local file="$1" from="$2" to="$3" text
  text="$(cat "$file")"
  [[ "$text" == *"$from"* ]] || { echo "vitrum (nix): $file no longer has: $from" >&2; exit 1; }
  printf '%s\n' "${text//"$from"/"$to"}" > "$file"
}
