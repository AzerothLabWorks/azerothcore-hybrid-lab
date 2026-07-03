#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADDON_SOURCE="$REPO_ROOT/modules/mod-hybrid-talent-system/addon/HybridTalentUI"
CLIENT_DIR="${WOW_CLIENT_DIR:-}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/install-hybrid-addon.sh --client-dir PATH

Options:
  --client-dir PATH      WoW 3.3.5a client directory. Accepts WSL paths
                         like /mnt/c/Games/WoW-3.3.5a-HD-Dev or quoted
                         Windows paths like 'C:\Games\WoW-3.3.5a-HD-Dev'.
  -h, --help             Show this help.

Examples:
  ./scripts/install-hybrid-addon.sh --client-dir /mnt/c/Games/WoW-3.3.5a-HD-Dev
  ./scripts/install-hybrid-addon.sh --client-dir 'C:\Games\WoW-3.3.5a-HD-Dev'

You can also set WOW_CLIENT_DIR and omit --client-dir.
USAGE
}

log() { printf '\033[0;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-dir) CLIENT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -n "$CLIENT_DIR" ]] || { usage; exit 1; }
[[ -d "$ADDON_SOURCE" ]] || die "Addon source not found: $ADDON_SOURCE"
[[ -f "$ADDON_SOURCE/HybridTalentUI.toc" ]] || die "Addon source is missing HybridTalentUI.toc: $ADDON_SOURCE"

normalize_path() {
  local path="$1"
  if [[ "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    command -v wslpath >/dev/null 2>&1 || die "Windows path provided but wslpath is unavailable. Use a /mnt/c/... path instead."
    wslpath -u "$path"
  else
    printf '%s\n' "$path"
  fi
}

CLIENT_DIR="$(normalize_path "$CLIENT_DIR")"
CLIENT_DIR="${CLIENT_DIR%/}"
[[ -d "$CLIENT_DIR" ]] || die "WoW client directory does not exist: $CLIENT_DIR"

ADDONS_DIR="$CLIENT_DIR/Interface/AddOns"
TARGET_DIR="$ADDONS_DIR/HybridTalentUI"

mkdir -p "$ADDONS_DIR"
rm -rf "$TARGET_DIR"
cp -R "$ADDON_SOURCE" "$TARGET_DIR"

[[ -f "$TARGET_DIR/HybridTalentUI.toc" ]] || die "Addon copy failed: $TARGET_DIR/HybridTalentUI.toc was not created"

log "Installed HybridTalentUI addon to $TARGET_DIR"
log "Restart WoW or reload the UI, then enable HybridTalentUI on the character select AddOns screen."
