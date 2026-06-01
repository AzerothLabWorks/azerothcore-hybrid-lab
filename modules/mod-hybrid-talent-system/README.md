# mod-hybrid-talent-system

NPC-first hybrid spell system for AzerothCore 3.3.5a.

## Current MVP

- Unlocks at level 10.
- Players buy cross-class spells with hybrid points.
- Hybrid points are calculated from level, not manually stored.
- Learned hybrid spells persist across logout.
- Purchased hybrid spells can automatically upgrade to the best rank for the player's level on login and level-up.
- Login restore also works for playerbots that load as normal `Player` objects.
- Reset removes all hybrid spells and can cost gold.
- Spell choices come from an explicit allowlist in `hybrid_spell_template`.
- `Hybrid Talent Beacon` item can summon a temporary trainer near the player.

## Install

1. Copy `mod-hybrid-talent-system` into your AzerothCore source tree under `modules/`.
2. Re-run CMake for the AzerothCore build.
3. Rebuild `worldserver`.
4. Copy `conf/mod_hybrid_talent_system.conf.dist` to your server config folder as `mod_hybrid_talent_system.conf`.
5. Import the SQL files:
   - `sql/world/base/2026_05_23_00_hybrid_talent_world.sql` into the world database.
   - `sql/characters/base/2026_05_23_00_hybrid_talent_characters.sql` into the characters database.
6. Create or reuse an NPC with entry `190010` and set its `ScriptName` to `npc_hybrid_talent_master`.
7. Spawn the NPC in game, or use the `Hybrid Talent Beacon` item created by the SQL.

## NPC Setup

The exact `creature_template` schema can vary by AzerothCore revision and installed modules, so this module does not ship a hardcoded NPC insert.

Recommended workflow:

1. Copy an existing class trainer creature in your world DB.
2. Give it entry `190010`.
3. Name it `Hybrid Talent Master`.
4. Set `npcflag` to include gossip.
5. Set `ScriptName` to `npc_hybrid_talent_master`.

You can also change `HybridTalentSystem.TrainerNpcEntry` in the config if you want to use a different creature entry.

## Beacon Item

The world SQL creates item `65010`, `Hybrid Talent Beacon`, with `ScriptName` set to `item_hybrid_talent_beacon`.

By default, the module grants the item to players on login. Using the item summons a temporary Hybrid Talent Master near the player. Temporary trainers show a `Dismiss summoned trainer` gossip option.

## Admin Commands

- `.hybrid reload` reloads config and DB templates.
- `.hybrid reset` resets the selected player's hybrid build.

## Starter Spell Pool

The starter SQL intentionally uses low-level spells. That keeps the first test pass manageable.

The `class_mask` column is a disallow mask. For example, Mage spells use `128`, which prevents mages from buying their own mage spells from the hybrid trainer while allowing other classes to buy them.

## Next Work

- Add a proper unlearn-single-spell menu.
- Add pages or class filters to the gossip UI once the spell pool grows.
- Add playerbot AI tuning so bots deliberately choose and cast hybrid spells.
- Add a Lua addon UI after the server rules are stable.
- Add custom passive spells for synergies.
