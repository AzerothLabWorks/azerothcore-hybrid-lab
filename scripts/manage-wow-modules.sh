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
  apply-core-patches    Apply Hybrid Lab AzerothCore core patches.
  setup-ahbot           Create/update AHBot account, owner character, and config.
  setup-hybrid          Install Hybrid config and normalize trainer NPC fields.
  setup-profession-master
                         Install Profession Master config and create trainer NPC.
  setup-startup-qol    Install Startup QoL config.
  rebuild               Rebuild and restart Docker services.

Known modules are defined in configs/modules.conf.

Examples:
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid list
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid ahbot transmog
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol
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
    list|installed|install|import-sql|apply-core-patches|setup-ahbot|setup-hybrid|setup-profession-master|setup-startup-qol|rebuild)
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

mysql_query() {
  local db_name="$1"
  local sql="$2"
  local db_container
  db_container="$(find_db_container 'database|mysql|mariadb|db')"
  [[ -n "$db_container" ]] || die "Could not find a running database container."

  docker exec -i "$db_container" sh -lc "mysql -N -B -uroot -p\"\$MYSQL_ROOT_PASSWORD\" $db_name" <<<"$sql"
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

find_ahbot_config() {
  local candidates=(
    "$SERVER_DIR/env/dist/etc/modules/mod_ahbot.conf"
    "$SERVER_DIR/env/dist/etc/mod_ahbot.conf"
    "$SERVER_DIR/conf/modules/mod_ahbot.conf"
    "$SERVER_DIR/conf/mod_ahbot.conf"
    "$SERVER_DIR/modules/mod-ah-bot/conf/mod_ahbot.conf"
    "$SERVER_DIR/modules/mod-ah-bot/conf/mod_ahbot.conf.dist"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  find "$SERVER_DIR" -path '*/mod-ah-bot/*' -name 'mod_ahbot.conf*' -type f 2>/dev/null | head -1
}

ensure_runtime_ahbot_config() {
  local source_file="$1"
  local etc_dir="$SERVER_DIR/env/dist/etc/modules"
  local runtime_file="$etc_dir/mod_ahbot.conf"

  mkdir -p "$etc_dir"
  if [[ ! -f "$runtime_file" ]]; then
    cp "$source_file" "$runtime_file"
  fi

  printf '%s\n' "$runtime_file"
}

set_conf_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    printf '\n%s = %s\n' "$key" "$value" >> "$file"
  fi
}

setup_ahbot() {
  require_server_dir

  local account_name="${AHBOT_ACCOUNT:-ahbot}"
  local character_name="${AHBOT_CHARACTER:-Auctioneer}"

  if [[ -t 0 ]]; then
    read -r -p "AHBot account name [$account_name]: " input
    account_name="${input:-$account_name}"
    read -r -p "AHBot character name [$character_name]: " input
    character_name="${input:-$character_name}"
  fi

  account_name="$(tr '[:lower:]' '[:upper:]' <<<"$account_name")"

  [[ "$account_name" =~ ^[A-Z0-9_]{3,32}$ ]] || die "AHBot account name must be 3-32 letters/numbers/underscores."
  [[ "$character_name" =~ ^[A-Za-z]{2,12}$ ]] || die "AHBot character name must be 2-12 letters."

  local ahbot_dir="$SERVER_DIR/modules/mod-ah-bot"
  [[ -d "$ahbot_dir" ]] || die "mod-ah-bot is not installed. Run: $0 --server-dir \"$SERVER_DIR\" install ahbot"

  log "Creating or reusing AHBot account '$account_name'..."
  mysql_query acore_auth "
INSERT INTO account (username, salt, verifier, email, reg_mail, expansion, locked)
SELECT '${account_name}', UNHEX(REPEAT('00', 32)), UNHEX(REPEAT('00', 32)), '', '', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM account WHERE username = '${account_name}');
"

  local account_id
  account_id="$(mysql_query acore_auth "SELECT id FROM account WHERE username = '${account_name}' LIMIT 1;" | tr -d '\r')"
  [[ -n "$account_id" ]] || die "Could not resolve AHBot account ID."

  log "Creating or reusing AHBot owner character '$character_name'..."
  mysql_query acore_characters "
SET @account_id := ${account_id};
SET @char_name := '${character_name}';
SET @next_guid := (SELECT COALESCE(MAX(guid), 0) + 1 FROM characters);

INSERT INTO characters (
  guid, account, name, race, class, gender, level, xp, money,
  skin, face, hairStyle, hairColor, facialStyle,
  bankSlots, restState, playerFlags,
  position_x, position_y, position_z, map,
  instance_id, instance_mode_mask, orientation,
  taximask, online, cinematic, totaltime, leveltime, logout_time,
  is_logout_resting, rest_bonus, resettalents_cost, resettalents_time,
  trans_x, trans_y, trans_z, trans_o, transguid,
  extra_flags, stable_slots, at_login, zone, death_expire_time,
  taxi_path, arenaPoints, totalHonorPoints, todayHonorPoints, yesterdayHonorPoints,
  totalKills, todayKills, yesterdayKills, chosenTitle, knownCurrencies,
  watchedFaction, drunk, health, power1, power2, power3, power4, power5, power6, power7,
  latency, talentGroupsCount, activeTalentGroup,
  exploredZones, equipmentCache, ammoId, knownTitles, actionBars, grantableLevels,
  \`order\`, deleteInfos_Account, deleteInfos_Name, deleteDate, innTriggerId, extraBonusTalentCount
)
SELECT
  @next_guid, @account_id, @char_name, 1, 1, 0, 1, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 0,
  -8949.95, -132.493, 83.5312, 0,
  0, 0, 0,
  '', 0, 1, 0, 0, UNIX_TIMESTAMP(),
  0, 0, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 0, 12, 0,
  '', 0, 0, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 100, 0, 0, 0, 0, 0, 0, 0,
  0, 1, 0,
  '', '', 0, '', 0, 0,
  NULL, NULL, NULL, NULL, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM characters WHERE name = @char_name);
"

  local character_guid
  character_guid="$(mysql_query acore_characters "SELECT guid FROM characters WHERE name = '${character_name}' LIMIT 1;" | tr -d '\r')"
  [[ -n "$character_guid" ]] || die "Could not resolve AHBot character GUID."

  local config_file
  config_file="$(find_ahbot_config)"
  [[ -n "$config_file" ]] || die "Could not find mod_ahbot.conf or mod_ahbot.conf.dist under $SERVER_DIR."

  if [[ "$config_file" == *.dist ]]; then
    local target_file="${config_file%.dist}"
    cp "$config_file" "$target_file"
    config_file="$target_file"
  fi

  log "Updating AHBot config: $config_file"
  for target_config in "$config_file" $(ensure_runtime_ahbot_config "$config_file"); do
    [[ -n "$target_config" ]] || continue
    set_conf_value "$target_config" "AuctionHouseBot.EnableSeller" "1"
    set_conf_value "$target_config" "AuctionHouseBot.EnableBuyer" "1"
    set_conf_value "$target_config" "AuctionHouseBot.Account" "$account_id"
    set_conf_value "$target_config" "AuctionHouseBot.GUID" "$character_guid"
    log "Configured $target_config"
  done

  log "AHBot setup complete."
  log "Account '${account_name}' id: $account_id"
  log "Character '${character_name}' guid: $character_guid"
  log "Restart ac-worldserver after setup: cd \"$SERVER_DIR\" && docker compose restart ac-worldserver"
}

setup_hybrid() {
  require_server_dir

  local module_dir="$SERVER_DIR/modules/mod-hybrid-talent-system"
  [[ -d "$module_dir" ]] || die "mod-hybrid-talent-system is not installed. Run: $0 --server-dir \"$SERVER_DIR\" install hybrid"

  local source_conf="$module_dir/conf/mod_hybrid_talent_system.conf.dist"
  [[ -f "$source_conf" ]] || die "Could not find $source_conf"

  local etc_modules_dir="$SERVER_DIR/env/dist/etc/modules"
  mkdir -p "$etc_modules_dir"
  cp "$source_conf" "$etc_modules_dir/mod_hybrid_talent_system.conf"
  log "Installed Hybrid config to $etc_modules_dir/mod_hybrid_talent_system.conf"

  log "Ensuring Hybrid SQL has been imported..."
  import_module_sql hybrid

  log "Normalizing Hybrid trainer creature_template entry 190010..."
  mysql_query acore_world "
UPDATE creature_template
SET
  npcflag = 1,
  gossip_menu_id = 0,
  faction = 35,
  \`rank\` = 0,
  unit_flags = 0,
  unit_flags2 = 0,
  dynamicflags = 0,
  type_flags = 0,
  flags_extra = 0,
  AIName = '',
  ScriptName = 'npc_hybrid_talent_master'
WHERE entry = 190010;
"

  local script_name
  script_name="$(mysql_query acore_world "SELECT ScriptName FROM creature_template WHERE entry = 190010;" | tr -d '\r')"
  [[ "$script_name" == "npc_hybrid_talent_master" ]] || die "Hybrid trainer entry 190010 was not found or could not be updated."

  log "Hybrid setup complete."
  log "Restart ac-worldserver, then delete and respawn the trainer if it was already spawned."
}

setup_profession_master() {
  require_server_dir

  local module_dir="$SERVER_DIR/modules/mod-profession-master"
  [[ -d "$module_dir" ]] || die "mod-profession-master is not installed. Run: $0 --server-dir \"$SERVER_DIR\" install professionmaster"

  local source_conf="$module_dir/conf/mod_profession_master.conf.dist"
  [[ -f "$source_conf" ]] || die "Could not find $source_conf"

  local etc_modules_dir="$SERVER_DIR/env/dist/etc/modules"
  mkdir -p "$etc_modules_dir"
  cp "$source_conf" "$etc_modules_dir/mod_profession_master.conf"
  log "Installed Profession Master config to $etc_modules_dir/mod_profession_master.conf"

  log "Ensuring Profession Master SQL has been imported..."
  import_module_sql professionmaster

  log "Normalizing Profession Master creature_template entry 190020..."
  mysql_query acore_world "
UPDATE creature_template
SET
  name = 'Artisan Nexus-Weaver',
  subname = 'Profession Master',
  npcflag = 1,
  gossip_menu_id = 0,
  faction = 35,
  \`rank\` = 0,
  unit_flags = 0,
  unit_flags2 = 0,
  dynamicflags = 0,
  type_flags = 0,
  flags_extra = 0,
  AIName = '',
  ScriptName = 'npc_profession_master'
WHERE entry = 190020;

DELETE FROM creature_template_model
WHERE CreatureID = 190020;

SET @model_source := COALESCE(
  (SELECT CreatureID FROM creature_template_model WHERE CreatureID = 190010 LIMIT 1),
  (SELECT CreatureID FROM creature_template_model WHERE CreatureID = 4968 LIMIT 1),
  (SELECT CreatureID FROM creature_template_model WHERE CreatureID = 68 LIMIT 1)
);

INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT 190020, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild
FROM creature_template_model
WHERE CreatureID = @model_source;
"

  local script_name
  script_name="$(mysql_query acore_world "SELECT ScriptName FROM creature_template WHERE entry = 190020;" | tr -d '\r')"
  [[ "$script_name" == "npc_profession_master" ]] || die "Profession Master entry 190020 was not found or could not be updated."

  local model_count
  model_count="$(mysql_query acore_world "SELECT COUNT(*) FROM creature_template_model WHERE CreatureID = 190020;" | tr -d '\r')"
  [[ "$model_count" != "0" ]] || die "Profession Master entry 190020 has no creature_template_model rows."

  log "Profession Master setup complete."
  log "Restart ac-worldserver after rebuilding, then spawn the NPC with: .npc add 190020"
}

setup_startup_qol() {
  require_server_dir

  local module_dir="$SERVER_DIR/modules/mod-startup-qol"
  [[ -d "$module_dir" ]] || die "mod-startup-qol is not installed. Run: $0 --server-dir \"$SERVER_DIR\" install startupqol"

  local source_conf="$module_dir/conf/mod_startup_qol.conf.dist"
  [[ -f "$source_conf" ]] || die "Could not find $source_conf"

  local etc_modules_dir="$SERVER_DIR/env/dist/etc/modules"
  mkdir -p "$etc_modules_dir"
  cp "$source_conf" "$etc_modules_dir/mod_startup_qol.conf"
  log "Installed Startup QoL config to $etc_modules_dir/mod_startup_qol.conf"

  local world_conf="$SERVER_DIR/env/dist/etc/worldserver.conf"
  if [[ -f "$world_conf" ]]; then
    set_conf_value "$world_conf" "HybridEquipment.ProficiencyOverride" "1"
    log "Enabled HybridEquipment.ProficiencyOverride in $world_conf"
  fi

  log "Startup QoL setup complete. Rebuild and restart the server, then create a new character to test."
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
      */sql/world/*|*/sql/db_world/*|*/sql/db-world/*) mysql_exec_file acore_world "$sql_file"; applied=true ;;
      */sql/characters/*|*/sql/db_characters/*|*/sql/db-characters/*) mysql_exec_file acore_characters "$sql_file"; applied=true ;;
      */sql/auth/*|*/sql/db_auth/*|*/sql/db-auth/*) mysql_exec_file acore_auth "$sql_file"; applied=true ;;
      *) warn "Skipping SQL with unknown target: $sql_file" ;;
    esac
  done < <(find "$module_dir/sql" -type f -name '*.sql' -print0 2>/dev/null || true)

  while IFS= read -r -d '' sql_file; do
    case "$sql_file" in
      */data/sql/db-world/*) mysql_exec_file acore_world "$sql_file"; applied=true ;;
      */data/sql/db-characters/*) mysql_exec_file acore_characters "$sql_file"; applied=true ;;
      */data/sql/db-auth/*) mysql_exec_file acore_auth "$sql_file"; applied=true ;;
      *) warn "Skipping SQL with unknown target: $sql_file" ;;
    esac
  done < <(find "$module_dir/data/sql" -type f -name '*.sql' -print0 2>/dev/null || true)

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

core_patch_already_present() {
  local patch_name="$1"

  case "$patch_name" in
    0001-combo-points-carry-over.patch)
      [[ -f "$SERVER_DIR/src/server/game/World/WorldConfig.h" ]] || return 1
      grep -q "CONFIG_COMBO_POINTS_CARRY_OVER" "$SERVER_DIR/src/server/game/World/WorldConfig.h" && \
        grep -q "RebindComboPoints" "$SERVER_DIR/src/server/game/Entities/Unit/Unit.h"
      ;;
    0002-hybrid-equipment-proficiency.patch)
      [[ -f "$SERVER_DIR/src/server/game/World/WorldConfig.h" ]] || return 1
      grep -q "CONFIG_HYBRID_EQUIPMENT_PROFICIENCY" "$SERVER_DIR/src/server/game/World/WorldConfig.h" && \
        grep -q "CanUseHybridEquipmentProficiency" "$SERVER_DIR/src/server/game/Entities/Player/PlayerStorage.cpp"
      ;;
    0003-hybrid-equipment-skill-persistence.patch)
      [[ -f "$SERVER_DIR/src/server/game/Entities/Player/Player.cpp" ]] || return 1
      grep -q "isHybridEquipmentSkill" "$SERVER_DIR/src/server/game/Entities/Player/Player.cpp"
      ;;
    0004-hybrid-equipment-proficiency-spells.patch)
      [[ -f "$SERVER_DIR/src/server/game/Entities/Player/Player.cpp" ]] || return 1
      grep -q "CanUseHybridEquipmentSkillLine" "$SERVER_DIR/src/server/game/Entities/Player/Player.cpp"
      ;;
    *)
      return 1
      ;;
  esac
}
apply_core_patches() {
  require_server_dir

  local patch_dir="$REPO_ROOT/patches/core"
  [[ -d "$patch_dir" ]] || die "No core patch directory found: $patch_dir"

  shopt -s nullglob
  local patches=("$patch_dir"/*.patch)
  shopt -u nullglob

  [[ ${#patches[@]} -gt 0 ]] || die "No core patches found in: $patch_dir"

  for patch_file in "${patches[@]}"; do
    if (cd "$SERVER_DIR" && git apply --check --recount "$patch_file"); then
      (cd "$SERVER_DIR" && git apply --recount "$patch_file")
      log "Applied $(basename "$patch_file")."
    elif (cd "$SERVER_DIR" && git apply --reverse --check --recount "$patch_file"); then
      warn "Already applied: $(basename "$patch_file")"
    elif core_patch_already_present "$(basename "$patch_file")"; then
      warn "Already present by marker check: $(basename "$patch_file")"
    else
      die "Could not apply core patch: $patch_file"
    fi
  done
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
  apply-core-patches)
    apply_core_patches
    ;;
  setup-ahbot)
    setup_ahbot
    ;;
  setup-hybrid)
    setup_hybrid
    ;;
  setup-profession-master)
    setup_profession_master
    ;;
  setup-startup-qol)
    setup_startup_qol
    ;;
  rebuild)
    rebuild_server
    ;;
  *)
    usage
    exit 1
    ;;
esac
