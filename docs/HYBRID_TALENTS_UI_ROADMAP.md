# Hybrid Talents UI Roadmap

This document tracks the first development objectives for the `codex/hybrid-talents-ui` branch. The intent is to keep higher-risk spell, talent, UI, and server work isolated from `main` until it has been tested on a separate development server.

## Branch Scope

- Stable branch: `main`
- Development branch: `codex/hybrid-talents-ui`
- Stable Windows checkout: `C:\Users\User\OneDrive\Documents\Wow Modules\wow-hybrid-server-lab`
- Development Windows checkout: `C:\Users\User\OneDrive\Documents\Wow Modules\wow-hybrid-server-lab-dev`
- Stable WSL server: `~/wow-server-playerbots-hybrid`
- Planned development WSL server: `~/wow-server-playerbots-hybrid-dev`

All work in this roadmap should happen on `codex/hybrid-talents-ui` first.

## Objectives

### 1. Custom Hybrid Spell And Talent UI

Build an Ascension-inspired in-game UI for browsing, learning, and unlearning cross-class spells and eventually talents.

The first useful version should support:

- Class tabs or filters.
- Spell lists by class.
- Search or simple filtering.
- Spell icons, names, ranks, and descriptions.
- Known, available, locked, and unlearnable states.
- Learn and unlearn actions.
- Server-side validation for every action.

The UI should be implemented as our own addon/server integration. The Ascension client can be used as a reference for broad interaction ideas, but proprietary code, art, modified Blizzard files, or packed client assets should not be copied into this project unless their license clearly allows reuse.

### 2. Talent Count Restriction Removal

Allow players to select talents without requiring the normal deep investment path through a single tree.

This needs careful scoping because native WotLK talent rules are enforced by both server behavior and client UI assumptions. Initial development should prefer a separate hybrid talent layer represented by learned spells or passive auras, rather than immediately patching the native talent frame.

Initial goals:

- Identify where the current server enforces talent prerequisites and row requirements.
- Decide whether to bypass native requirements globally or only for the hybrid system.
- Avoid breaking normal class talent resets, dual spec behavior, or bot/player expectations.

### 3. Hunter Dependency Learning

When a character learns key Hunter spells such as `Tame Beast`, automatically grant required supporting spells, skills, or passive dependencies needed for the feature to work.

Initial target:

- Learning `Tame Beast` should grant the required Hunter pet-management toolkit.
- Unlearning should be safe and should not remove unrelated spells the player legitimately has.
- Dependency grants should be data-driven where possible, not hardcoded only for one spell.

## Recommended Phase Order

### Phase 1: Development Server And Safety Harness

- Create or confirm WSL checkout for `codex/hybrid-talents-ui`.
- Create or confirm `~/wow-server-playerbots-hybrid-dev`.
- Ensure deploy scripts can install/rebuild the dev branch without touching the stable server.
- Add a small manual test checklist for learning, unlearning, reset, relog, and server restart behavior.

### Phase 2: Spell UI Foundation

- Build a first custom addon window for the existing hybrid spell system.
- Keep server authority in the module.
- Reuse existing spell data and descriptions already available from the server/client where possible.
- Support learning and unlearning spells before attempting full talent browsing.

### Phase 3: Dependency Learning

- Add a data-driven dependency table for spells that require bundled supporting spells.
- Implement Hunter `Tame Beast` as the first real dependency case.
- Test learn, unlearn, relog, reset, and class edge cases.

### Phase 4: Hybrid Talent Browsing

- Add talent browsing to the custom UI.
- Treat talents as a separate hybrid progression layer first.
- Only consider native talent-tree rule removal after the custom layer is stable.

### Phase 5: Native Talent Rule Changes

- Investigate server and client behavior around normal talent prerequisites.
- Prototype on the development branch only.
- Merge to `main` only after focused testing confirms native character progression is not destabilized.

## Ascension Client Reference Decision

Local Ascension files were found under:

`C:\MetaPC_Data\MetaPain_Backup\Project Ascension\Ascension Launcher\resources\client\Interface\AddOns`

The folder contains normal addons, Blizzard UI folders, and an old trainer UI folder. It does not appear to expose an obvious standalone reusable Ascension talent-picker addon by name.

Project rule:

- We can inspect behavior and high-level UX concepts.
- We should build our own addon and server protocol.
- We should not copy Ascension-specific code, art, modified Blizzard UI files, packed client data, or proprietary assets into this repository unless reuse rights are clear.

This keeps the project clean, portable, and safe to maintain in GitHub.

## Merge Rule

Nothing from this roadmap should be merged into `main` until:

- The development branch builds cleanly.
- The dev server deploy path is known.
- New behavior is tested in game.
- Regressions against current stable hybrid trainer behavior are checked.
- The changes are reviewed through a controlled merge or PR.
