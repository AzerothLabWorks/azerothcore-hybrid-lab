#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INSTALL_ROOT="${INSTALL_ROOT:-$HOME}"
PROFILE="${PROFILE:-}"
SERVER_DIR="${SERVER_DIR:-}"
WITH_HYBRID="${WITH_HYBRID:-true}"
BUILD_NOW="${BUILD_NOW:-true}"

BASE_REPO="https://github.com/azerothcore/azerothcore-wotlk.git"
ACORE_DOCKER_REPO="https://github.com/azerothcore/acore-docker.git"
PLAYERBOTS_CORE_REPO="https://github.com/mod-playerbots/azerothcore-wotlk.git"
PLAYERBOTS_MODULE_REPO="https://github.com/mod-playerbots/mod-playerbots.git"
NPCBOTS_REPO="https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots.git"

usage() {
  cat <<USAGE
Usage:
  ./scripts/install-wow-hybrid.sh [options]

Options:
  --profile base|base-prebuilt|playerbots|npcbots
  --dir PATH              Install directory. Defaults by profile.
  --no-hybrid             Do not install the Hybrid Talent System module.
  --no-build              Clone and configure only; do not run docker compose build/up.
  -h, --help              Show this help.

Examples:
  ./scripts/install-wow-hybrid.sh --profile base
  ./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots
  ./scripts/install-wow-hybrid.sh --profile npcbots --no-build
USAGE
}

log() { printf '\033[0;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --dir) SERVER_DIR="${2:-}"; shift 2 ;;
    --no-hybrid) WITH_HYBRID=false; shift ;;
    --no-build) BUILD_NOW=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

choose_profile() {
  if [[ -n "$PROFILE" ]]; then
    return
  fi

  echo "Choose server profile:"
  echo "  1) base          AzerothCore source build, supports custom modules"
  echo "  2) base-prebuilt AzerothCore Docker prebuilt images, fastest, no custom C++ modules"
  echo "  3) playerbots    Playerbots fork plus custom modules"
  echo "  4) npcbots       NPCBots fork plus custom modules"
  read -r -p "Profile [1-4]: " choice

  case "$choice" in
    1) PROFILE="base" ;;
    2) PROFILE="base-prebuilt" ;;
    3) PROFILE="playerbots" ;;
    4) PROFILE="npcbots" ;;
    *) die "Invalid profile choice." ;;
  esac
}

default_server_dir() {
  if [[ -n "$SERVER_DIR" ]]; then
    return
  fi

  case "$PROFILE" in
    base) SERVER_DIR="$INSTALL_ROOT/wow-server-base" ;;
    base-prebuilt) SERVER_DIR="$INSTALL_ROOT/wow-server" ;;
    playerbots) SERVER_DIR="$INSTALL_ROOT/wow-server-playerbots" ;;
    npcbots) SERVER_DIR="$INSTALL_ROOT/wow-server-npcbots" ;;
    *) die "Unknown profile: $PROFILE" ;;
  esac
}

check_system() {
  [[ "$(uname -s)" == "Linux" ]] || die "This installer is intended for Linux/WSL2."

  if grep -qi microsoft /proc/version 2>/dev/null; then
    log "WSL2-style Linux environment detected."
  else
    warn "This does not look like WSL2. Continuing because Docker-based Linux installs are still supported."
  fi

  command -v git >/dev/null 2>&1 || die "git is required. Install it with: sudo apt-get install -y git"
  command -v docker >/dev/null 2>&1 || die "docker is required. Follow docs/WSL2_DOCKER.md first."

  if ! docker compose version >/dev/null 2>&1; then
    die "docker compose plugin is required. Install docker-compose-plugin."
  fi

  if ! docker ps >/dev/null 2>&1; then
    die "Docker is not running or your user cannot access it. Try: sudo service docker start && newgrp docker"
  fi
}

confirm_target() {
  log "Profile: $PROFILE"
  log "Install directory: $SERVER_DIR"
  log "Hybrid module: $WITH_HYBRID"
  log "Build/start now: $BUILD_NOW"

  if [[ -d "$SERVER_DIR" ]]; then
    warn "Directory already exists: $SERVER_DIR"
    read -r -p "Remove it and install fresh? Type yes to continue: " answer
    [[ "$answer" == "yes" ]] || die "Install cancelled."
    if [[ -f "$SERVER_DIR/docker-compose.yml" ]]; then
      (cd "$SERVER_DIR" && docker compose down -v) || true
    fi
    rm -rf "$SERVER_DIR"
  fi
}

clone_profile() {
  case "$PROFILE" in
    base)
      log "Cloning AzerothCore source..."
      git clone --depth 1 "$BASE_REPO" "$SERVER_DIR"
      cp "$REPO_ROOT/docker/overrides/base-source.yml" "$SERVER_DIR/docker-compose.override.yml"
      ;;
    base-prebuilt)
      if [[ "$WITH_HYBRID" == "true" ]]; then
        warn "base-prebuilt cannot include custom C++ modules. Disabling hybrid module for this profile."
        WITH_HYBRID=false
      fi
      log "Cloning AzerothCore Docker launcher..."
      git clone --depth 1 "$ACORE_DOCKER_REPO" "$SERVER_DIR"
      cat > "$SERVER_DIR/docker-compose.override.yml" <<'OVERRIDE'
services:
  phpmyadmin:
    ports:
      - "8181:80"
OVERRIDE
      ;;
    playerbots)
      log "Cloning Playerbots core fork..."
      git clone --branch Playerbot "$PLAYERBOTS_CORE_REPO" "$SERVER_DIR"
      log "Cloning mod-playerbots..."
      git clone --depth 1 --branch master "$PLAYERBOTS_MODULE_REPO" "$SERVER_DIR/modules/mod-playerbots"
      cp "$REPO_ROOT/docker/overrides/playerbots.yml" "$SERVER_DIR/docker-compose.override.yml"
      ;;
    npcbots)
      log "Cloning NPCBots core fork..."
      git clone --depth 1 "$NPCBOTS_REPO" "$SERVER_DIR"
      cp "$REPO_ROOT/docker/overrides/npcbots.yml" "$SERVER_DIR/docker-compose.override.yml"
      ;;
    *)
      die "Unknown profile: $PROFILE"
      ;;
  esac
}

install_hybrid_module() {
  [[ "$WITH_HYBRID" == "true" ]] || return 0

  mkdir -p "$SERVER_DIR/modules"
  rm -rf "$SERVER_DIR/modules/mod-hybrid-talent-system"
  cp -R "$REPO_ROOT/modules/mod-hybrid-talent-system" "$SERVER_DIR/modules/mod-hybrid-talent-system"
  log "Installed local Hybrid Talent System module."
}

build_and_start() {
  [[ "$BUILD_NOW" == "true" ]] || return 0

  log "Building and starting Docker services. This can take a long time for source profiles."
  cd "$SERVER_DIR"

  if [[ "$PROFILE" == "base-prebuilt" ]]; then
    docker compose pull
    docker compose up -d --scale phpmyadmin=0
  else
    docker compose up -d --build
  fi
}

main() {
  choose_profile
  default_server_dir
  check_system
  confirm_target
  clone_profile
  install_hybrid_module
  build_and_start

  log "Install flow complete."
  log "Server directory: $SERVER_DIR"
  log "Watch logs with: cd \"$SERVER_DIR\" && docker compose logs -f ac-worldserver"
}

main "$@"
