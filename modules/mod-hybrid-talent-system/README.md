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
- Selected class maintenance buffs can be normalized to a configurable duration for smoother solo/hybrid play.
- Configurable dependency packages can grant support spells or items for class-defining hybrid spells.
- Spell choices come from curated `hybrid_spell_template` rows plus missing class-trainer spells imported from AzerothCore trainer data.
- The legacy Hybrid Talent Master and beacon flow has been retired in favor of the addon UI and `/hybridui` command path.
- Hybrid action-bar persistence tracks learned hybrid spells, dependency-granted support spells, hybrid talent actives, and known spells from the Hybrid UI template pool so rank changes/relog cleanup do not silently remove placed buttons.
- The client addon includes a tested shaman weapon imbue reminder for main-hand and off-hand temporary weapon enchants.
- Optional non-combat companion auto-loot can loot nearby eligible creature corpses as a QoL feature for solo and bot-group play.

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

## Weapon Imbue Reminder

The `HybridTalentUI` addon can remember the last shaman weapon imbue the player cast and show separate movable `MH` and `OH` reminder buttons when the main-hand or off-hand temporary enchant is missing or close to expiring. The buttons use `GetWeaponEnchantInfo()` client-side state and do not change server spell validation.

Current tested scope:

- Rockbiter Weapon
- Flametongue Weapon
- Frostbrand Weapon
- Windfury Weapon
- Earthliving Weapon

The reminder is enabled by default after the addon loads. It starts tracking after the player casts a supported imbue once. Useful commands:

- `/hyui imbue` shows reminder status.
- `/hyui imbue on` enables reminders.
- `/hyui imbue off` disables reminders.
- `/hyui imbue reset` clears remembered imbues and saved reminder positions.
- `/hyui imbue threshold <seconds>` changes the low-duration reminder threshold.

Follow-up QA targets include Rogue poisons and other temporary weapon effects once those characters are being tested.

## Buff Mirroring

When `HybridTalentSystem.MirrorPetBuffs` is enabled, selected self-cast friendly buff spell families also apply to the player's active pet. This is meant for hybrid builds using warlock demons or hunter beasts.

When `HybridTalentSystem.MirrorGroupBuffs` is enabled, the same selected self-cast buff families also apply to nearby party or raid members within `HybridTalentSystem.MirrorGroupBuffRange` yards. This makes hybrid group play smoother without requiring every single buff to be manually targeted.

The default `HybridTalentSystem.PetBuffSpellIds` list includes common buff families such as Power Word: Fortitude, Divine Spirit, Shadow Protection, Arcane Intellect, Arcane Brilliance, Dampen/Amplify Magic, Blessings, Mark/Gift of the Wild, and Thorns. Add only the first rank of a spell family; higher ranks are matched automatically.

## Class Buff Duration

When `HybridTalentSystem.NormalizeClassBuffDuration.Enable` is enabled, selected class maintenance buff families are normalized to `HybridTalentSystem.NormalizeClassBuffDuration.Seconds`. QA defaults to 30 minutes for upkeep buffs such as Battle Shout, Commanding Shout, Paladin blessings, Fortitude, Spirit, Shadow Protection, Arcane Intellect, Mark/Gift of the Wild, Thorns, Dampen Magic, and Amplify Magic.

Only maintenance buff families should be listed. Short tactical cooldowns such as Blessing of Freedom, Blessing of Protection, Divine Shield, and similar defensive buttons should keep their native durations.

## Companion Auto-Loot

When `HybridTalentSystem.CompanionAutoLoot.Enable` is enabled, an active non-combat companion can loot nearby eligible creature corpses for the player. The feature uses normal server loot eligibility and leaves protected loot checks in place.

Key options:

- `HybridTalentSystem.CompanionAutoLoot.Radius`
- `HybridTalentSystem.CompanionAutoLoot.IntervalMs`
- `HybridTalentSystem.CompanionAutoLoot.OutOfCombatOnly`
- `HybridTalentSystem.CompanionAutoLoot.RequireNonCombatCompanion`
- `HybridTalentSystem.CompanionAutoLoot.PrioritizePlayerInGroups`

## Spell Dependency Grants

`HybridTalentSystem.SpellDependencyGrants` can grant support spells when a hybrid spell is learned. The default rules make `Tame Beast` grant the hunter pet toolkit and make shard-based Warlock demon summons grant `Drain Soul`.

Dependency grants are tracked per character. When the trigger spell is unlearned or the hybrid build is reset, the module removes only support spells it granted and leaves pre-existing or separately learned spells alone.

## Spell Dependency Items

The module automatically grants Shaman totem tool items declared by spell data when a hybrid totem spell is learned or restored. This covers Earth, Fire, Water, and Air totem tools.

`HybridTalentSystem.SpellDependencyItems` can grant extra support items when a hybrid spell is learned or restored. Use it for support items that are not declared directly on the spell.

Dependency items are removed on unlearn when no other learned hybrid spell still requires the same item.

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
