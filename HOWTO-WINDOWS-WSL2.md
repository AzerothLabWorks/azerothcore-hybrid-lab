# How to Install AzerothCore Hybrid Lab on Windows with WSL2

Run a private WoW 3.3.5a AzerothCore server on Windows using Ubuntu under WSL2 and Docker.

This guide is written for this repo:

```text
https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git
```

It supports these server profiles:

- `base`: AzerothCore source build with custom modules.
- `base-prebuilt`: fastest clean AzerothCore Docker install, but no custom C++ modules.
- `playerbots`: Playerbots fork plus custom modules.
- `npcbots`: NPCBots fork plus custom modules.

For the Hybrid Talent System, use `base`, `playerbots`, or `npcbots`. Custom C++ modules require a source build.

## What You Need

- Windows 10 version 2004 or newer, or Windows 11.
- A WoW WotLK 3.3.5a client installed on Windows.
- At least 30 GB free for source builds.
- Internet connection for downloads.
- Time:
  - `base-prebuilt`: usually fastest.
  - `base`: can take a while because it builds from source.
  - `playerbots` or `npcbots`: can take several hours.

## Part 1: Install WSL2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

Restart Windows if prompted.

After restart, Windows may automatically finish installing Ubuntu and open a new Ubuntu terminal. If it does, create your Linux username/password when prompted.

If Ubuntu does not open automatically, install it manually from PowerShell:

```powershell
wsl --list --online
wsl --install -d Ubuntu
```

Then launch Ubuntu from the Start menu, or run:

```powershell
wsl -d Ubuntu
```

Create your Linux username/password when prompted.

If `wsl --install -d Ubuntu` says Ubuntu is already installed, just launch Ubuntu from the Start menu or run `wsl -d Ubuntu`.

Verify WSL2 from PowerShell:

```powershell
wsl --list --verbose
```

You want Ubuntu to show `VERSION 2`.

If it shows version 1:

```powershell
wsl --set-version Ubuntu 2
```

## Part 2: Install Docker in Ubuntu

Open Ubuntu, then run:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git
```

Add Docker's package repository:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker:

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Start Docker and allow your Linux user to use it:

```bash
sudo service docker start
sudo usermod -aG docker "$USER"
newgrp docker
docker ps
```

If `docker ps` shows an empty table, Docker is working.

Make Docker start automatically when Ubuntu opens:

```bash
grep -qxF 'sudo service docker start > /dev/null 2>&1' ~/.bashrc || \
  echo 'sudo service docker start > /dev/null 2>&1' >> ~/.bashrc
