# AzerothCore Hybrid Lab

Personal AzerothCore lab for building a WotLK 3.3.5a private server with optional module profiles, NPC-driven quality-of-life systems, and an Ascension-inspired Hybrid Talent System.

This repo owns the custom work:

- `modules/mod-hybrid-talent-system`
- `modules/mod-profession-master`
- `modules/mod-startup-qol`
- `patches/core` AzerothCore source patches
- WSL2/Docker installer scripts
- Module management scripts
- Documentation and example configuration

It does not vendor the full AzerothCore source tree. Installer scripts clone the upstream server source that matches the selected profile.

## Features

- **Hybrid Talent System**: NPC-first cross-class spell learning unlocked at level 10, with configurable point costs, gold reset cost, automatic spell rank upgrades, action-bar preservation for learned hybrid spells, and a summon beacon item.
- **Profession Master**: NPC for learning primary/secondary professions, buying profession skill-ups, learning recipes/abilities available at the player's current profession skill, and a summon beacon item.
- **Startup QoL**: First-login package for brand-new characters with riding/mount spells, bags, starter gold, and weapon/armor proficiencies.
- **Combo point carry-over**: Core patch that lets player combo points survive target swaps and target death, matching later WoW/Ascension-style behavior.
- **Module automation**: Helper script can install local modules, clone supported public modules, import SQL, configure AHBot, set up custom trainer NPC templates, and rebuild Docker services.
- **Supported module set**: Hybrid Talent System, Profession Master, Startup QoL, Auction House Bot, Transmog, and Auto Learn Spells.
- **Safer install directories**: Hybrid installs use `-hybrid` directory names such as `wow-server-playerbots-hybrid` so testing does not collide with existing server installs.
- **Pacific server time**: Docker source-build profiles set `TZ=America/Los_Angeles` for `ac-worldserver` so in-game day/night follows Pacific Time instead of UTC.

## Profiles

- `base`: Standard AzerothCore.
- `playerbots`: Playerbot fork plus `mod-playerbots`.
- `npcbots`: NPCBots fork.

Custom modules require a source build. Fast prebuilt Docker images are useful for a clean first install, but they cannot include local custom C++ modules like the Hybrid Talent System or Profession Master.

## Quick Start

For the full Windows + WSL2 walkthrough, start here:

[HOWTO-WINDOWS-WSL2.md](HOWTO-WINDOWS-WSL2.md)

Inside Ubuntu/WSL2:

```bash
git clone <your-github-repo-url> ~/wow-hybrid-server-lab
cd ~/wow-hybrid-server-lab
chmod +x scripts/*.sh
./scripts/install-wow-hybrid.sh
```

After installation, use:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid list
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid professionmaster startupqol ahbot transmog learnspells
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

## Startup QoL

Brand-new characters receive the configured starter package on first login: riding spells, starter mount spells, four `Gigantique Bags`, `20000` gold, and all weapon/armor proficiencies. Existing characters are not modified retroactively.

## Custom NPCs

- Hybrid trainer: `190010`, `Hybrid Talent Master`, script `npc_hybrid_talent_master`
- Profession trainer: `190020`, `Artisan Nexus-Weaver`, script `npc_profession_master`
- Hybrid beacon item: `1915`, `Hybrid Talent Beacon`
- Profession beacon item: `3500`, `Profession Master Beacon`

The setup commands create or normalize the database templates and beacon items. Beacon items are granted on login by default and summon temporary trainers near the player. You can still choose permanent in-game placement with GM commands such as:

```text
.npc add 190010
.npc add 190020
```

## Current Status

The repo is an active MVP lab. The Hybrid Talent System and Profession Master are playable and being tested through normal progression. The next larger design phase is cross-class talent support with a more visual talent browsing experience.

## References

- AzerothCore: https://github.com/azerothcore/azerothcore-wotlk
- AzerothCore Docker: https://github.com/azerothcore/acore-docker
- Playerbots fork: https://github.com/mod-playerbots/azerothcore-wotlk
- Playerbots module: https://github.com/mod-playerbots/mod-playerbots
- NPCBots fork: https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots
- Dad's MMO Lab installer inspiration: https://github.com/DadsMmoLab/dads-mmo-lab
