# Hybrid Talent System Roadmap

This is the living roadmap for the Hybrid spell/talent project. It tracks what is already live, what is being validated through play, what we may build next on `codex/hybrid-talents-ui`, and which higher-risk experiments belong in the isolated QA lane before any promotion back toward normal development.

## Branch And Environment Model

- Stable source branch: `main`
- Active development branch: `codex/hybrid-talents-ui`
- High-risk QA branch: `codex/hybrid-race-class-qa`
- Stable WSL server: `~/wow-server-playerbots-hybrid`
- Development WSL server: `~/wow-server-playerbots-hybrid-dev`
- QA WSL lab repo: `~/azerothcore-hybrid-lab-qa`
- QA WSL server: `~/wow-server-playerbots-hybrid-qa`
- Stable client example: `C:\Games\WoW-3.3.5a-HD`
- Development client example: `C:\Games\WoW-3.3.5a-HD-Dev`
- Disposable client experiment copy: `C:\Games\WoW-3.3.5a-HD-Test`
- QA Docker endpoints: auth `127.0.0.1:3725`, world `127.0.0.1:8086`, DB `127.0.0.1:3307`, SOAP `127.0.0.1:7879`

Use `main` for stable source and production deployment. Use `codex/hybrid-talents-ui` for normal new work. Use `codex/hybrid-race-class-qa` for experiments that may affect race/class assumptions, character creation, DBC data, GlueXML, shapeshift display logic, or client MPQ patches.

Do not modify `main`, `codex/hybrid-talents-ui`, `~/wow-server-playerbots-hybrid`, or `~/wow-server-playerbots-hybrid-dev` while doing QA experiments unless a proven QA change is explicitly being promoted. Client-side experiments should happen only in `C:\Games\WoW-3.3.5a-HD-Test` until proven recoverable and worth promoting.

## Current State

Status after PR #1 promotion to `main` and resync of `codex/hybrid-talents-ui`:

| Area | State | Notes |
|---|---|---|
| Addon-first Hybrid UI | Live | `HybridTalentUI` provides the primary spell/talent interface with a movable launcher button and `/hybridui`. |
| Spell browsing | Live | Class filters, availability filters, icons, native tooltips, known/available/locked states, learn, and unlearn are working. Search now includes names, IDs, server descriptions, and client tooltip descriptions. |
| Spell persistence | Live | Learned hybrid spells persist through relog and restart, upgrade to best rank where configured, and action bars are preserved where possible. Dependency-granted support spells such as Mend Pet and known Hybrid UI template spells such as Battle Shout are now included in action-bar persistence when tracked. |
| Talent browsing | Live | Talents can be browsed by class, show native descriptions/tooltips, use separate hybrid talent points, and participate in tooltip-description search. |
| Talent learning | Live | Hybrid talents can be learned/unlearned, persist through relog, allow free picks across trees without native tree point requirements, and support dependency checks such as requiring Charge before Improved Charge. |
| Talent UI clarity | In progress | Talent rows, details, and chat feedback show next rank, max-rank state, locked reasons, and free-pick rules more clearly. |
| Progression clarity | Live | The addon shows when the next spell point and next talent point will be earned during leveling. |
| Progression balance | Playtesting | Current defaults are playable, but point cadence, costs, level gates, and long-term leveling feel still need more character progression data. |
| QA gameplay pacing | Live in QA | `setup-qa-rates` applies the current QA pacing profile: `3x` player XP, `5x` reputation, `4x` crafting/gathering skill gain, `2x` rare drops, and `1.5x` epic drops. |
| Hunter pet support | Live | Tame Beast works for hybrid characters, grants the required pet toolkit, supports pet persistence, pet action bar restoration, pet spellbook tab, and autocast persistence. |
| Buff mirroring | Live | Selected self-cast buff families can mirror to active pets and nearby group members. |
| Class dependency packages | In progress | Hunter pet support is live. Warlock demon summons now grant Drain Soul support, Shaman totem spells automatically grant required Earth, Fire, Water, and Air totem tools from spell data, and Rogue Stealth/Poisons now grant starter utility support. Hybrid totems also use faction-safe fallback models when a non-Shaman race has no native totem model. |
| Multi-resource hybrid support | Live in QA | QA can grant baseline mana, energy, and rage pools through `Hybrid.Resources.*` config so cross-class spells have their expected resource pools available. Ongoing playtesting should validate edge cases such as Rogue abilities on non-Rogues and Warrior abilities on caster classes. |
| Equipment skill persistence | Live | Hybrid weapon/armor skills and Dual Wield are allowed to persist across class restrictions, reducing repeated login cleanup and duplicate spell-save noise. |
| Weapon imbue reminders | Live in QA addon | Shaman weapon imbue reminders support main hand and off hand independently, including mixed imbues such as Flametongue plus Frostbrand. Login/equipment-change settle timing prevents false startup reminders. |
| Azeroth flying unlock | Live in QA | QA client/server patches allow flying mounts in old-world Azeroth. Server-side QA support now also permits Eversong Woods, Ghostlands, Azuremyst Isle, and Bloodmyst Isle. These starter zones remain a known client-terrain edge case: mounting/flying works, but movement can feel constrained, so terrain/ADT patching is deferred as too risky for now. |
| Targeted ground AoE usability | Active in QA | Rain of Fire validated the client/server pattern: client DBC marks selected ground spells as unit-targetable while server config snapshots the selected target position as the spell destination. Expanded player spell-family testing is active. |
| Companion auto-loot / Lootbot QoL | Live in QA | Active non-combat companions/minipets can auto-loot nearby eligible creature corpses. Multiple corpses are handled one at a time. Grouped bot play is supported, with an opt-in QA flag to prioritize the player on eligible group loot while still respecting protected loot checks. |
| Legacy trainer/beacon | Retired | Hybrid Talent Master and Hybrid Talent Beacon are disabled on this path. Hybrid progression is addon-first. |
| Profession Master | Live | Profession Master remains NPC/beacon based and is not retired. |
| Playerbots support | Live separately | Playerbot population, LFG, role, and social tuning are tracked in `docs/PLAYERBOTS_IMPROVEMENT_ROADMAP.md`. |
| QA race/class unlocks | First smoke pass successful | `Hybrid.AllowAnyRaceClass` is active on the isolated QA server. Undead Hunter, Human Druid, and Gnome Shaman have passed initial gameplay smoke routes covering pets, shapeshifts, totems, starter spells, action bars, gear, and logout/login retention. |
| QA client asset experiments | Active in disposable QA client | Local-only QA patches in `C:\Games\WoW-3.3.5a-HD-Test\Data` carry the any-race/any-class, starter outfit, reagent tooltip, Azeroth flying, and Warrior stance client prototypes. Generated MPQs and extracted client files are not committed to this repo; see `docs/CLIENT_PATCH_POLICY.md`. |

