# Hybrid Talent System Roadmap

This is the living roadmap for the Hybrid spell/talent project. It tracks what is already live, what is being validated through play, and what we may build next on `codex/hybrid-talents-ui` before another promotion to `main`.

## Branch And Environment Model

- Stable source branch: `main`
- Active development branch: `codex/hybrid-talents-ui`
- Stable WSL server: `~/wow-server-playerbots-hybrid`
- Development WSL server: `~/wow-server-playerbots-hybrid-dev`
- Stable client example: `C:\Games\WoW-3.3.5a-HD`
- Development client example: `C:\Games\WoW-3.3.5a-HD-Dev`
- Disposable client experiment copy: `C:\Games\WoW-3.3.5a-HD-Test`

Use `main` for stable source and production deployment. Use `codex/hybrid-talents-ui` for new work. Client-side experiments should happen only in the disposable test client until proven safe.

## Current State

Status after PR #1 promotion to `main` and resync of `codex/hybrid-talents-ui`:

| Area | State | Notes |
|---|---|---|
| Addon-first Hybrid UI | Live | `HybridTalentUI` provides the primary spell/talent interface with a movable launcher button and `/hybridui`. |
| Spell browsing | Live | Class filters, search, availability filters, icons, native tooltips, known/available/locked states, learn, and unlearn are working. |
| Spell persistence | Live | Learned hybrid spells persist through relog and restart, upgrade to best rank where configured, and action bars are preserved where possible. |
| Talent browsing | Live | Talents can be browsed by class, show native descriptions/tooltips, and use separate hybrid talent points. |
| Talent learning | Live | Hybrid talents can be learned/unlearned, persist through relog, allow free picks across trees without native tree point requirements, and support dependency checks such as requiring Charge before Improved Charge. |
| Talent UI clarity | In progress | Talent rows, details, and chat feedback are being improved to show next rank, max-rank state, locked reasons, and free-pick rules more clearly. |
| Progression clarity | Live | The addon shows when the next spell point and next talent point will be earned during leveling. |
| Progression balance | Playtesting | Current defaults are playable, but point cadence, costs, level gates, and long-term leveling feel still need more character progression data. |
| Hunter pet support | Live | Tame Beast works for hybrid characters, grants the required pet toolkit, supports pet persistence, pet action bar restoration, pet spellbook tab, and autocast persistence. |
| Buff mirroring | Live | Selected self-cast buff families can mirror to active pets and nearby group members. |
| Legacy trainer/beacon | Retired | Hybrid Talent Master and Hybrid Talent Beacon are disabled on this path. Hybrid progression is addon-first. |
| Profession Master | Live | Profession Master remains NPC/beacon based and is not retired. |
| Playerbots support | Live separately | Playerbot population, LFG, role, and social tuning are tracked in `docs/PLAYERBOTS_IMPROVEMENT_ROADMAP.md`. |
| Client race/class unlocks | Not started | Requires isolated client testing and likely DBC/GlueXML work. Do not patch the dev client directly. |

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
- Added stance requirement relaxation for selected Warrior abilities only: Charge, Intercept, Overpower, Mocking Blow, Revenge, Disarm, Shield Wall, Retaliation, Recklessness, Berserker Rage, Pummel, and Whirlwind.

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
- Add dependency rules through `HybridTalentSystem.SpellDependencyGrants` where possible.

Why this matters: Tame Beast showed that one iconic spell often needs a supporting kit. Other class fantasies may need similar packages.

### 4. Stability And Persistence Hardening

Goal: reduce edge-case bugs after relog, death, reset, unlearn, or server restart.

Candidate work:

- Add more manual test cases for learn/unlearn/relog/reset/restart.
- Verify action bars after removing and re-adding spells/talents.
- Verify talent-granted spells across logout/login.
- Verify pets after stable, dismiss, call, abandon, and tame-new-pet flows.
- Reduce recurring duplicate `character_spell` log noise where safe.
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

## Later Experiments

These are interesting but higher risk. They should not be mixed into normal incremental work.

### Any Race / Any Class

Potential value: complete class fantasy freedom at character creation.

Known layers:

- Server layer: `playercreateinfo`, starting spells, skills, actions, class/race validation, and cleanup logic.
- Client layer: character creation UI likely requires DBC and/or GlueXML changes. Normal addons do not run on the character creation screen.

Safety rule:

- Use `C:\Games\WoW-3.3.5a-HD-Test` only.
- Start with one race/class pair, not every combination.
- Do not patch the dev client until the test client is proven recoverable.

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
   Keep current/future state accurate so new work starts from a shared understanding.

2. **Hybrid progression balance pass**
   Review point gain, costs, unlock pacing, and early-level feel.

3. **Talent UI clarity pass**
   Improve learned rank, dependency, and locked-state messaging.

4. **Class dependency package pass**
   Pick one class fantasy after Hunter pets and make it complete end to end.

5. **Persistence/log cleanup pass**
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