```

## Part 3: Choose Stable or Development Source

This project has two common source checkouts:

- **Stable production**: branch `main`, source folder `~/azerothcore-hybrid-lab`, server folder `~/wow-server-playerbots-hybrid`.
- **Development testing**: branch `codex/hybrid-talents-ui`, source folder `~/azerothcore-hybrid-lab-dev`, server folder `~/wow-server-playerbots-hybrid-dev`.

Do not install both branches into the same server folder. Separate directories keep your stable characters, database, build, and Docker stack away from risky development changes.

### Stable Main Branch

Inside Ubuntu:

```bash
cd ~
git clone https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git
cd azerothcore-hybrid-lab
git checkout main
chmod +x scripts/*.sh
```

### Development Branch

Inside Ubuntu:

```bash
cd ~
git clone --branch codex/hybrid-talents-ui https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git azerothcore-hybrid-lab-dev
cd azerothcore-hybrid-lab-dev
chmod +x scripts/*.sh
```

Development branch URL:

```text
https://github.com/AzerothLabWorks/azerothcore-hybrid-lab/tree/codex/hybrid-talents-ui
```

## Part 4: Choose an Install Profile and Server Folder

Recommended profile for this project:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid
```

For the development branch, use the dev server folder:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid-dev
```

Other profile options:

```bash
# AzerothCore source build with Hybrid Talent System
./scripts/install-wow-hybrid.sh --profile base --dir ~/wow-server-base-hybrid

# Fast clean AzerothCore install, no custom C++ modules
./scripts/install-wow-hybrid.sh --profile base-prebuilt --dir ~/wow-server-prebuilt-hybrid

# NPCBots source/fork with Hybrid Talent System
./scripts/install-wow-hybrid.sh --profile npcbots --dir ~/wow-server-npcbots-hybrid
```

Default install folders:

- `base`: `~/wow-server-base-hybrid`
- `base-prebuilt`: `~/wow-server-prebuilt-hybrid`
- `playerbots`: `~/wow-server-playerbots-hybrid`
- `npcbots`: `~/wow-server-npcbots-hybrid`

These `-hybrid` defaults are intentional. They keep this lab separate from any existing AzerothCore, DadsMmoLab, Playerbots, or NPCBots installs you already have. Add `-dev` to the folder name for development branch testing.

To clone/configure only and build later:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid --no-build
```

For dev:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid-dev --no-build
```

## Part 5: Watch the Server Build

Source builds can take a long time.

To watch logs:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose logs -f ac-worldserver
```

For other profiles, change the folder:

```bash
cd ~/wow-server-base-hybrid
cd ~/wow-server-npcbots-hybrid
cd ~/wow-server-prebuilt-hybrid
```

Stop watching logs with `Ctrl+C`. That does not stop the server.

## Part 6: Confirm the Server Is Running

Before adding or testing more modules, confirm the base server path works.

Check container status:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose ps
```

For the Playerbots profile, it is normal to see noisy runtime messages while bots are created and logged in. Messages like these are usually warnings, not build failures:

```text
Random Bots Stats: 122 online
Arena: Player ... already has an arena team
Bot ... failed to join guild ...
```

What matters is that `ac-worldserver` stays `Up` and does not continually exit/restart.

Watch logs:

```bash
docker compose logs -f ac-worldserver
```

Stop watching logs with `Ctrl+C`.

## Part 7: Create Your Game Account

Attach to the worldserver console:

```bash
docker attach $(docker ps --format '{{.Names}}' | grep worldserver | head -1)
```

Create an account:

```text
account create USERNAME PASSWORD PASSWORD
account set gmlevel USERNAME 3 -1
```

Example:

```text
account create ryan mypassword mypassword
account set gmlevel ryan 3 -1
```

Detach safely:

```text
Ctrl+P then Ctrl+Q
```

Do not press `Ctrl+C` while attached to the console, because that can stop the server.

## Part 8: Connect Your Windows WoW Client

Find your WSL2 IP address inside Ubuntu:

```bash
hostname -I | awk '{print $1}'
```

Open your Windows WoW client folder and edit:

```text
Data\enUS\realmlist.wtf
```

Depending on your client, it may be in a different locale folder such as `Data\enGB`.

Set it to:

```text
set realmlist YOUR_WSL2_IP
```

Example:

```text
set realmlist 172.24.144.1
```

Launch `wow.exe` and log in with the account you created.

Do this before continuing. A successful login proves:

- Docker networking is working.
- Authserver is working.
- Worldserver is working.
- The Windows client can reach the WSL2 server.
- Your account and realm configuration are good.

After you can log into the world, continue with module setup.

## Part 9: Start and Stop the Server

Start:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose up -d
```

Stop:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose down
```

Check running containers:

```bash
docker ps
```

Watch logs:

```bash
docker compose logs -f ac-worldserver
```

## Part 10: Install or Update Modules

List known modules:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh list
```

If you are using the development branch, run these commands from `~/azerothcore-hybrid-lab-dev` and change `--server-dir ~/wow-server-playerbots-hybrid` to `--server-dir ~/wow-server-playerbots-hybrid-dev`.

Apply Hybrid Lab core patches, including combo point carry-over:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

Install modules into an existing source server:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid professionmaster startupqol ahbot transmog learnspells
```

Import module SQL after the database containers are running:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid professionmaster ahbot transmog learnspells
```

Tune Playerbots for the Hybrid Lab defaults:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-playerbots
```

This writes `env/dist/etc/modules/playerbots.conf` and sets both `AiPlayerbot.MinRandomBots` and `AiPlayerbot.MaxRandomBots` to `1500`.

Rebuild after adding C++ modules:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

### Startup QoL Starter Package

The `startupqol` module grants brand-new characters a first-login package: all configured riding spells, starter mount spells, four `Gigantique Bags`, `20000` gold, and weapon/armor proficiencies. Existing characters are not changed retroactively. When core patches are applied, those hybrid proficiencies are allowed to persist and can bypass normal weapon/armor class restrictions for hybrid gearing while still respecting item level requirements.

After installing the module, apply core patches and copy its runtime config before rebuilding:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol
```

### Pacific Server Time

The source-build Docker override templates set `TZ=America/Los_Angeles` for `ac-worldserver` so in-game day/night follows Pacific Time instead of UTC.

For an existing server directory, refresh the copied compose override before rebuilding:

```bash
cd ~/azerothcore-hybrid-lab
cp docker/overrides/playerbots.yml ~/wow-server-playerbots-hybrid/docker-compose.override.yml
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

Current known module keys:

- `hybrid`: Hybrid Talent System from this repo.
- `professionmaster`: Profession Master from this repo.
- `startupqol`: Startup QoL first-login starter package from this repo.
- `ahbot`: Auction House Bot.
- `transmog`: Transmog.
- `learnspells`: Auto Learn Spells.

### AHBot Account Note

Installing `ahbot` only adds the module source and SQL. AHBot still needs its config pointed at an account ID and character GUID.

The AHBot config values are:

```ini
AuctionHouseBot.EnableSeller = 1
AuctionHouseBot.EnableBuyer = 1
AuctionHouseBot.Account = ACCOUNT_ID
AuctionHouseBot.GUID = CHARACTER_GUID
```

The AHBot account does not need GM privileges. The AHBot character should not be used as a normal playable character.

Use the helper command after `ahbot` is installed, its SQL is imported, and the database container is running:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot
```

Defaults:

- Account: `AHBOT`
- Character: `Auctioneer`

To run non-interactively:

```bash
AHBOT_ACCOUNT=ahbot AHBOT_CHARACTER=Auctioneer \
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot
```

The helper:

- Creates or reuses a locked dedicated AHBot account.
- Creates or reuses a minimal AHBot owner character.
- Updates `mod_ahbot.conf`.
- Enables both seller and buyer mode.

Then restart worldserver:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose restart ac-worldserver
```

## Part 11: Hybrid Talent System Setup

Run these commands from the same repo branch you used for the install and point them at the matching server directory.

For stable `main`:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

For development `codex/hybrid-talents-ui`:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev install hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev rebuild
```

### Required HybridTalentUI Client Addon

The development branch is addon-first. Install the `HybridTalentUI` client addon after the server module is set up. This is required for the intended spell and talent learning experience; the old Hybrid Talent Master NPC and Hybrid Talent Beacon are retired on this branch.

Recommended user-facing addon source:

```text
https://github.com/AzerothLabWorks/addons/tree/codex/hybrid-talents-ui/HybridTalentUI
```

Download or clone `AzerothLabWorks/addons` from the matching `codex/hybrid-talents-ui` branch, then copy the `HybridTalentUI` folder to:

```text
<WoW client>/Interface/AddOns/HybridTalentUI
```

Example Windows target:

```text
C:\Games\WoW-3.3.5a-HD-Dev\Interface\AddOns\HybridTalentUI
```

If you are already working from this dev repo checkout, the addon source is also available at:

```text
modules/mod-hybrid-talent-system/addon/HybridTalentUI
```

You can install that local copy with the helper command from Ubuntu/WSL2:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/install-hybrid-addon.sh --client-dir 'C:\Games\WoW-3.3.5a-HD-Dev'
```

Or with a WSL path:

```bash
./scripts/install-hybrid-addon.sh --client-dir /mnt/c/Games/WoW-3.3.5a-HD-Dev
```

Use a separate dev client copy, for example `C:\Games\WoW-3.3.5a-HD-Dev`, if you also play on a stable production server. Restart WoW or reload the UI, enable `HybridTalentUI` on the character select AddOns screen, then open it with the Hybrid microbar button or `/hybridui`. Learn spells and talents from the addon UI instead of the old Hybrid Talent Master NPC.

### Retired Hybrid NPC Reference

On the dev branch, `setup-hybrid` imports addon-backed Hybrid SQL and retires the old Hybrid trainer/beacon path. The legacy entries are kept here for reference only:

- Legacy Hybrid trainer: `190010`, `Hybrid Talent Master`
- Legacy Hybrid beacon item: `1915`, `Hybrid Talent Beacon`

The module config is:

```text
modules/mod-hybrid-talent-system/conf/mod_hybrid_talent_system.conf.dist
```

Important defaults on the dev branch:

- Spell unlock level: `10`
- Spell point curve: `1` point every `2` levels starting at level `10`
- Spell max points: `35`
- Talent unlock level: `10`
- Talent point curve: `1` point every `2` levels starting at level `10`
- Talent max points: `35`
- Auto-upgrade purchased hybrid spell ranks on login and level-up: enabled
- Addon-first access through `HybridTalentUI` and `/hybridui`

Recommended first validation path:

```text
1. Use a level 10 or higher character.
2. Open HybridTalentUI from the microbar button or /hybridui.
3. Learn one available hybrid spell.
4. Cast the learned spell.
5. Relog and confirm the spell and action-bar button remain.
6. Learn a talent that grants a spell, such as Arcane Power.
7. Relog and confirm the talent-granted spell and action-bar button remain.
8. Level up and confirm spell/talent points update correctly.
```

## Part 12: Optional Companion Tuning Repositories

These repositories are not required for the Hybrid Talent System, but they provide useful scripts and tuning workflows for a more polished solo/small-group WotLK server:

- [AzerothLabWorks/playerbots-tuner](https://github.com/AzerothLabWorks/playerbots-tuner): Playerbots tuning helpers for population, grouping, dungeon/LFG behavior, and world activity.
- [AzerothLabWorks/wotlk-tuning](https://github.com/AzerothLabWorks/wotlk-tuning): broader WotLK tuning scripts and data adjustments for the private server experience.

## Part 13: Profession Master Setup

The Profession Master is an optional NPC module for learning professions, buying profession skill-ups, and learning recipes/abilities available at your current profession skill.

Install and prepare it after your database containers are running. For stable `main`:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install professionmaster
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

For development `codex/hybrid-talents-ui`:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev install professionmaster
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev rebuild
```

The setup command automates the NPC template creation:

- Entry: `190020`
- Name: `Artisan Nexus-Weaver`
- Subname: `Profession Master`
- ScriptName: `npc_profession_master`
- Model row in `creature_template_model`

After the rebuild, spawn the NPC where you want it:

```text
.npc add 190020
```

Current versions also create item `3500`, `Profession Master Beacon`, which is granted on login by default and summons a temporary Profession Master near you.

The module config is:

```text
modules/mod-profession-master/conf/mod_profession_master.conf.dist
```

Important defaults:

- Profession cap: `450`
- Skill-up step: `25`
- Learn profession cost: `10000` copper, or 1 gold
- Skill-up cost: `50000` copper, or 5 gold
- Learn recipes cost: `100000` copper, or 10 gold
- Primary profession limit bypass: enabled
- Beacon item entry: `3500`

Recommended first validation path:

```text
1. Use a new character with no professions.
2. Learn two primary professions and two secondary professions.
3. Drag the profession buttons to the action bar.
4. Log out and back in, then confirm the professions and action-bar buttons remain.
5. Increase one profession skill.
6. Use Learn available recipes for that profession.
7. Confirm the profession window shows the new recipes.
```

## Troubleshooting

### Docker says permission denied

Run:

```bash
sudo service docker start
sudo usermod -aG docker "$USER"
newgrp docker
docker ps
```

### WSL2 IP changed

Run this again:

```bash
hostname -I | awk '{print $1}'
```

Then update `realmlist.wtf`.

### Server starts but WoW cannot connect

Check:

- Docker containers are running: `docker ps`
- Worldserver is ready: `docker compose logs -f ac-worldserver`
- `realmlist.wtf` points to the current WSL2 IP
- Windows Firewall is not blocking the connection

### Module changes do not appear

For C++ modules, rebuild:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

For SQL changes, import the module SQL:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid professionmaster
```

### Profession Master NPC says it does not exist

If `.npc add 190020` fails after setup, check the creature template and model rows:

```bash
docker exec -it ac-database sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world -e "
SELECT entry, name, subname, npcflag, faction, ScriptName
FROM creature_template
WHERE entry = 190020;

SELECT *
FROM creature_template_model
WHERE CreatureID = 190020;
"'
```

If the rows exist, restart the worldserver:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose restart ac-worldserver
```

### `hybrid_spell_template` table does not exist

If worldserver logs this:

```text
Table 'acore_world.hybrid_spell_template' doesn't exist
Your database structure is not up to date.
```

The Hybrid Talent System module loaded before its SQL was imported.

From the lab repo, import the Hybrid SQL and restart worldserver:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
cd ~/wow-server-playerbots-hybrid
docker compose restart ac-worldserver
```

Newer versions of this repo also place Hybrid SQL under `modules/mod-hybrid-talent-system/data/sql/` so AzerothCore's DB updater can discover it automatically on fresh builds.

If you see an older error like this:

```text
Table 'acore_characters.hybrid_spell_template' doesn't exist
```

Update the lab repo and rebuild. Current versions calculate spent hybrid points from the character table plus the world template data loaded by the module.

```bash
cd ~/azerothcore-hybrid-lab
git pull
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

### I want to update this repo on WSL2

```bash
cd ~/azerothcore-hybrid-lab
git pull
```

Then reinstall or update modules as needed:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```