## Completed Milestones

### Foundation

- Created isolated development branch and dev server workflow.
- Added safer stable/dev install paths and documentation.
- Added module management commands for install, SQL import, setup, rebuild, diagnostics, and addon install.
- Promoted the first stable development cycle to `main` through PR #1.

### Hybrid UI

- Built custom addon-first spell UI.
- Added class filters, search, status filters, pagination, icons, and native tooltips.
- Expanded search so spells and talents can be found by client tooltip descriptions, not only names.
- Added known spell filtering across all classes.
- Added talent browsing and learning views.
- Added movable Hybrid launcher button near the microbar.
- Added optional Shaman weapon imbue reminder buttons with independent main-hand/off-hand memory, mixed imbue support, startup settle timing, and movable UI positions.
- Moved user-facing addon distribution to `AzerothLabWorks/addons` on the matching dev branch.

### Spell And Talent Mechanics

- Added server protocol for addon refresh, learn, and unlearn commands.
- Added point display and refresh behavior after learning/unlearning.
- Added next spell/talent point display for leveling clarity.
- Added free-pick hybrid talent selection across talent trees without requiring prior points in that tree.
- Improved talent row/detail text for rank state, next rank, locked reasons, and free-pick rules.
- Added known/available/locked/unaffordable status handling.
- Added action bar preservation for hybrid spells and talent-granted spells.
- Added logic to respect intentionally removed action buttons.
- Added action-bar persistence for tracked dependency-granted support spells, such as Mend Pet granted by Tame Beast.
- Added stance requirement relaxation and Hybrid UI tooltip notes for selected Warrior abilities only: Charge, Intercept, Overpower, Mocking Blow, Revenge, Disarm, Shield Wall, Retaliation, Recklessness, Berserker Rage, Pummel, and Whirlwind.
- Added dependency item packages, including automatic Shaman totem tool grants from spell data.

### Hunter Pet Support

- Added dependency grants for Tame Beast.
- Added Mend Pet and hunter pet support spells.
- Allowed hybrid characters to tame beasts.
- Completed Tame Beast behavior on aura expiration.
- Loaded hybrid tamed pets as Hunter pets.
- Restored pet action bars, pet spell slots, pet spellbook tab, and autocast state.

### Buff And Group Quality Of Life

- Mirrored selected buffs to pets.
- Mirrored selected buffs to nearby group members.
- Kept behavior configurable through module config.

### Class Dependency Packages

- Expanded spell dependency grants so Voidwalker, Succubus, and Felhunter summon spells grant Drain Soul support for soul shards.
- Added Shaman totem item dependency support so hybrid totem spells can grant their required Earth, Fire, Water, or Air totem tool items.
- Added Shaman totem model fallback support so hybrid totems cast by non-Shaman races render as valid Dwarf or Orc totems instead of missing-model placeholders.
- Added Rogue dependency packages: Stealth grants Pick Pocket, Sap, and Pick Lock, while Poisons grants Instant Poison as a starter poison application.
- Added Blood Elf Warrior startup support so QA-created Blood Elf Warriors receive Arcane Torrent through player creation spell/action data.

### QA Environment

- Created `codex/hybrid-race-class-qa` from `codex/hybrid-talents-ui`.
- Created isolated QA lab repo at `~/azerothcore-hybrid-lab-qa`.
- Created isolated QA server at `~/wow-server-playerbots-hybrid-qa`.
- Configured QA Docker container names, image tag, volumes, and ports separately from the normal stable/dev lanes.
- Installed `HybridTalentUI` into the disposable client copy at `C:\Games\WoW-3.3.5a-HD-Test`.
- Pointed the disposable client realmlist files at the QA auth endpoint, `127.0.0.1:3725`.

### QA Any Race / Any Class Prototype

- Added QA-only `Hybrid.AllowAnyRaceClass` server gating.
- Synthesized missing player creation definitions for unsupported race/class pairs when the QA flag is enabled.
- Synthesized starter action bar entries for unsupported race/class pairs.
- Added a guarded racial action-bar fallback that places a known active racial in the first free action slot during character creation.
- Added same-class starter outfit fallback logic for unsupported race/class/gender combinations.
- Created disposable client patch `patch-y.mpq` for `C:\Games\WoW-3.3.5a-HD-Test` with expanded `CharBaseInfo.dbc` and `CharStartOutfit.dbc` data.
- Verified Gnome Shaman creation, starter spell grants, starter action bars, starter gear, and basic Lightning Bolt/Healing Wave casting.
- Verified Undead Hunter creation, starter spell grants, starter action bars, and starter gear.
- Verified Undead Hunter gameplay through natural leveling to 5, GM-assisted level 20 testing, Hunter talent selection, Tame Beast, pet combat, pet logout/login retention, and hybrid spell learning.
- Verified Human Druid creation, starter gear, starter spells, level 2 auto spell learning, GM-assisted level 22 spell learning, Bear Form, Cat Form, default Night Elf druid form models, Hybrid Tame Beast, pet combat, and post-save logout/login retention.
- Verified Gnome Shaman totem support and active Shaman spell retention across logout/login, including Lightning Shield and Flametongue Weapon.

