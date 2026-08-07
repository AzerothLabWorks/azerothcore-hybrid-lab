# Hybrid Talent UI

Hybrid Talent UI is a WotLK 3.3.5a addon for the AzerothCore Hybrid Lab development branch. It provides an addon-first interface for cross-class spell and talent browsing, learning, and unlearning.

This addon is designed for:

```text
AzerothLabWorks/azerothcore-hybrid-lab
branch: codex/hybrid-race-class-qa
```

## Install

Copy the `HybridTalentUI` folder into your WoW 3.3.5a client:

```text
World of Warcraft 3.3.5a\Interface\AddOns\HybridTalentUI
```

Example Windows path:

```text
C:\Games\WoW-3.3.5a-HD-Test\Interface\AddOns\HybridTalentUI
```

Then restart WoW, or reload the UI, and enable `Hybrid Talent UI` from the AddOns button on the character select screen.

## Server Requirement

The addon requires the Hybrid Talent System server module from the Hybrid Lab dev branch. It will not work on a normal AzerothCore server unless that server has the matching module, SQL, and core patches installed.

Recommended dev setup repo:

```text
https://github.com/AzerothLabWorks/azerothcore-hybrid-lab/tree/codex/hybrid-race-class-qa
```

## Use

Open it in game with:

```text
/hybridui
```

The addon also creates a movable Hybrid launcher button near the microbar. Left-click it to open or close the Hybrid Training window.

## Current Features

- Spell and talent tabs in one interface.
- Class browsing for Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock, and Druid.
- Spell and talent icons with native tooltip descriptions.
- Search and availability filters.
- Left-click to learn supported hybrid spells and talents.
- Right-click to unlearn supported hybrid spells and talents.
- Known filter support for learned hybrid spells/talents.
- Action-bar preservation for learned hybrid spells and talent-granted spells.
- Weapon effect reminders for main-hand and off-hand temporary weapon enchants, including Shaman imbues and Rogue poisons.
- Movable Hybrid Resources frame showing Mana, Rage, and Energy together for multi-resource builds.

## Hybrid Resources

The QA addon can show a movable three-bar resource frame for hybrid characters that use more than one resource type. This helps rage-primary or energy-primary characters manage hidden mana, and mana-primary characters manage rage or energy abilities.

Useful commands:

- `/hyui resources` shows resource frame status.
- `/hyui resources on` enables the frame.
- `/hyui resources off` hides the frame.
- `/hyui resources reset` restores the default frame position.

## Weapon Effect Reminder

The QA addon can remember the last supported Shaman imbue or Rogue poison the player cast and show separate movable `MH` and `OH` reminder buttons when the main-hand or off-hand temporary enchant is missing or close to expiring. The buttons use client-side `GetWeaponEnchantInfo()` state and do not change server spell validation.

Tested shaman imbues:

- Rockbiter Weapon
- Flametongue Weapon
- Frostbrand Weapon
- Windfury Weapon
- Earthliving Weapon

Tested or targeted Rogue poisons:

- Instant Poison
- Deadly Poison
- Crippling Poison
- Mind-numbing Poison
- Wound Poison
- Anesthetic Poison

Useful commands:

- `/hyui weapon`, `/hyui imbue`, or `/hyui poison` shows reminder status.
- `/hyui weapon on` enables reminders.
- `/hyui weapon off` disables reminders.
- `/hyui weapon reset` clears remembered weapon effects and saved reminder positions.
- `/hyui weapon threshold <seconds>` changes the low-duration reminder threshold.

The `imbue` and `poison` command aliases support the same `on`, `off`, `reset`, `debug`, and `threshold` subcommands.

## Spell Descriptions

The addon prefers curated server descriptions when available. If the server sends an imported trainer fallback such as `Paladin - Trainer` or `Priest - Trainer`, the addon uses the native client spell tooltip description. Full descriptions remain searchable and visible in the detail panel, while list rows use a compact one-line summary to keep the browser readable.

## Notes

Hybrid point totals, spell availability, talent availability, dependency checks, learning, unlearning, refunds, and persistence are handled server-side by the Hybrid Talent System module. The addon is the client interface for that server support.
