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
| Spell browsing | Live | Class filters, search, availability filters, icons, native tooltips, known/available/locked states, learn, and unlearn are working. |
| Spell persistence | Live | Learned hybrid spells persist through relog and restart, upgrade to best rank where configured, and action bars are preserved where possible. |
| Talent browsing | Live | Talents can be browsed by class, show native descriptions/tooltips, and use separate hybrid talent points. |
| Talent learning | Live | Hybrid talents can be learned/unlearned, persist through relog, allow free picks across trees without native tree point requirements, and support dependency checks such as requiring Charge before Improved Charge. |
| Talent UI clarity | In progress | Talent rows, details, and chat feedback show next rank, max-rank state, locked reasons, and free-pick rules more clearly. |
| Progression clarity | Live | The addon shows when the next spell point and next talent point will be earned during leveling. |
| Progression balance | Playtesting | Current defaults are playable, but point cadence, costs, level gates, and long-term leveling feel still need more character progression data. |
| Hunter pet support | Live | Tame Beast works for hybrid characters, grants the required pet toolkit, supports pet persistence, pet action bar restoration, pet spellbook tab, and autocast persistence. |
| Buff mirroring | Live | Selected self-cast buff families can mirror to active pets and nearby group members. |
| Class dependency packages | In progress | Hunter pet support is live. Warlock demon summons now grant Drain Soul support, Shaman totem spells automatically grant required Earth, Fire, Water, and Air totem tools from spell data, and Rogue Stealth/Poisons now grant starter utility support. Hybrid totems also use faction-safe fallback models when a non-Shaman race has no native totem model. |
| Equipment skill persistence | Live | Hybrid weapon/armor skills and Dual Wield are allowed to persist across class restrictions, reducing repeated login cleanup and duplicate spell-save noise. |
| Legacy trainer/beacon | Retired | Hybrid Talent Master and Hybrid Talent Beacon are disabled on this path. Hybrid progression is addon-first. |
| Profession Master | Live | Profession Master remains NPC/beacon based and is not retired. |
| Playerbots support | Live separately | Playerbot population, LFG, role, and social tuning are tracked in `docs/PLAYERBOTS_IMPROVEMENT_ROADMAP.md`. |
| QA race/class unlocks | First smoke pass successful | `Hybrid.AllowAnyRaceClass` is active on the isolated QA server. Undead Hunter, Human Druid, and Gnome Shaman have passed initial gameplay smoke routes covering pets, shapeshifts, totems, starter spells, action bars, gear, and logout/login retention. |
| QA client asset experiments | Active in disposable QA client | `C:\Games\WoW-3.3.5a-HD-Test\Data\patch-y.mpq` currently carries reversible `CharBaseInfo.dbc` and `CharStartOutfit.dbc` edits for the any-race/any-class prototype. |

## Completed Milestones

### Foundation

- Created isolated development branch and dev server workflow.
- Added safer stable/dev install paths and documentation.
- Added module management commands for install, SQL import, setup, rebuild, diagnostics, and addon install.
- Promoted the first stable development cycle to `main` through PR #1.

### Hybrid UI

- Built custom addon-first spell UI.
- Added class filters, search, status filters, pagination, icons, and native tooltips.
- Added known spell filtering across all classes.
- Added talent browsing and learning views.
- Added movable Hybrid launcher button near the microbar.
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

### 4. Stability And Persistence Hardening

Goal: reduce edge-case bugs after relog, death, reset, unlearn, or server restart.

Candidate work:

- Add more manual test cases for learn/unlearn/relog/reset/restart.
- Verify action bars after removing and re-adding spells/talents.
- Verify talent-granted spells across logout/login.
- Verify pets after stable, dismiss, call, abandon, and tame-new-pet flows.
- Monitor recurring duplicate `character_spell` log noise after the Dual Wield persistence fix.
- Audit hybrid-managed spells that teach class-restricted skill lines.

Why this matters: this project touches core assumptions in AzerothCore. Persistence bugs are the ones players notice most.

### 5. Addon Polish

Goal: keep the current lightweight addon-first approach but make it feel cleaner.

Candidate work:

- Better detail panel for selected spells/talents.
- Clearer point display and next-point progress.
- Better empty states for filters.
- Optional compact/dense view.
- Better visual distinction for known, available, locked, and unaffordable rows.
- Add a lightweight help/about panel with version and branch compatibility.

Why this matters: the addon is already useful. Small UI polish can make it feel intentional and approachable for non-developers.

### 6. Playerbots Hybrid Awareness

Goal: eventually let bots interact better with the custom hybrid world.

Candidate work:

- Keep Playerbots roadmap separate for LFG/world behavior.
- Later, evaluate whether bots should learn or use hybrid spells.
- Start with diagnostics and passive compatibility before giving bots custom hybrid progression.

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

### 2. Custom Druid Form Appearances

Goal: add custom Bear and Cat form appearances to a WotLK 3.3.5a server/client workflow, beginning with known-compatible form patches and later swapping in custom Ascension-inspired assets where rights and provenance are clear.

Investigation:

- `SpellShapeshiftForm.dbc` rows for Bear, Dire Bear, and Cat.
- `CreatureDisplayInfo.dbc` and `CreatureModelData.dbc` display/model linkage.
- Existing WotLK druid form display IDs.
- Where TrinityCore/AzerothCore applies shapeshift model IDs.
- Whether form appearance in 3.3.5a is race, gender, hair, or skin dependent.
- Client patch requirements for M2, skin, BLP, DBC edits, and MPQ packaging.