### QA Quality-Of-Life Prototypes

- Added config-gated reagent-free casting for Hybrid learn-template spells.
- Added QA client `Spell.dbc` reagent cleanup in `patch-z.mpq` so reagent tooltip text is removed for the tested hybrid spell surface.
- Added config-gated Azeroth flying support and matching QA client patching so flying mounts work in Eastern Kingdoms and Kalimdor.
- Extended server-side Azeroth flying support to the Burning Crusade starter zones that live on map `530`: Eversong Woods, Ghostlands, Azuremyst Isle, and Bloodmyst Isle. Local client `AreaTable.dbc` experiments did not remove the starter-zone movement constraint, so terrain/ADT patching is intentionally deferred and documented as a known QA limitation.
- Added selected Warrior stance requirement relaxation on the server and matching client tooltip/DBC support for the disposable QA client.
- Added Shaman weapon imbue reminders to Hybrid UI, including independent MH/OH reminders, mixed imbue support, and delayed startup checks to avoid false login reminders.
- Added tracked dependency action-bar persistence so support spells such as Mend Pet remain on the action bar after relog once placed.
- Added a client patch policy documenting that generated MPQs and extracted client files remain local-only QA artifacts and should not be committed or publicly redistributed.

## Active Planning Lanes

These are the main areas we can pick from for the next development cycle.

### 1. Progression And Balance

Goal: make spell and talent acquisition feel good over a full leveling journey.

Current state: the progression display work is live and validated. The broader balance pass remains open until point gain, costs, level gates, and late-level progression have been tested through more normal gameplay.

Candidate work:

- Tune hybrid spell point gain rate.
- Tune hybrid talent point gain rate.
- Review spell costs by power, role, cooldown, utility, and class identity.
- Review talent costs and rank pacing.
- Add level gates for especially powerful spells/talents.
- Add a simple balance notes table to document why key costs differ.

Why this matters: the system works mechanically, but pacing determines whether hybrid progression feels rewarding instead of chaotic or overpowered.

### 2. Talent UI And Talent Rules

Goal: make talent choices easier to understand and safer to use.

Candidate work:

- Show learned talent rank more clearly in the list/detail panel.
- Improve locked talent explanations.
- Document and preserve free-pick talent behavior across trees.
- Add clearer dependency text for talents that require base spells or other talents.
- Add tree/category labels where useful.
- Review talents that grant active spells and ensure action bar behavior remains stable.
- Expand data-driven talent dependency rules.

Why this matters: talents are now usable, but the UI can do more to explain why a talent is available, locked, or valuable.

### 3. Class Fantasy Dependency Packages

Goal: make cross-class mechanics feel complete when a player learns class-defining spells.

Candidate work:

- Review Rogue stealth/combo-point support dependencies.
- Review Warlock demon support and missing companion spells.
- Review Shaman totem support and totem prerequisites.
- Review Paladin aura/blessing behavior.
- Review Druid shapeshift spell and form edge cases.
- Review Warrior stance-less ability coverage after more playtesting. Current stance relaxation is intentionally limited to selected Warrior hybrid abilities and should not be treated as a global stance/form/resource removal.
- Add dependency spell rules through `HybridTalentSystem.SpellDependencyGrants` and dependency item rules through `HybridTalentSystem.SpellDependencyItems` where possible.

Why this matters: Tame Beast showed that one iconic spell often needs a supporting kit. Other class fantasies may need similar packages.

### 4. Multi-Resource Hybrid Support

Goal: make learned hybrid spells usable when they depend on a resource or class state the player's native class does not normally have.

Candidate work:

- Test Rogue energy abilities such as Sinister Strike on non-Rogue classes.
- Test combo point builders and finishers on classes that do not normally use Rogue/Druid combo-point flows.
- Test Warrior rage abilities on mana or energy classes.
- Test Death Knight runic power assumptions if DK abilities become part of normal hybrid progression.
- Review mana, rage, energy, runic power, combo points, stance, form, weapon, pet, and shapeshift requirements separately instead of treating all restrictions as one switch.
- Prefer narrow, spell-family-specific fixes over global resource removal.
- Keep each relaxation config-gated where possible, with QA-only defaults until playtesting proves it is stable.
- Add Hybrid UI notes for spells that require a special resource or where QA behavior intentionally differs from stock WotLK.

Why this matters: free spell learning only feels good if learned spells can actually be used. Resource and class-state assumptions are core gameplay rules, so this needs careful, targeted work rather than broad bypasses.

### 5. Stability And Persistence Hardening

Goal: reduce edge-case bugs after relog, death, reset, unlearn, or server restart.

Candidate work:

- Add more manual test cases for learn/unlearn/relog/reset/restart.
- Verify action bars after removing and re-adding spells/talents.
- Verify talent-granted spells across logout/login.
- Verify pets after stable, dismiss, call, abandon, and tame-new-pet flows.
- Monitor recurring duplicate `character_spell` log noise after the Dual Wield persistence fix.
- Audit hybrid-managed spells that teach class-restricted skill lines.

