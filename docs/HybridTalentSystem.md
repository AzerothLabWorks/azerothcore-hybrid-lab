# Hybrid Talent System for AzerothCore

## Goal

Build an Ascension-inspired system for a private AzerothCore server that lets players learn spells and talents outside their base class, while keeping progression, limits, UI, and balance rules configurable.

The system should feel like an in-game feature, not a collection of GM commands. The first version should be server-safe and data-driven, then later versions can add deeper client UI and spell synergy changes.

## Recommended Scope

### Phase 1: Server Module MVP

Create an AzerothCore module, for example `mod-hybrid-talent-system`, that provides:

- Cross-class spell learning from an allowlist.
- Configurable spell point currency.
- Configurable talent point expansion.
- NPC gossip interface for browsing, learning, unlearning, and resetting hybrid spells.
- Database-backed character spell selections.
- Basic validation to prevent impossible or broken spells.

This avoids client patching at first and gives you a playable system quickly.

### Phase 2: Better In-Game Interface

Add a custom client addon that talks to the server through one of these channels:

- Gossip menus, safest and easiest.
- Custom addon messages, better UX but requires server-side addon message handling.
- Item/NPC spellbook style UI, useful if you want the system anchored to a trainer, tome, or ascension altar.

The addon can provide:

- Class tabs.
- Role filters.
- Search by spell name.
- Cost display.
- Known/available/locked states.
- Build summary.
- Reset confirmation.

### Phase 3: Hybrid Synergy Rules

Add optional passive effects and spell mechanic adjustments:

- Custom passive auras that modify cross-class spell behavior.
- Proc rules for hybrid build archetypes.
- Scaling overrides where borrowed spells depend on incompatible stats.
- Cooldown, cost, coefficient, or requirement adjustments.
- Talent-like unlock nodes that create synergy between two or more class families.

This phase should be approached carefully because spell changes can affect bots, NPCs, pets, PvP, and scripted encounters.

## Server Architecture

### Module Hooks

The module should likely use these AzerothCore script points:

- `PlayerScript`
  - On login, restore learned hybrid spells.
  - On level change, update available points.
  - On talent reset, optionally reset hybrid talents/spells.
- `CreatureScript`
  - Trainer or altar gossip menu.
  - Learn/unlearn/reset flows.
- `WorldScript`
  - Load module config.
  - Load spell allowlist and rule tables.
- `CommandScript`
  - Admin/debug commands for granting points, resetting players, and reloading rules.

Depending on the exact AzerothCore version, hook names may vary slightly.

### Core Concepts

Use separate concepts for spells, talents, and synergy passives:

- `HybridSpell`: a learnable spell from another class.
- `HybridTalent`: a talent-like unlock, often represented by a spell or aura.
- `HybridPoint`: currency used to buy hybrid spells or talents.
- `HybridRule`: requirements, exclusions, rank handling, and class restrictions.
- `HybridBuild`: the current saved selections for a character.

### Data Storage

Suggested world DB table:

```sql
CREATE TABLE IF NOT EXISTS hybrid_spell_template (
  spell_id INT UNSIGNED NOT NULL,
  class_mask INT UNSIGNED NOT NULL DEFAULT 0,
  required_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  cost SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  category VARCHAR(64) NOT NULL DEFAULT '',
  role_mask TINYINT UNSIGNED NOT NULL DEFAULT 0,
  flags INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (spell_id)
);
```

Suggested character DB table:

```sql
CREATE TABLE IF NOT EXISTS character_hybrid_spell (
  guid INT UNSIGNED NOT NULL,
  spell_id INT UNSIGNED NOT NULL,
  learned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (guid, spell_id)
);
```

Suggested points table:

```sql
CREATE TABLE IF NOT EXISTS character_hybrid_points (
  guid INT UNSIGNED NOT NULL,
  points_earned SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  points_spent SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (guid)
);
```

Optional synergy table:

```sql
CREATE TABLE IF NOT EXISTS hybrid_synergy_template (
  synergy_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  required_spell_1 INT UNSIGNED NOT NULL,
  required_spell_2 INT UNSIGNED NOT NULL,
  reward_spell INT UNSIGNED NOT NULL,
  PRIMARY KEY (synergy_id)
);
```

## Spell Eligibility Rules

The module should reject spells that are technically learnable but likely harmful or nonsensical:

- Passive internal spells not meant for players.
- Spells with broken or missing client data.
- Duplicate ranks unless rank progression is handled deliberately.
- Pet-only spells.
- NPC-only spells.
- Spells requiring forms, stances, shapeshifts, power types, weapons, or class resources the player cannot use, unless custom compatibility rules are added.
- Quest, racial, profession, riding, teleport, and scripted encounter spells unless explicitly allowlisted.

