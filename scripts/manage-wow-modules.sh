#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_REGISTRY="$REPO_ROOT/configs/modules.conf"
SERVER_DIR="${SERVER_DIR:-}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/manage-wow-modules.sh [--server-dir PATH] COMMAND [module...]

Commands:
  list                  List known modules.
  installed             List modules currently present in SERVER_DIR/modules.
  install MODULE...     Install one or more modules into SERVER_DIR/modules.
  import-sql MODULE...  Apply module SQL files to running Docker databases.
  rebuild               Rebuild and restart Docker services.

Known modules are defined in configs/modules.conf.

Examples:
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid list
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid ahbot transmog
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
USAGE
}

log() { printf '\033[0;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-dir) SERVER_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    list|installed|install|import-sql|rebuild)
      COMMAND="$1"
      shift
      break
      ;;
    *) die "Unknown option or command: $1" ;;
  esac
done

COMMAND="${COMMAND:-}"
[[ -n "$COMMAND" ]] || { usage; exit 1; }

if [[ -z "$SERVER_DIR" ]]; then
  for candidate in "$HOME/wow-server-playerbots-hybrid" "$HOME/wow-server-npcbots-hybrid" "$HOME/wow-server-base-hybrid" "$HOME/wow-server-prebuilt-hybrid"; do
    if [[ -f "$candidate/docker-compose.yml" ]]; then
      SERVER_DIR="$candidate"
      break
    fi
  done
fi

require_server_dir() {
  [[ -n "$SERVER_DIR" ]] || die "SERVER_DIR is not set. Use --server-dir PATH."
  [[ -d "$SERVER_DIR" ]] || die "Server directory does not exist: $SERVER_DIR"
  [[ -f "$SERVER_DIR/docker-compose.yml" ]] || die "No docker-compose.yml found in: $SERVER_DIR"
}

read_module_row() {
  local key="$1"
  grep -E "^${key}\\|" "$MODULE_REGISTRY" || true
}

list_modules() {
  printf '%-14s %-24s %-8s %s\n' "KEY" "NAME" "TYPE" "SOURCE"
  grep -vE '^\s*(#|$)' "$MODULE_REGISTRY" | while IFS='|' read -r key name source_type source dest; do
    printf '%-14s %-24s %-8s %s\n' "$key" "$name" "$source_type" "$source"
  done
}

list_installed() {
  require_server_dir
  if [[ ! -d "$SERVER_DIR/modules" ]]; then
    warn "No modules directory exists yet."
    return 0
  fi

  find "$SERVER_DIR/modules" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
}

install_module() {
  require_server_dir
  local key="$1"
  local row
  row="$(read_module_row "$key")"
  [[ -n "$row" ]] || die "Unknown module: $key"

  local name source_type source dest
  IFS='|' read -r _key name source_type source dest <<<"$row"

  mkdir -p "$SERVER_DIR/modules"
  local target="$SERVER_DIR/modules/$dest"

  if [[ -e "$target" ]]; then
    warn "$dest already exists. Updating/replacing it."
    rm -rf "$target"
  fi

  case "$source_type" in
    local)
      log "Copying $name from local repo..."
      cp -R "$REPO_ROOT/$source" "$target"
      ;;
    git)
      log "Cloning $name..."
      git clone --depth 1 "$source" "$target"
      ;;
    *)
      die "Unsupported source type '$source_type' for module '$key'"
      ;;
  esac

  log "Installed $name to $target"
}

find_db_container() {
  local pattern="$1"
  docker ps --format '{{.Names}}' | grep -E "$pattern" | head -1 || true
}

mysql_exec_file() {
  local db_name="$1"
  local sql_file="$2"
  local db_container
  db_container="$(find_db_container 'database|mysql|mariadb|db')"
  [[ -n "$db_container" ]] || die "Could not find a running database container."

  log "Applying $(basename "$sql_file") to $db_name via $db_container"
  docker exec -i "$db_container" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" $db_name" < "$sql_file"
}

import_module_sql() {
  require_server_dir
  local key="$1"
  local row
  row="$(read_module_row "$key")"
  [[ -n "$row" ]] || die "Unknown module: $key"

  local name source_type source dest
  IFS='|' read -r _key name source_type source dest <<<"$row"
  local module_dir="$SERVER_DIR/modules/$dest"
  [[ -d "$module_dir" ]] || die "Module is not installed: $dest"

  local applied=false

  while IFS= read -r -d '' sql_file; do
    case "$sql_file" in
      */sql/world/*|*/sql/db_world/*) mysql_exec_file acore_world "$sql_file"; applied=true ;;
      */sql/characters/*|*/sql/db_characters/*) mysql_exec_file acore_characters "$sql_file"; applied=true ;;
      */sql/auth/*|*/sql/db_auth/*) mysql_exec_file acore_auth "$sql_file"; applied=true ;;
      *) warn "Skipping SQL with unknown target: $sql_file" ;;
    esac
  done < <(find "$module_dir/sql" -type f -name '*.sql' -print0 2>/dev/null || true)

  if [[ "$applied" == false ]]; then
    warn "No SQL files applied for $name."
  fi
}

rebuild_server() {
  require_server_dir
  log "Rebuilding Docker services in $SERVER_DIR"
  cd "$SERVER_DIR"
  docker compose up -d --build
}

case "$COMMAND" in
  list)
    list_modules
    ;;
  installed)
    list_installed
    ;;
  install)
    [[ $# -gt 0 ]] || die "Specify at least one module key."
    for module in "$@"; do install_module "$module"; done
    ;;
  import-sql)
    [[ $# -gt 0 ]] || die "Specify at least one module key."
    for module in "$@"; do import_module_sql "$module"; done
    ;;
  rebuild)
    rebuild_server
    ;;
  *)
    usage
    exit 1
    ;;
esac