Why this matters: this project touches core assumptions in AzerothCore. Persistence bugs are the ones players notice most.

### 6. Addon Polish

Goal: keep the current lightweight addon-first approach but make it feel cleaner.

Candidate work:

- Better detail panel for selected spells/talents.
- Clearer point display and next-point progress.
- Better empty states for filters.
- Optional compact/dense view.
- Better visual distinction for known, available, locked, and unaffordable rows.
- Add optional suggested-pick helpers for new players, using lightweight curated tags such as melee, caster, pet, healing, survivability, weapon imbue, attack power, spell power, utility, and travel.
- Let suggested-pick helpers explain why an option may fit a build, without restricting free-pick behavior or trying to become a full automated build planner.
- Add a lightweight help/about panel with version and branch compatibility.

Why this matters: the addon is already useful. Small UI polish can make it feel intentional and approachable for non-developers.

Suggested-pick notes: free search and free-pick progression should remain the core design. A recommendation layer should be optional, transparent, and easy to ignore. The first version should probably be addon-side metadata and filters rather than server-side rules.

### 7. Playerbots Hybrid Awareness

Goal: eventually let bots interact better with the custom hybrid world.

Candidate work:

- Keep Playerbots roadmap separate for LFG/world behavior.
- Later, evaluate whether bots should learn or use hybrid spells.
- Start with diagnostics and passive compatibility before giving bots custom hybrid progression.
- Later, evaluate config-gated riding and flying skill grants for playerbots after player-facing Azeroth flying is stable.
- Evaluate a conservative ground/flying mount grant set for bots, preferably level-appropriate and faction-safe.
- Start with permission, skill, and mount availability only; avoid AI pathing or flight behavior changes until observation proves existing Playerbots movement can use it safely.
- Keep old-world bot flying behind a QA-only config flag and validate travel, stuck handling, combat, regroup, follow, and teleport recovery behavior.

Why this matters: bots already make the world feel alive. Hybrid-aware bots could be powerful, but it is a larger design problem and should wait until player progression is stable.

## QA Experiment Lanes

These are high-risk workstreams for `codex/hybrid-race-class-qa`. They should be validated in the isolated QA server/client workflow before any change is considered for `codex/hybrid-talents-ui`.

### 1. Any Race / Any Class

Goal: allow character creation and stable gameplay for unsupported race/class combinations without damaging normal class/race assumptions.

Current state: first smoke pass is successful in the isolated QA server/client lane. The server work is config-gated with `Hybrid.AllowAnyRaceClass`, and the disposable test client uses a reversible `patch-y.mpq` containing the current DBC proof of concept.

Implemented in QA:

- Server accepts unsupported race/class combinations only when the QA config flag is enabled.
- Missing player create definitions are synthesized from same-race and same-class data.
- Missing starter action sets are synthesized so class starter spells appear on the action bar.
- Known active racials are added to a free action slot during character creation.
- Starter gear falls back to a same-class outfit when no exact race/class/gender row exists.
- The disposable QA client exposes unsupported combinations through patched `CharBaseInfo.dbc`.
- The disposable QA client includes starter outfit DBC rows for unsupported race/class/gender combinations through patched `CharStartOutfit.dbc`.

Validated so far:

- Undead Hunter can be created, enters the world, receives starter spells/action bars/gear, levels naturally to 5, learns spells automatically, reaches level 20 through GM testing, selects Hunter talents, learns hybrid spells, tames a pet, and retains the pet through logout/login.
- Human Druid can be created, receives starter spells/action bars/gear, learns spells while leveling, reaches level 22 through GM testing, uses Bear Form and Cat Form successfully, defaults to Night Elf druid form models, learns Tame Beast through the hybrid system, and uses a tamed pet successfully.
- Gnome Shaman can be created, receives starter spells/action bars/gear, receives expected totem tools, uses totem mechanics successfully, and retains active Shaman spells such as Lightning Shield and Flametongue Weapon across logout/login.
- GM-assisted level jumps may require `.save` before logout for immediate persistence. Natural leveling should be confirmed further before adding any programmatic save behavior.

Investigation:

- Server-side race/class validation during character creation.
- `playercreateinfo`, starting positions, starting actions, starting spells, starting items, skills, factions, languages, and reputation.
- Login/load cleanup paths that may remove class-restricted spells, skills, pets, forms, or equipment proficiencies.
- Character creation restrictions in the 3.3.5a client.
- Whether server-only acceptance is enough for any test pair, or whether DBC/GlueXML changes are required.

Candidate work:

- Treat the current pet, form, and totem smoke coverage as enough to proceed to the next QA milestone.
- Continue natural playthrough validation opportunistically, especially around normal save timing, trainers, starter quests, language/faction/reputation behavior, equipment skill cleanup, battleground/LFG assumptions, and HybridTalentUI learn/unlearn flows.
- Keep deeper matrix testing as optional hardening rather than a blocker for reagent-free casting.
- Add focused follow-up tests only when a new change touches race/class creation, starter data, pets, forms, totems, action bars, or client DBC data.
- Keep any client edits confined to `C:\Games\WoW-3.3.5a-HD-Test`.

Why this matters: any-race/any-class support is central to class fantasy freedom, but it touches assumptions across both server and client.

### 2. Backported Cosmetics And Visuals

Goal: explore cosmetic-only visual customization for a WotLK 3.3.5a server/client workflow, including custom Druid form appearances, wings, class-fantasy auras, weapon visuals, and other Ascension-inspired presentation features where rights and provenance are clear.

Investigation:

