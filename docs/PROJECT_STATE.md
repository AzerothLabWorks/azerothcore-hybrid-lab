# Project State

This file is the durable handoff note for continuing AzerothCore Hybrid Lab work across Codex chats and machines.

## Repository

- GitHub: `https://github.com/AzerothLabWorks/azerothcore-hybrid-lab`
- Windows repo path: `C:\Users\User\OneDrive\Documents\Wow Modules\wow-hybrid-server-lab`
- Main branch: `main`
- Current stable commit at migration recovery: `2fdf488 Add single hybrid spell unlearning`
- Dev branch reserved for future Ascension-style UI/talent work: `codex/hybrid-talents-ui`

## WSL Runtime

- Ubuntu user: `ryan`
- WSL lab repo path: `~/azerothcore-hybrid-lab`
- Restored server path: `~/wow-server-playerbots-hybrid`
- Restored backup source: `C:\MetaPC_Data\MetaPain_Backup\Wow Server Backup`
- Docker is available inside Ubuntu.

Codex on this machine runs shell commands through a sandbox Windows account and cannot directly see the interactive user's WSL distro. For WSL/Docker operations, run commands manually in Ubuntu and paste output into the chat.

## Client

- Preferred local client path: `C:\Games\WoW-3.3.5a-HD`
- OneDrive client copy may contain cloud placeholders and should be treated as backup/source only.
- For same-machine server login, `realmlist.wtf` is usually `set realmlist 127.0.0.1`.

## Stable Server Features

- Playerbots profile with grouping behavior tuning.
- Hybrid Talent System with cross-class spell learning, descriptions, auto-rank upgrades, action-bar preservation, beacons, single-spell unlearning, and full reset.
- Profession Master with beacon item.
- AHBot setup automation.
- Transmog and Auto Learn Spells modules.
- Combo point carry-over core patch.
- Pacific server time via `TZ=America/Los_Angeles` in Docker override templates.

## Recovery Notes

The restored DB needed a compatibility repair because the rebuilt Playerbot core expected `creature.id1`, `id2`, and `id3`, while the restored world DB had only `creature.id`.

The applied repair preserved `id` and added:

```sql
ALTER TABLE creature
  ADD COLUMN id1 int unsigned NOT NULL DEFAULT 0 AFTER guid,
  ADD COLUMN id2 int unsigned NOT NULL DEFAULT 0 AFTER id1,
  ADD COLUMN id3 int unsigned NOT NULL DEFAULT 0 AFTER id2;

UPDATE creature SET id1 = id WHERE id1 = 0;
CREATE INDEX idx_creature_id1 ON creature (id1);
```

## Normal Development Flow

Windows/Codex side:

```powershell
cd "C:\Users\User\OneDrive\Documents\Wow Modules\wow-hybrid-server-lab"
git status --short --branch
```

WSL/server side:

```bash
cd ~/azerothcore-hybrid-lab
git pull

./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install playerbots hybrid professionmaster startupqol ahbot transmog learnspells
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol

AHBOT_ACCOUNT=ahbot AHBOT_CHARACTER=Auctioneer \
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot

./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

Server status checks:

```bash
cd ~/wow-server-playerbots-hybrid
docker compose ps
docker compose logs --tail=160 ac-worldserver
```

- Startup QoL module grants brand-new characters riding/mount spells, bags, starter gold, and weapon/armor proficiencies on first login. Core patch `0002-hybrid-equipment-proficiency.patch` lets weapon/armor equipment bypass normal class/proficiency restrictions while preserving item level and other non-class gates.
