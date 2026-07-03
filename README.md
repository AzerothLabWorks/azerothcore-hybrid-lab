# AzerothCore Hybrid Lab

Personal AzerothCore lab for building a WotLK 3.3.5a private server with optional module profiles, NPC-driven quality-of-life systems, and an Ascension-inspired Hybrid spell/talent progression system.

This repo owns the custom work:

- `modules/mod-hybrid-talent-system`
- `modules/mod-profession-master`
- `modules/mod-startup-qol`
- `modules/mod-hybrid-talent-system/addon/HybridTalentUI`
- `patches/core` AzerothCore source patches
- WSL2/Docker installer scripts
- Module management scripts
- Documentation and example configuration

It does not vendor the full AzerothCore source tree. Installer scripts clone the upstream server source that matches the selected profile.

## Features

- **HybridTalentUI addon**: Addon-first cross-class spell and talent interface inspired by Project Ascension. It opens from a movable microbar button, supports spell/talent tabs, class browsing, search, availability filters, icons, in-game tooltip descriptions, and next spell/talent point visibility while leveling.
- **Hybrid spell learning**: Cross-class spell learning unlocks at level 10, uses configurable hybrid spell points, supports left-click learning and right-click unlearning, refunds points correctly, preserves learned spells through relog, upgrades ranks automatically, and restores learned spell action buttons where possible.
- **Hybrid talent browsing and learning**: Cross-class talent browsing is available in the same UI with separate hybrid talent points, tooltip descriptions, learn/unlearn support, relog persistence, next-point progression clarity, free-pick talent selection across trees without native tree point requirements, and dependency checks such as requiring Charge before Improved Charge.
- **Cross-class hunter pet support**: Hybrid Hunter support includes Tame Beast dependency grants, Mend/Call/Dismiss/Revive/Feed/Beast Training support, non-Hunter pet taming, pet persistence, pet action bar restoration, pet spellbook tab support, and pet autocast persistence.
- **Retired Hybrid trainer/beacon path on this branch**: The legacy Hybrid Talent Master NPC and Hybrid Talent Beacon have been disabled/removed in the dev build. Hybrid progression now flows through the addon and `/hybridui` command path.
- **Profession Master**: NPC for learning primary/secondary professions, buying profession skill-ups, learning recipes/abilities available at the player's current profession skill, and a summon beacon item. This NPC remains active.
- **Startup QoL**: First-login package for brand-new characters with riding/mount spells, bags, starter gold, weapon/armor proficiencies, and an optional equipment-proficiency override for hybrid gearing.
- **Combo point carry-over**: Core patch that lets player combo points survive target swaps and target death, matching later WoW/Ascension-style behavior.
- **Hybrid equipment proficiency**: Core patch that lets weapon and armor equipment bypass normal class/proficiency restrictions while preserving race, faction, level, reputation, and profession gates.
- **Module automation**: Helper script can install local modules, clone supported public modules, import SQL, configure AHBot/Playerbots, set up custom NPC templates, import addon-backed Hybrid SQL, and rebuild Docker services.
- **Supported module set**: Hybrid Talent System, Profession Master, Startup QoL, Auction House Bot, Transmog, Auto Learn Spells, and Playerbots.
- **Safer install directories**: Hybrid installs use `-hybrid` and `-hybrid-dev` directory names so development testing does not collide with stable server installs.
- **Pacific server time**: Docker source-build profiles set `TZ=America/Los_Angeles` for `ac-worldserver` so in-game day/night follows Pacific Time instead of UTC.

## Profiles

- `base`: Standard AzerothCore.
- `playerbots`: Playerbot fork plus `mod-playerbots`.
- `npcbots`: NPCBots fork.

Custom modules require a source build. Fast prebuilt Docker images are useful for a clean first install, but they cannot include local custom C++ modules like the Hybrid Talent System or Profession Master.

## Quick Start

For the full Windows + WSL2 walkthrough, start here:

[HOWTO-WINDOWS-WSL2.md](HOWTO-WINDOWS-WSL2.md)

This repo has two common install paths:

- **Stable production**: use the `main` branch and install into `~/wow-server-playerbots-hybrid`.
- **Development testing**: use the `codex/hybrid-talents-ui` branch and install into `~/wow-server-playerbots-hybrid-dev`.

Do not point both branches at the same server directory. Keeping the source folders and server folders separate lets you test dev changes without touching your stable server data or build.

### Stable Main Branch

Inside Ubuntu/WSL2:

```bash
cd ~
git clone https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git
cd azerothcore-hybrid-lab
git checkout main
chmod +x scripts/*.sh
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid
```

### Development Branch

Inside Ubuntu/WSL2:

```bash
cd ~
git clone --branch codex/hybrid-talents-ui https://github.com/AzerothLabWorks/azerothcore-hybrid-lab.git azerothcore-hybrid-lab-dev
cd azerothcore-hybrid-lab-dev
chmod +x scripts/*.sh
./scripts/install-wow-hybrid.sh --profile playerbots --dir ~/wow-server-playerbots-hybrid-dev
```

