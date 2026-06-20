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

After restart, open Ubuntu from the Start menu and create your Linux username/password.

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

## Part 3: Download This Repo

Inside Ubuntu:

```bash
cd ~
git clone https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git
cd azerothcore-hybrid-lab
chmod +x scripts/*.sh
```

## Part 4: Choose an Install Profile

Recommended first choice for your project:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots
```

Other options:

```bash
# AzerothCore source build with Hybrid Talent System
./scripts/install-wow-hybrid.sh --profile base

# Fast clean AzerothCore install, no custom C++ modules
./scripts/install-wow-hybrid.sh --profile base-prebuilt

# NPCBots source/fork with Hybrid Talent System
./scripts/install-wow-hybrid.sh --profile npcbots
```

Default install folders:

- `base`: `~/wow-server-base-hybrid`
- `base-prebuilt`: `~/wow-server-prebuilt-hybrid`
- `playerbots`: `~/wow-server-playerbots-hybrid`
- `npcbots`: `~/wow-server-npcbots-hybrid`

These `-hybrid` defaults are intentional. They keep this lab separate from any existing AzerothCore, DadsMmoLab, Playerbots, or NPCBots installs you already have.

To use a custom folder:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/my-wow-server
```

To clone/configure only and build later:

```bash
./scripts/install-wow-hybrid.sh --profile playerbots --no-build
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

Rebuild after adding C++ modules:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

### Startup QoL Starter Package

The `startupqol` module grants brand-new characters a first-login package: all configured riding spells, starter mount spells, four `Gigantique Bags`, `20000` gold, and weapon/armor proficiencies. Existing characters are not changed retroactively. When core patches are applied, those proficiencies can also bypass normal weapon/armor class restrictions for hybrid gearing.

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

The installer copies the Hybrid Talent System module into the server source tree for source-build profiles.

The current MVP is an NPC-first hybrid spell system. Players spend level-based hybrid points to learn cross-class spells from an allowlist. Cross-class talent support is planned as a later iteration after the spell flow is stable.

After building and starting the server:

1. Verify or import the Hybrid module SQL.

   The helper command installs the Hybrid config file, safely imports Hybrid SQL, and normalizes the trainer NPC flags:

   ```bash
   cd ~/azerothcore-hybrid-lab
   ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
   ```

   If you only want to re-import SQL, this is safe to re-run because the Hybrid SQL uses `CREATE TABLE IF NOT EXISTS` and updates the starter spell templates without dropping learned character data.

   ```bash
   cd ~/azerothcore-hybrid-lab
   ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
   ```

   To check manually whether the table already exists:

   ```bash
   cd ~/wow-server-playerbots-hybrid
   docker exec -it ac-database sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world -e "SHOW TABLES LIKE '\''hybrid_spell_template'\'';"'
   ```

   You do not need to know the MySQL root password when using the command above. It reads `MYSQL_ROOT_PASSWORD` from inside the database container.

   If you connect from outside the container, AzerothCore's Docker default is:

   ```text
   username: root
   password: password
   database: acore_world
   ```

   That default changes if `DOCKER_DB_ROOT_PASSWORD` is set in your server environment.

2. Create or update a trainer NPC in the world database.

   The Hybrid Talent System uses a normal AzerothCore creature as its trainer NPC. The important fields are:

   - `entry`: `190010`
   - `name`: `Hybrid Talent Master`
   - `npcflag`: must include gossip
   - `ScriptName`: `npc_hybrid_talent_master`

   In AzerothCore, `entry` is the creature template ID. The module config expects this value by default:

   ```text
   HybridTalentSystem.TrainerNpcEntry = 190010
   ```

   `ScriptName` is what connects the creature to the C++ module. If this value is wrong or blank, the NPC may spawn but the Hybrid Talent menu will not open.

   `npcflag` controls what interaction icons/features the NPC has. Gossip is flag `1`, so the safest minimum is:

   ```text
   npcflag = 1
   ```

   If you copy an existing trainer NPC, it may already have other flags. That is fine. Just make sure gossip is included.

   If you already created entry `190010`, run this after editing it:

   ```bash
   cd ~/azerothcore-hybrid-lab
   ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
   ```

3. Recommended NPC creation method: copy an existing simple gossip NPC.

   The exact `creature_template` columns can vary between AzerothCore versions and forks, so copying an existing template is safer than writing a giant insert by hand.

   Open a database shell for the world database:

   ```bash
   cd ~/wow-server-playerbots-hybrid
   docker exec -it ac-database sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world'
   ```

   Inside MySQL, find a simple NPC template to copy:

   ```sql
   SELECT entry, name, npcflag, ScriptName
   FROM creature_template
   WHERE npcflag & 1
   ORDER BY entry
   LIMIT 20;
   ```

   Pick one harmless gossip NPC from the result. Then copy it into entry `190010`.

   Example using source entry `68`:

   ```sql
   CREATE TEMPORARY TABLE tmp_hybrid_npc
   AS SELECT * FROM creature_template WHERE entry = 68;

   UPDATE tmp_hybrid_npc
   SET entry = 190010,
       name = 'Hybrid Talent Master',
       subname = 'Cross-Class Trainer',
       npcflag = npcflag | 1,
       ScriptName = 'npc_hybrid_talent_master';

   DELETE FROM creature_template WHERE entry = 190010;
   INSERT INTO creature_template SELECT * FROM tmp_hybrid_npc;
   DROP TEMPORARY TABLE tmp_hybrid_npc;
   ```

   If your selected source NPC does not have a `subname` column, remove this line:

   ```sql
   subname = 'Cross-Class Trainer',
   ```

   Verify it:

   ```sql
   SELECT entry, name, subname, npcflag, ScriptName
   FROM creature_template
   WHERE entry = 190010;
   ```

   Example using Lady Jaina Proudmoore as the trainer:

   ```sql
   SELECT entry, name, npcflag, ScriptName
   FROM creature_template
   WHERE name LIKE '%Jaina%' AND npcflag & 1
   ORDER BY entry;
   ```

   On a typical AzerothCore WotLK database, entry `32346` is a good source template because it has gossip enabled and no special `ScriptName`.

   Do not modify the original Jaina entry. Copy it into your custom trainer entry instead:

   ```sql
   CREATE TEMPORARY TABLE tmp_hybrid_npc
   AS SELECT * FROM creature_template WHERE entry = 32346;

   UPDATE tmp_hybrid_npc
   SET entry = 190010,
       name = 'Lady Jaina Proudmoore',
       subname = 'Hybrid Talent Master',
       npcflag = 1,
       gossip_menu_id = 0,
       AIName = '',
       ScriptName = 'npc_hybrid_talent_master';

   DELETE FROM creature_template WHERE entry = 190010;
   INSERT INTO creature_template SELECT * FROM tmp_hybrid_npc;
   DROP TEMPORARY TABLE tmp_hybrid_npc;
   ```

   Verify it:

   ```sql
   SELECT entry, name, subname, npcflag, gossip_menu_id, AIName, ScriptName
   FROM creature_template
   WHERE entry = 190010;
   ```

4. Alternative NPC creation method: use a database editor.

   If you prefer a GUI such as HeidiSQL, DBeaver, or phpMyAdmin:

   - Open the `acore_world` database.
   - Open `creature_template`.
   - Copy an existing simple gossip NPC row.
   - Change `entry` to `190010`.
   - Change `name` to `Hybrid Talent Master`.
   - Change `subname` to `Cross-Class Trainer`, if that column exists.
   - Make sure `npcflag` includes gossip. Minimum value: `1`.
   - Set `ScriptName` to `npc_hybrid_talent_master`.
   - Save the row.

5. Restart the worldserver or reload creature templates.

   The easiest option is to restart the server:

   ```bash
   cd ~/wow-server-playerbots-hybrid
   docker compose restart ac-worldserver
   ```

   If you are attached to the worldserver console as a GM/admin, you can try:

   ```text
   reload creature_template
   ```

   A full worldserver restart is the more reliable path while setting this up.

6. Spawn the NPC in game.

   Log in with a GM account and go to the place where you want the trainer to stand.

   Target your own location and run:

   ```text
   .npc add 190010
   ```

   The NPC should appear where your character is standing.

   Quality-of-life tip: current versions also create item `1915`, `Hybrid Talent Beacon`, which is granted on login by default and summons a temporary trainer near you.

   GM commands can still be placed in normal in-game macros if your account has permission to run them. Create a macro named `Hybrid Trainer` with:

   ```text
   .npc add 190010
   ```

   Put the macro on your action bar while testing so you do not have to remember the trainer entry ID.

   If you want to remove a bad spawn:

   ```text
   .npc delete
   ```

   Make sure the NPC is targeted before running `.npc delete`.

7. Test the NPC.

   Level a character to at least 10:

   ```text
   .levelup 9
   ```

   Or use your normal leveling flow.

   Talk to the `Hybrid Talent Master`. You should see options like:

   - `View hybrid status`
   - `Learn hybrid spells`
   - `Reset hybrid build`

   Learn a spell, relog, and confirm the spell is still known.

   Recommended first validation path:

   ```text
   1. Use a level 10 character.
   2. Click View hybrid status and confirm earned/spent/available points appear in chat.
   3. Click Learn hybrid spells and learn one 1-point spell.
   4. Cast the learned spell.
   5. Relog and confirm the spell is still known.
   6. Level to 12 and confirm available points increases by 1.
   7. Continue leveling and confirm purchased hybrid spells automatically upgrade to the best rank available for the character's level.
   8. Test Reset hybrid build when the character has enough gold.
   ```

The module config is:

```text
modules/mod-hybrid-talent-system/conf/mod_hybrid_talent_system.conf.dist
```

Important defaults:

- Unlock level: `10`
- Point curve: `1` point every `2` levels starting at level `10`
- Max points: `35`
- Reset cost: `100000` copper, or 10 gold
- NPC entry: `190010`
- Beacon item entry: `1915`
- Auto-upgrade purchased hybrid spell ranks on login and level-up: enabled

## Part 12: Profession Master Setup

The Profession Master is an optional NPC module for learning professions, buying profession skill-ups, and learning recipes/abilities available at your current profession skill.

Install and prepare it after your database containers are running:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install professionmaster
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
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