- Which cosmetic effects can be achieved with existing WotLK spell, aura, display, item, or model data.
- Which later-expansion or custom cosmetic assets can realistically be backported into 3.3.5a-compatible formats.
- Wings, back attachments, glow effects, class-fantasy auras, weapon visuals, and cosmetic shapeshift/display auras.
- `SpellShapeshiftForm.dbc` rows for Bear, Dire Bear, and Cat.
- `CreatureDisplayInfo.dbc` and `CreatureModelData.dbc` display/model linkage.
- Existing WotLK druid form display IDs.
- Where TrinityCore/AzerothCore applies shapeshift model IDs.
- Whether form appearance in 3.3.5a is race, gender, hair, or skin dependent.
- Client patch requirements for M2, skin, BLP, DBC edits, and MPQ packaging.
- Whether cosmetic application should be managed through a future Hybrid UI cosmetics tab, server command, item, aura, or persisted character setting.

Candidate work:

- Start with a curated allowlist of existing WotLK cosmetic visuals before importing custom or later-expansion assets.
- Add a future optional Hybrid UI cosmetics tab for browsing, searching, applying, and removing approved cosmetics.
- Prototype with a known WotLK-compatible Legion/MoP druid form patch first.
- Verify the full pipeline in the disposable client: MPQ load order, DBC edits, model display, shapeshift behavior, combat animations, logout/login persistence, and failure recovery.
- Document the minimum DBC rows and file paths required for a clean patch.
- Replace known-compatible prototype assets with custom assets only after the pipeline is understood.
- Prefer config-gated server behavior if server-side shapeshift model selection needs adjustment.
- Keep all imported asset work limited to the disposable QA client until the patch pipeline is proven safe.

Risk: medium to high. Some cosmetic visuals are harmless, but many spells or displays carry gameplay effects, scripts, model assumptions, animation gaps, or client-format risks.

Why this matters: cosmetic progression can add a lot of class-fantasy flavor without changing combat balance, but backported visuals are mostly a client data and asset pipeline risk and may intersect with server-side aura, display, shapeshift, and persistence handling.

### 3. Targeted Ground AoE Usability

Goal: allow selected ground-targeted hybrid spells to cast at the current target's position instead of requiring manual ground targeting.

Current state: active in QA. Rain of Fire proved the required client/server pattern after an initial unsafe DBC attempt was corrected. The working approach keeps each spell's normal dynamic/destination effect behavior intact, but patches the disposable QA client's `Spell.dbc` so selected spell rows send a unit target. The QA server then uses the configured spell allowlist to snapshot the selected unit's position as the destination at cast start.

Scope:

- Apply only to explicit spell IDs listed in a QA config option.
- Limit the feature to player-facing spell families, not creatures, scripts, bots, engineering items, quest spells, or all destination-targeted spells globally.
- Keep normal ground-targeting behavior for every spell not explicitly configured and client-patched.

Current QA-tested pattern:

- Server feature flag: `Hybrid.TargetGroundAtTarget.Enable = 1`
- Server allowlist: `Hybrid.TargetGroundAtTarget.Spells`
- Client patch: disposable QA `patch-z.mpq` updates selected `Spell.dbc` rows to use `Targets = 2` while preserving original effect targeting such as `TARGET_DEST_DYNOBJ_ENEMY`.
- Validated proof of concept: Rain of Fire casts at the selected hostile target position without a ground-target prompt and ends normally when channeling ends.

Expanded QA spell-family scope now under test:

- Mage: Blizzard and Flamestrike.
- Warlock: Rain of Fire and Shadowfury.
- Hunter: Volley.
- Druid: Hurricane and Force of Nature.
- Death Knight: Death and Decay.
- Priest: Mass Dispel.

Special-case follow-up:

- Flare should probably not use hostile-target placement. Preferred future behavior is a separate caster-position path so Flare can drop at the player's feet without requiring an enemy target.
- Track this separately from enemy-targeted AoE, likely with a future config such as `Hybrid.TargetGroundAtCaster.Spells = "1543"`.

Investigation:

- Where AzerothCore handles ground-target spell cast requests and destination targets.
- How client cast validation behaves when a ground-target spell is triggered from server-side target position data.
- Whether the spell should cast at the selected target, target-of-target, or current hostile unit only.
- How line of sight, range, map, phase, transport, and indoor/outdoor checks behave with synthesized destination coordinates.
- Whether Playerbots, scripted boss spells, or spell scripts use the same path and could be affected.
- Whether each spell family should use enemy-target position, caster position, or remain manual ground-target only.

Candidate work:

- Continue testing the expanded player spell-family allowlist across multiple characters.
- Validate channeled spells, instant spells, persistent area auras, summoned ground effects, and triggered damage ticks separately.
- Confirm no-target, invalid-target, out-of-range, line-of-sight, dead target, moving target, and despawned target behavior.
- Remove or split out any spell that feels awkward with enemy-target placement, starting with Flare.
- Add a separate caster-position path only if the Flare use case stays desirable after more testing.
- Document the final client patch rows and server config together before considering promotion.

Risk: medium to high. Ground-target spells are a shared core mechanic, so this must stay narrow, opt-in, and covered by regression checks before any promotion.

Why this matters: this could make hybrid gameplay smoother for selected spells without requiring a broad client UI rewrite, but careless implementation could break normal targeting semantics.

### 4. Reagent-Free Casting

Goal: evaluate removing or bypassing reagent requirements for hybrid player spells to modernize gameplay and make hybrid/cross-class progression smoother.

Current state: the initial server/client proof of concept was successful, including Summon Voidwalker and Teleport: Stormwind casting without reagents and without reagent text in the client tooltip. The QA lane has now expanded this from a three-spell proof of concept to the full Hybrid learn-template spell surface.

