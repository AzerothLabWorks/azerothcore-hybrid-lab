# mod-hybrid-talent-system

Addon-first hybrid spell and talent system for AzerothCore 3.3.5a.

## Current MVP

- Unlocks at level 10.
- Players buy cross-class spells with hybrid points.
- Players learn cross-class talents with separate hybrid talent points.
- Hybrid points are calculated from level, not manually stored.
- Learned hybrid spells persist across logout.
- Learned hybrid talents persist across logout.
- Purchased hybrid spells can automatically upgrade to the best rank for the player's level on login and level-up.
- Players can unlearn individual hybrid spells from the trainer to refund only that spell's points.
- Login restore also works for playerbots that load as normal `Player` objects.
- Reset removes all hybrid spells and can cost gold.
- Selected self-cast buffs can mirror onto active hunter pets, warlock demons, and nearby group members.
- Configurable dependency packages can grant support spells or items for class-defining hybrid spells.
- Spell choices come from curated `hybrid_spell_template` rows plus missing class-trainer spells imported from AzerothCore trainer data.
- The legacy Hybrid Talent Master and beacon flow has been retired in favor of the addon UI and `/hybridui` command path.

## Install

1. Copy `mod-hybrid-talent-system` into your AzerothCore source tree under `modules/`.
2. Re-run CMake for the AzerothCore build.
3. Rebuild `worldserver`.
4. Copy `conf/mod_hybrid_talent_system.conf.dist` to your server config folder as `mod_hybrid_talent_system.conf`.
5. Import the SQL files:
   - `sql/world/base/2026_05_23_00_hybrid_talent_world.sql` into the world database.
   - `sql/characters/base/2026_05_23_00_hybrid_talent_characters.sql` into the characters database.
6. Install the `HybridTalentUI` client addon from the matching AzerothLabWorks addons branch.
7. Use the Hybrid microbar button or `/hybridui` in game.

## Addon UI

The current user-facing Wrath client addon is published at:

https://github.com/AzerothLabWorks/addons/tree/codex/hybrid-talents-ui/HybridTalentUI

Copy the `HybridTalentUI` folder into the client's `Interface/AddOns` folder, enable it at the character screen, then use the Hybrid microbar button, `/hybridui`, or `/hyui` in game.

The addon talks to the server through AzerothCore addon-channel commands:

- `hybridui refresh`
- `hybridui learn <spellId>`
- `hybridui unlearn <spellId>`
- `hybridui learntalent <talentId>`
- `hybridui unlearntalent <talentId>`

The server remains authoritative. Learn and unlearn requests are validated by module logic before anything is applied.

## Buff Mirroring

When `HybridTalentSystem.MirrorPetBuffs` is enabled, selected self-cast friendly buff spell families also apply to the player's active pet. This is meant for hybrid builds using warlock demons or hunter beasts.

When `HybridTalentSystem.MirrorGroupBuffs` is enabled, the same selected self-cast buff families also apply to nearby party or raid members within `HybridTalentSystem.MirrorGroupBuffRange` yards. This makes hybrid group play smoother without requiring every single buff to be manually targeted.

The default `HybridTalentSystem.PetBuffSpellIds` list includes common buff families such as Power Word: Fortitude, Divine Spirit, Shadow Protection, Arcane Intellect, Arcane Brilliance, Dampen/Amplify Magic, Blessings, Mark/Gift of the Wild, and Thorns. Add only the first rank of a spell family; higher ranks are matched automatically.

## Spell Dependency Grants

`HybridTalentSystem.SpellDependencyGrants` can grant support spells when a hybrid spell is learned. The default rules make `Tame Beast` grant the hunter pet toolkit and make shard-based Warlock demon summons grant `Drain Soul`.

Dependency grants are tracked per character. When the trigger spell is unlearned or the hybrid build is reset, the module removes only support spells it granted and leaves pre-existing or separately learned spells alone.

## Spell Dependency Items

`HybridTalentSystem.SpellDependencyItems` can grant support items when a hybrid spell is learned or restored. The default rules make current earth totem spells, including `Earthbind Totem` and `Strength of Earth Totem`, grant the `Earth Totem` item required by earth totem spells.

Dependency items are not removed on unlearn because they are harmless class-kit reagents and may be shared by multiple future spells.

## Admin Commands

- `.hybrid reload` reloads config and DB templates.
- `.hybrid reset` resets the selected player's hybrid build.

## Spell Pool

The starter SQL includes curated low-level spells and then fills gaps from AzerothCore's class trainer tables. Curated rows keep their hand-tuned cost/category values; imported trainer spells default to cost `2` and category `<Class> - Trainer`.

The `class_mask` column is a disallow mask. For example, Mage spells use `128`, which prevents mages from buying their own mage spells from the hybrid trainer while allowing other classes to buy them.

## Next Work

- Continue enriching class fantasy dependency packages.
- Continue improving talent rule clarity and locked-state messaging.
- Add playerbot AI tuning so bots deliberately choose and cast hybrid spells.
- Add custom passive spells for synergies.
