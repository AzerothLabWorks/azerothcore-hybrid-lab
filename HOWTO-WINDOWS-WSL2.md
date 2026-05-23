# How to Install AzerothCore Hybrid Lab on Windows with WSL2

Run a private WoW 3.3.5a AzerothCore server on Windows using Ubuntu under WSL2 and Docker.

This guide is written for this repo:

```text
https://github.com/ryancartmell/azerothcore-hybrid-lab
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
git clone https://github.com/ryancartmell/azerothcore-hybrid-lab.git
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

- `base`: `~/wow-server-base`
- `base-prebuilt`: `~/wow-server`
- `playerbots`: `~/wow-server-playerbots`
- `npcbots`: `~/wow-server-npcbots`

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
cd ~/wow-server-playerbots
docker compose logs -f ac-worldserver
```

For other profiles, change the folder:

```bash
cd ~/wow-server-base
cd ~/wow-server-npcbots
cd ~/wow-server
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
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots install hybrid ahbot transmog learnspells
```

Rebuild after adding C++ modules:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots rebuild
```

Import module SQL after the database containers are running:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots import-sql hybrid
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
cd ~/wow-server-playerbots
docker compose up -d
```

Stop:

```bash
cd ~/wow-server-playerbots
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
   ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots import-sql hybrid
   ```

2. Create or update a trainer NPC in the world database:

   - Entry: `190010`
   - Name: `Hybrid Talent Master`
   - ScriptName: `npc_hybrid_talent_master`
   - Gossip enabled

3. Spawn the NPC in game.

4. Level a character to 10.

5. Talk to the NPC and learn a hybrid spell.

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
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots rebuild
```

For SQL changes, import the module SQL:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots import-sql hybrid
```

### I want to update this repo on WSL2

```bash
cd ~/azerothcore-hybrid-lab
git pull
```

Then reinstall or update modules as needed:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots install hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots rebuild
```