Active QA config:

- `Hybrid.NoReagent.Enable = 1`
- `Hybrid.NoReagent.HybridTemplateSpells = 1`
- `Hybrid.NoReagent.Spells = "697,3561,10059"` remains as an additive explicit safety/test list.

Active QA scope: every spell currently listed in `hybrid_spell_template` is treated as reagent-free by the QA worldserver, including rank-chain handling where available. The current live QA database contains 530 Hybrid learn-template spell IDs.

Scope:

- Validate reagent-free behavior across the Hybrid learn-template spell surface.
- Keep the feature opt-in, config-gated, and reversible.
- Keep the default safety boundary around hybrid-learned/player class spells rather than globally bypassing reagents for every spell in the game.
- Treat non-template exceptions as explicit spell-list additions only after review.

Server-side investigation:

- Bypass reagent checks and reagent consumption for configured player-cast spells.
- Reuse the existing reagent-check path where possible so configured spells pass both cast validation and reagent consumption.
- Load the Hybrid learn-template spell surface from `hybrid_spell_template` when `Hybrid.NoReagent.HybridTemplateSpells` is enabled.
- Keep profession crafting, item-created spells, item-use spells, trade target items, and important economy/item mechanics protected.
- Add a config flag and spell list so the feature can be enabled, disabled, and rolled back cleanly.

Client-side investigation:

- Current QA `patch-z.mpq` includes a patched `Spell.dbc` that clears reagent fields for Hybrid learn-template spells exported from the QA database.
- Current DBC verification: 530 spell IDs were requested, 528 were present in the 3.3.5a client `Spell.dbc`, and all 528 present rows had reagent fields cleared. IDs `8681` and `26786` were not present in the client DBC.
- Keep addon tooltip cleanup as a fallback only for spells that cannot be handled cleanly through DBC patching.
- Continue using only `C:\Games\WoW-3.3.5a-HD-Test` for any tooltip, DBC, or MPQ experiments.

Candidate work:

- Revalidate the initial QA list: `697` Summon Voidwalker, `3561` Teleport: Stormwind, and `10059` Portal: Stormwind.
- Validate several additional reagent spells from different class families, especially Mage travel, Warlock utility/summons, Paladin blessings, Priest utility, Rogue poisons or utility, and any Shaman/Druid edge cases discovered during play.
- Confirm Hybrid learn-template spells cast without reagents and do not consume reagents if reagents are present.
- Confirm non-template reagent spells still require and consume reagents normally unless explicitly configured.
- Confirm crafting, profession, item-created, and item-use spell behavior is unchanged.
- Document whether the feature should eventually be promoted to `codex/hybrid-talents-ui`, kept QA-only, or abandoned.

Risk: medium. Player spell reagent removal is narrower than global spell targeting changes, but careless implementation could affect crafting, item sinks, economy assumptions, or client/server expectation mismatches.

Why this matters: reagent friction is often at odds with solo hybrid gameplay, especially for cross-class utility spells learned outside their original class progression.


### 5. Weapon Imbue And Poison Reapply Reminder

Goal: make temporary weapon enchants easier to maintain by visually reminding the player when Shaman imbues or Rogue poisons are missing or close to expiring.

Preferred first approach: addon/client-side detection in Hybrid Talent UI, without changing server spell mechanics.

Current state: Shaman weapon imbue reminders are implemented and validated in QA for main hand, off hand, and mixed imbue use cases. The addon remembers the last imbue used per hand, supports independent reminder buttons, avoids startup false positives, and keeps off-hand reminders visible while main-hand reminders are resolved.

Scope:

- Shaman weapon imbues such as Flametongue Weapon, Rockbiter Weapon, Windfury Weapon, Frostbrand Weapon, and Earthliving Weapon are the proven first scope.
- Add Rogue poisons next, including main-hand and off-hand state where possible.
- Focus on temporary weapon enchants first, because normal buffs are already easier to solve with WeakAuras.
- Keep the reminder optional and easy to disable through addon settings or a QA feature flag.

Investigation:

- Use WotLK client APIs such as `GetWeaponEnchantInfo()` to detect main-hand and off-hand temporary enchant state and expiration timing.
- Map known imbue and poison spells to the appropriate weapon slot expectations.
- Determine whether the addon can locate matching spells on standard action bars and trigger a visible glow, pulse, or overlay.
- Evaluate whether a compact fallback reminder icon near the Hybrid UI is more reliable than action-button glow for custom bars or missing action slots.

Candidate work:

- Treat Shaman imbues as the validated baseline and continue playtesting during normal Shaman leveling.
- Add Rogue poisons after a Rogue or poison-using hybrid test character is ready.
- Revisit action-bar glow only if the standalone reminder buttons feel insufficient.
- Avoid server changes unless the client API cannot reliably detect the needed state.
- Later expand to any other temporary weapon enchant families that matter for hybrid play.

Risk: low to medium. This should be mostly addon-side, but action-bar glow behavior can be fragile across default bars, custom bars, stances, paging, dual wield, and temporary enchant edge cases.

Why this matters: weapon imbues and poisons are important class-fantasy maintenance spells, but they are harder to track with WeakAuras in WotLK than normal buffs.

### 6. Azeroth Flying Unlock

Goal: evaluate allowing flying mounts in Eastern Kingdoms and Kalimdor, similar to later expansions, to make old-world traversal smoother for solo hybrid play.

Preferred first approach: server-side, config-gated QA experiment with no client patching unless testing proves the client needs help.

Current state: Azeroth flying is implemented and working in the isolated QA server/client lane. The QA client patch removes the Outland/Northrend-only tooltip restriction for tested flying mounts, and the QA server allows old-world flying through the configured experiment path.