The safest model is an explicit allowlist, not a broad import of every class spell.

## Talent Point Expansion

There are two paths:

### Safer Path

Leave the native talent frame alone and create a separate hybrid progression system. Hybrid talents are represented by learned spells/passive auras and managed by the custom NPC/addon.

Pros:

- Minimal client patching.
- Lower risk of corrupting native talent behavior.
- Easier to balance.

Cons:

- Does not look exactly like the default talent tree.

### Deeper Path

Patch client DBC/MPQ data and server talent handling to support expanded or altered talent trees.

Pros:

- More native-feeling UI.
- Can produce a true custom talent-tree experience.

Cons:

- Requires client patch distribution.
- Higher risk of crashes or desyncs.
- More maintenance when core or client data changes.

Recommendation: start with the safer path, then add a custom addon UI before attempting native talent frame modification.

## Client UI Options

### Option A: Gossip UI

Fastest first release.

Use an NPC named something like `Hybrid Talent Master`.

Menus:

- Learn Hybrid Spells
- Unlearn Hybrid Spell
- Reset Hybrid Build
- View Points
- Explain Rules

This can be implemented entirely server-side.

### Option B: Lua Addon UI

Best long-term player experience.

Addon features:

- Main frame with class tabs.
- Search box.
- Filter buttons for damage, healing, tanking, utility, passive.
- Scrollable spell list.
- Detail panel with cost, requirements, and conflicts.
- Learn/unlearn buttons.
- Build summary panel.

Communication options:

- Addon sends requests using addon messages.
- Server validates every action.
- Server replies with compact state payloads.

The server must remain authoritative. The addon should never decide whether a player can learn a spell.

### Option C: Patched Native Talent UI

Most ambitious.

Requires:

- Custom DBC changes.
- Client patch MPQ.
- Server-side compatibility work.
- Testing with every supported client build.

This should be treated as a later milestone.

## Balance Model

Start with a conservative rule set:

- Earn 1 hybrid point every 2 levels, starting at level 10.
- Cap total hybrid points at 30 or 35.
- Major cooldowns cost 3 to 5 points.
- Core rotational spells cost 2 to 3 points.
- Utility spells cost 1 to 2 points.
- Strong passives cost 3 or more points.
- Limit high-impact categories, such as only one major defensive cooldown.

Useful categories:

- Builder
- Spender
- Heal
- Defensive
- Mobility
- Crowd Control
- Pet
- Passive
- Major Cooldown
- Utility

## Spell Synergy Examples

These should be custom passives rather than direct hacks to many unrelated spells.

Examples:

- `Battle Cleric`: If the player knows a melee strike and a direct heal, melee crits can reduce the cast time or mana cost of the next heal.
- `Stormblade`: If the player knows a lightning spell and a melee strike, melee hits can add nature damage.
- `Shadowmender`: If the player knows a shadow damage spell and a heal-over-time spell, shadow damage can slightly extend active healing-over-time effects.
- `Frostguard`: If the player knows a frost spell and a shield/defensive spell, taking damage can slow attackers briefly.

Implementation approach:

- Create custom passive spell IDs.
- Learn or remove those passives when the player build changes.
- Implement proc logic in the module.
- Keep all tuning values in config or DB.

## Development Plan

1. Confirm server and client versions.
2. Confirm whether the project uses AzerothCore module format under `modules/`.
3. Build `mod-hybrid-talent-system` skeleton.
4. Add config file with point and reset settings.
5. Add SQL for template and character tables.
6. Implement spell allowlist loading.
7. Implement player login restore.
8. Implement NPC gossip learn/reset flow.
9. Add admin commands.
10. Populate a first safe spell set for testing.
11. Test with one character of each class.
12. Add addon UI once server behavior is stable.
13. Add synergy passives after the base system is reliable.

## First Implementation Target

The first useful milestone should be:

- A trainer NPC lists allowlisted spells by class.
- Player can learn a spell if they have enough hybrid points.
- Player can reset all hybrid spells.
- Learned choices persist across logout.
- On login, missing hybrid spells are restored.
- Admin can reload templates and reset a player.

That gives you a working core system without requiring client patching.

## Questions To Resolve Before Coding

- AzerothCore branch/version.
- WoW client version, likely 3.3.5a.
- Whether you want an NPC-first MVP or addon-first UI.
- Whether cross-class spells should be free-pick from level 1 or unlocked by level.
- Whether bots should use hybrid spells too, or only real players.
- Whether resets should cost gold, an item, or be free.
- Whether PvP balance matters on this private server.

