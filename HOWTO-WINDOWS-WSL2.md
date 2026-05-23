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

## Part 6: Install or Update Modules

List known modules:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh list
```

Install modules into an existing source server:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid ahbot transmog learnspells
```

Rebuild after adding C++ modules:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

Import module SQL after the database containers are running:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
```

Current known module keys:

- `hybrid`: Hybrid Talent System from this repo.
- `ahbot`: Auction House Bot.
- `transmog`: Transmog.
- `learnspells`: Auto Learn Spells.

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

## Part 10: Hybrid Talent System Setup

The installer copies the Hybrid Talent System module into the server source tree for source-build profiles.

After building and starting the server:

1. Import the module SQL if it was not imported automatically:

   ```bash
   cd ~/azerothcore-hybrid-lab
   ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
   ```

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

3. Recommended NPC creation method: copy an existing simple gossip NPC.

   The exact `creature_template` columns can vary between AzerothCore versions and forks, so copying an existing template is safer than writing a giant insert by hand.

   Open a database shell for the world database:

   ```bash
   cd ~/wow-server-playerbots-hybrid
   docker exec -it $(docker ps --format '{{.Names}}' | grep -E 'database|mysql|mariadb|db' | head -1) \
     mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world
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

The module config is:

```text
modules/mod-hybrid-talent-system/conf/mod_hybrid_talent_system.conf.dist
```

Important defaults:

- Unlock level: `10`
- Max points: `35`
- Reset cost: `100000` copper, or 10 gold
- NPC entry: `190010`

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
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid import-sql hybrid
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