Scope:

- Add a feature flag such as `Hybrid.AllowAzerothFlying = 0/1`, defaulted off outside QA.
- Enable only in the isolated QA server while testing.
- Limit the first pass to player-controlled characters.
- Preserve existing Outland and Northrend flying behavior.
- Keep battlegrounds, arenas, instances, transports, taxi paths, scripted movement, and special no-fly areas protected.

Investigation:

- Find where AzerothCore blocks flying by map, area, aura, mount, or movement flags.
- Determine whether a server-only map/area restriction relaxation is enough for the WotLK client.
- Check anti-cheat, movement validation, logout/login, fall state, death/ghost behavior, and mounted aura persistence.
- Identify old-world terrain, city boundary, fatigue, water, transport, and exploration edge cases that may make this unsafe for broader promotion.

Candidate work:

- Continue playtesting old-world flying during normal leveling and travel.
- Test zone transitions, hearth/teleport, death/ghost state, dismounting, landing, swimming, and logout/login while mounted or airborne.
- Confirm old-world taxi paths, boats, zeppelins, battlegrounds, and instances still behave normally.
- Later, evaluate playerbot riding/flying support only after player-controlled Azeroth flying is stable; keep bots out of the first validation pass.
- Keep all changes reversible through config and document whether this should stay QA-only, become an optional dev feature, or be abandoned.

Risk: medium to high. The client may render old-world flying movement, but pre-Cataclysm Azeroth was not built for player flight and may expose terrain holes, invisible walls, exploration gaps, or movement-validation assumptions.

Why this matters: old-world traversal can be a major solo-play friction point, and a reversible QA feature could make hybrid leveling feel more modern without changing core class mechanics.

### 7. Companion Auto-Loot / Lootbot QoL

Goal: evaluate an Ascension-inspired quality-of-life helper where an active non-combat companion/minipet can automatically loot nearby eligible creature corpses for the player.

Current state: implemented and playtest-stable in QA. The feature is server-side, config-gated, requires an active non-combat companion by default, and does not require client MPQ patching.

Scope:

- Require an active player non-combat companion/minipet before auto-looting starts.
- Limit the first pass to nearby creature corpses the player is already eligible to loot.
- Run out of combat only, with a short radius and a modest scan interval.
- Support grouped bot play through normal loot eligibility checks while avoiding auto-claim of protected roll/master-loot threshold items.
- Protect boss loot, bind prompts, profession gathering, skinning, mining, herb nodes, chests, and item-created mechanics.
- Keep all behavior disabled unless a QA config flag is enabled.

Validation:

- Confirmed minipet-triggered looting works during normal play.
- Confirmed multiple nearby corpses are looted one at a time.
- Confirmed the helper keeps working when the visual companion is resting or away from the corpse, because the radius is anchored to the player.
- Confirmed grouped bot play can be supported without disabling the helper.

Remaining watch items:

- Quest item drops.
- Full bags.
- Uncommon/rare roll-threshold loot in groups.
- Named mobs and dungeon/boss loot.

Candidate work:

- Add config such as `Hybrid.CompanionAutoLoot.Enable = 0`, `Hybrid.CompanionAutoLoot.Radius = 10`, and `Hybrid.CompanionAutoLoot.OutOfCombatOnly = 1`.
- Prototype with one conservative trigger, preferably an active controlled pet or companion-style summon.
- Add debug logging or player chat feedback while QA testing so skipped corpses are understandable.
- Validate during normal leveling with inventory near-full, quest drops active, pet dismissed/summoned, logout/login, mounts, flight paths, and party/bot nearby scenarios.
- Decide after playtesting whether to keep it as a built-in QoL feature, tie it to a custom lootbot item/cosmetic, or defer it.

Risk: medium. Loot is core gameplay and economy behavior, so the prototype must avoid bypassing ownership, group loot, quest handling, item prompts, and special corpse/container mechanics.

Why this matters: solo hybrid play produces a lot of small corpse-looting friction, and a safe companion loot helper could make leveling feel smoother without changing combat balance.

## Later Experiments

These are interesting but higher risk. They should not be mixed into normal incremental work. Any experiment in this section should start in the QA lane unless it is explicitly reclassified as normal development work.

### Native Talent Tree Rule Removal

Potential value: more Ascension-like talent freedom in the native talent UI.

Risk:

- Native talent rules are assumed by both client and server.
- Breaking dual spec, normal class talents, resets, or bot assumptions would be easy.

Current preference:

- Continue treating hybrid talents as a separate addon/server progression layer.
- Consider native talent frame changes only after the custom hybrid talent system is mature.

### Larger Ascension-Style UI Rewrite

Potential value: richer spellbook/talent-tree style experience.

Risk:

- Larger UI work can become fragile, especially on the 3.3.5a client.
- Current addon-first list UI is lightweight and stable.

Current preference:

- Keep improving the current addon until a concrete limitation justifies a larger rewrite.
- If we start a large UI rewrite, consider creating a separate branch.

### Playerbot Riding And Azeroth Flying

Potential value: make the QA world feel more alive by allowing playerbots to learn riding/flying skills and use selected mount spells, especially if old-world flying remains part of the hybrid experience.

Risk:

- Granting skills and mount spells is relatively contained, but bot movement, stuck handling, follow behavior, combat behavior, and regroup logic may not understand freeform old-world flying.
- Bots using flying mounts in pre-Cataclysm Azeroth could expose terrain, navigation, and pathing assumptions faster than player-only testing.
- A broad bot change could affect server performance or make debugging player-facing flight issues harder.

Current preference:

- Defer until the player-facing Azeroth flying lane has more playthrough validation.
- If explored, start with a QA-only config flag that grants level-appropriate riding skills and a small mount list, with no AI pathing changes in the first pass.
- Treat actual bot flight behavior as a separate higher-risk investigation after simple skill/mount availability proves harmless.

### Original Hybrid Synergy And Enchant System

Potential value: create deeper buildcraft, similar in spirit to Ascension-style classless synergy, while keeping the design original to this project.

Candidate direction:

- Add curated build tags such as melee, caster, pet, dot, burst, sustain, healing, shield, weapon imbue, poison, holy, fire, frost, nature, shadow, rage, energy, and mana.
- Tune selected talents so they support hybrid builds instead of assuming a pure original class context.
- Explore an original "hybrid enchant" or "mystic enchant-inspired" module that grants build-defining passive effects through custom items, auras, account unlocks, or Hybrid UI selections.
- Use broad gameplay inspiration only. Do not copy third-party database rows, text, icons, assets, or exact effect packages.
- Start with a small hand-authored proof of concept rather than importing a large ruleset.

Risk:

- Deeper synergy systems can quickly become balance-heavy and hard to explain.
- Imported or copied data/assets would create legal, provenance, and support concerns.
- Passive effects may interact with spell scripts, auras, pets, and item procs in surprising ways.

Current preference:

- Keep this as a later-stage QA design lane until baseline hybrid spell/talent usability, multi-resource support, persistence, and class dependency packages are more stable.
- If we pursue it seriously, consider a separate planning chat or branch so the large design work does not obscure active QA bug fixing.

## Suggested Next Iterations

Recommended order for the next few work sessions:

1. **Roadmap and documentation refresh**
   Keep current/future state accurate as QA findings move from prototype to validation. Current refresh should capture description search, Shaman imbue reminders, dependency action-bar persistence, Azeroth flying, and the cosmetics/backport research lane.

2. **QA any-race/any-class validation pass**
   First smoke pass is successful across pet, form, and totem paths. Keep natural playthrough validation running opportunistically, but do not block the next QA milestone on more race/class combinations.

3. **Rogue poison reminder expansion**
   Extend the proven Shaman imbue reminder model to Rogue poisons once a Rogue or poison-using hybrid character is ready for focused testing.

4. **Hybrid UI suggested-pick helpers**
   Add optional curated tags and recommendation hints so new players can discover useful spell/talent synergies without losing free-pick freedom.

5. **Expanded reagent-free casting validation**
   Validate the expanded Hybrid learn-template scope across multiple class families, and confirm profession, crafting, item-created, and item-use reagent behavior remains protected.

6. **Companion auto-loot validation**
   Continue playthrough validation for quest drops, full bags, grouped loot, named mobs, dungeon loot, and the player-priority grouped-loot QA option.

7. **Azeroth flying validation**
   Continue old-world flying validation during normal play, especially movement, map, transport, death, logout/login, and protected-zone behavior.

8. **Hybrid progression balance pass**
   Review point gain, costs, unlock pacing, and early-level feel.

9. **Multi-resource hybrid support pass**
   Validate whether learned abilities that require energy, rage, combo points, runic power, stance, form, weapon, or pet state are usable on cross-class builds, starting with concrete examples such as Sinister Strike on non-Rogue classes.

10. **Targeted Ground AoE usability validation**
   Rain of Fire proved the working client/server pattern. Continue testing the expanded player spell-family allowlist, and split Flare into a separate caster-position follow-up if enemy-target placement feels wrong.

11. **Talent UI clarity pass**
   Improve learned rank, dependency, and locked-state messaging.

12. **Class dependency package pass**
   Pick one class fantasy after Hunter pets and make it complete end to end.

13. **Backported cosmetics research**
   Start with existing WotLK-safe visuals and asset pipeline documentation before importing later-expansion/custom assets.

14. **Persistence/log cleanup pass**
   Reduce recurring log noise and harden action-bar/spell restoration edge cases.

15. **Playerbot riding/flying research**
   Revisit after existing QA items and player-facing Azeroth flying validation. Start with config-gated riding skill and mount availability before considering any bot AI movement changes.

16. **Original hybrid synergy/enchant planning**
   Explore original Ascension-inspired buildcraft concepts after the safer resource, dependency, and persistence work is stable.

## Manual Test Checklist

Use this after meaningful Hybrid changes:

- New character reaches level 10 and receives/display points correctly.
- Learn a spell, relog, and confirm it remains known.
- Unlearn a spell and confirm points refund.
- Remove a learned spell from the action bar, relog, and confirm it is not forcibly re-added.
- Learn a talent, relog, and confirm rank/state persists.
- Unlearn a talent and confirm points refund.
- Test a talent-granted active spell on the action bar.
- Test known/available/locked filters.
- Test Tame Beast, Call Pet, Dismiss Pet, pet action bar, pet spellbook tab, and autocast if pet code changed.
- Test selected self-buffs with pet and group member nearby if buff code changed.
- Restart worldserver and repeat one spell, one talent, and one pet persistence check.

## Promotion Rule

New work should stay on `codex/hybrid-talents-ui` until:

- The branch builds cleanly.
- Dev server setup/rebuild path is known.
- The feature has been tested in game.
- Known regressions are documented or fixed.
- The stable source branch has a backup point if the promotion is large.
- Changes are reviewed through a controlled PR into `main`.

## Reference Policy

Project Ascension and similar projects may be used for high-level interaction inspiration only.

Do not copy proprietary code, art, modified Blizzard UI files, packed client data, or private-server-specific assets unless reuse rights are clear. Build our own addon, server protocol, SQL, and documentation so the project remains portable and maintainable.