Candidate work:

- Prototype with a known WotLK-compatible Legion/MoP druid form patch first.
- Verify the full pipeline in the disposable client: MPQ load order, DBC edits, model display, shapeshift behavior, combat animations, logout/login persistence, and failure recovery.
- Document the minimum DBC rows and file paths required for a clean patch.
- Replace known-compatible prototype assets with custom assets only after the pipeline is understood.
- Prefer config-gated server behavior if server-side shapeshift model selection needs adjustment.

Why this matters: shapeshift appearance work is mostly a client data and asset pipeline risk, but it intersects with server-side form handling and class fantasy polish.

### 3. Targeted Ground AoE Usability

Goal: allow selected ground-targeted hybrid spells to cast at the current target's position instead of requiring manual ground targeting.

Scope:

- Start with one proof-of-concept spell, probably Rain of Fire.
- Apply only to explicit spell IDs listed in a QA config option.
- Limit the first pass to player-cast hybrid spells, not creatures, scripts, bots, or all ground-targeted spells globally.

Investigation:

- Where AzerothCore handles ground-target spell cast requests and destination targets.
- How client cast validation behaves when a ground-target spell is triggered from server-side target position data.
- Whether the spell should cast at the selected target, target-of-target, or current hostile unit only.
- How line of sight, range, map, phase, transport, and indoor/outdoor checks behave with synthesized destination coordinates.
- Whether Playerbots, scripted boss spells, or spell scripts use the same path and could be affected.

Candidate work:

- Add an opt-in config such as `Hybrid.TargetedGroundAoe.Spells = 5740`.
- Convert the selected unit target position into a destination only for configured spell IDs.
- Preserve normal ground-targeting behavior for every spell not explicitly configured.
- Add logging or debug feedback during QA so misfires are easy to diagnose.
- Build manual tests for normal Rain of Fire casting, configured target-position casting, no-target failure, invalid-target failure, line-of-sight/range failure, bot casting, and scripted ground AoE spells.

Risk: medium to high. Ground-target spells are a shared core mechanic, so this must stay narrow, opt-in, and covered by regression checks before any promotion.

Why this matters: this could make hybrid gameplay smoother for selected spells without requiring a broad client UI rewrite, but careless implementation could break normal targeting semantics.

### 4. Reagent-Free Casting

Goal: evaluate removing or bypassing reagent requirements for selected player spells to modernize gameplay and make hybrid/cross-class progression smoother.

Current state: server-side proof of concept is deployed on the isolated QA server. The active QA config enables `Hybrid.NoReagent.Enable = 1` with `Hybrid.NoReagent.Spells = "688,10059"` for initial testing: Summon Imp and Portal: Stormwind.

Scope:

- Start with a small proof-of-concept spell set, preferably one Warlock spell and one Mage, Paladin, or Priest utility spell.
- Test server-side cast behavior before attempting any client tooltip cleanup.
- Keep the first pass opt-in and limited to explicit spell IDs.
- Consider whether the final scope should apply only to hybrid-learned spells or to all player class spells where reagent removal is safe.

Server-side investigation:

- Bypass reagent checks and reagent consumption for selected player-cast spells.
- Reuse the existing reagent-check path where possible so configured spells pass both cast validation and reagent consumption.
- Keep profession crafting, item-created spells, item-use spells, trade target items, and important economy/item mechanics protected.
- Add a config flag and spell list so the feature can be enabled, disabled, and rolled back cleanly.

Client-side investigation:

- Determine whether reagent text can be hidden through addon tooltip cleanup.
- Identify whether full client cleanup requires DBC edits, MPQ patching, or both.
- Use only `C:\Games\WoW-3.3.5a-HD-Test` for any tooltip, DBC, or MPQ experiments.

Candidate work:

- Validate the initial QA list: `688` Summon Imp and `10059` Portal: Stormwind.
- Confirm configured spells cast without reagents and do not consume reagents if reagents are present.
- Confirm unconfigured reagent spells still require and consume reagents normally.
- Confirm crafting, profession, item-created, and item-use spell behavior is unchanged.
- Document whether the feature should eventually be promoted to `codex/hybrid-talents-ui`, kept QA-only, or abandoned.

Risk: medium. Player spell reagent removal is narrower than global spell targeting changes, but careless implementation could affect crafting, item sinks, economy assumptions, or client/server expectation mismatches.

Why this matters: reagent friction is often at odds with solo hybrid gameplay, especially for cross-class utility spells learned outside their original class progression.

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

## Suggested Next Iterations

Recommended order for the next few work sessions:

1. **Roadmap and documentation refresh**
   Keep current/future state accurate as QA findings move from prototype to validation.

2. **QA any-race/any-class validation pass**
   First smoke pass is successful across pet, form, and totem paths. Keep natural playthrough validation running opportunistically, but do not block the next QA milestone on more race/class combinations.

3. **Reagent-free casting proof of concept**
   Start a narrow, config-gated server-side test for selected player spells, then evaluate tooltip/client cleanup only after cast behavior is proven safe.

4. **Hybrid progression balance pass**
   Review point gain, costs, unlock pacing, and early-level feel.

5. **Talent UI clarity pass**
   Improve learned rank, dependency, and locked-state messaging.

6. **Class dependency package pass**
   Pick one class fantasy after Hunter pets and make it complete end to end.

7. **Persistence/log cleanup pass**
   Reduce recurring log noise and harden action-bar/spell restoration edge cases.

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