You can also view the development branch on GitHub:

[https://github.com/AzerothLabWorks/azerothcore-hybrid-lab/tree/codex/hybrid-talents-ui](https://github.com/AzerothLabWorks/azerothcore-hybrid-lab/tree/codex/hybrid-talents-ui)

After installation, run the module setup commands from the matching repo folder and point them at the matching server folder. For the stable branch, use:

```bash
cd ~/azerothcore-hybrid-lab
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid list
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install hybrid professionmaster startupqol ahbot transmog learnspells
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-ahbot
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-playerbots
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

For the development branch, use the same commands with the dev paths:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev list
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev apply-core-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev apply-playerbots-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev install hybrid professionmaster startupqol ahbot transmog learnspells
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-hybrid
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-startup-qol
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-ahbot
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-playerbots
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-lfg
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-pvp
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev rebuild
```

The Playerbots patch step prevents bots from explicitly declining LFG proposals simply because they are in combat or dead. The Playerbots setup step writes `playerbots.conf`, aligns Docker overrides, and tunes the random bot population to `1500` online bots, player-level-synced leveling density, LFG participation, rated 3v3 seeding, instance strategies, summon-on-group behavior, role-biased tank/healer specs, quiet greetings, and active bot chat/broadcasts. The LFG and PvP diagnostic commands print relevant config and recent worldserver log lines after failed dungeon or arena queue attempts. The improvement roadmap tracks dungeon progression across Vanilla, Burning Crusade, and Wrath of the Lich King.

Playerbot improvement planning lives in [docs/PLAYERBOTS_IMPROVEMENT_ROADMAP.md](docs/PLAYERBOTS_IMPROVEMENT_ROADMAP.md).

## Development Branch State

This branch, `codex/hybrid-talents-ui`, is the active development build for the addon-first Hybrid spell/talent project. The stable production branch remains `main`; use a separate development server directory such as `~/wow-server-playerbots-hybrid-dev` and a separate client copy such as `C:\Games\WoW-3.3.5a-HD-Dev` when testing this branch.

The current development direction is to make the addon the main user experience for hybrid progression while keeping the server module responsible for validation, persistence, point accounting, next-point progression data, free-pick hybrid talent rules, dependency grants, and cross-class engine support.

## Startup QoL

Brand-new characters receive the configured starter package on first login: riding spells, starter mount spells, four `Gigantique Bags`, `20000` gold, and all weapon/armor proficiencies. Existing characters are not modified retroactively. With core patches applied, those hybrid proficiencies are allowed to persist even when they are not normally valid for the character class, enabling choices such as a mage wearing mail while still respecting item level requirements.

## Custom NPCs and Addon Access

Hybrid spell/talent access is now addon-first on this branch:

- Hybrid UI addon source in this repo: `modules/mod-hybrid-talent-system/addon/HybridTalentUI`
- User-facing addon repo: `https://github.com/AzerothLabWorks/addons/tree/codex/hybrid-talents-ui/HybridTalentUI`
- Addon install helper: `scripts/install-hybrid-addon.sh --client-dir <WoW client path>`
- In-game command path: `/hybridui`
- Legacy Hybrid trainer: `190010`, `Hybrid Talent Master`, retired on this branch
- Legacy Hybrid beacon item: `1915`, `Hybrid Talent Beacon`, retired on this branch

Profession Master remains NPC/beacon based:

- Profession trainer: `190020`, `Artisan Nexus-Weaver`, script `npc_profession_master`
- Profession beacon item: `3500`, `Profession Master Beacon`

The Hybrid setup step imports addon-backed Hybrid SQL and removes old Hybrid beacon/trainer access. The Profession Master setup step still creates or normalizes the Profession Master template. You can place the Profession Master permanently with:

```text
.npc add 190020
```

## Current Status

The dev branch is playable and being tested through normal progression. Confirmed areas include Hybrid spell learning/unlearning, Hybrid talent learning/unlearning, free-pick talent selection across trees, point spending/refunds, next spell/talent point display while leveling, relog persistence, spell/talent tooltips, class browsing, dependency checks, cross-class Hunter pet taming, pet action bars, pet spellbook tab support, and pet autocast persistence.

Known near-term development areas include broader class-by-class balance testing, additional dependency rules, talent progression tuning, pet talent edge cases, and continued UI polish.

## References

- AzerothCore: https://github.com/azerothcore/azerothcore-wotlk
- AzerothCore Docker: https://github.com/azerothcore/acore-docker
- Playerbots fork: https://github.com/mod-playerbots/azerothcore-wotlk
- Playerbots module: https://github.com/mod-playerbots/mod-playerbots
- NPCBots fork: https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots
- Dad's MMO Lab installer inspiration: https://github.com/DadsMmoLab/dads-mmo-lab
