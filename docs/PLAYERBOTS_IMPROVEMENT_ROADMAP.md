# Playerbots Improvement Roadmap

This roadmap keeps native Playerbot AI responsible for gameplay decisions while improving reliability, observability, and social presence around it.

## End State

Build a Living Server layer for the Playerbots profile:

- Bots reliably join, enter, recover from, and finish normal leveling/dungeon flows across Vanilla, Burning Crusade, and Wrath of the Lich King.
- Bots explain important state changes without spamming the player.
- Bots use native text, broadcast, and event hooks for personality and server culture.
- Any future LLM use is limited to controlled text/content generation unless a later experiment proves it can safely cooperate with native Playerbot AI.

## Iteration 1: LFG Reliability Baseline

The first practical target is dungeon entry reliability across the full 1-80 dungeon progression, especially when using LFG.

### Setup

Run this after installing `mod-playerbots`:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev apply-playerbots-patches
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev setup-playerbots
cd ~/wow-server-playerbots-hybrid-dev
docker compose up -d --build ac-worldserver
```

The setup command now writes `playerbots.conf` and explicitly enables:

- random bot autologin
- 1500 configured online random bots
- random bot LFG participation
- instance strategy application
- summon-on-group
- greetings
- random bot talk
- broadcasts

The current Playerbots patch prevents bots from explicitly declining LFG proposals just because they are in combat or dead. This targets failed dungeon pops where one questing bot collapses the proposal for the whole group.

### Diagnostics

After a failed LFG/dungeon entry attempt, run:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-lfg
```

Optional knobs:

```bash
PLAYERBOTS_LFG_LOG_SINCE=90m PLAYERBOTS_LFG_LOG_LINES=400 \
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-lfg
```

Capture these details when reproducing:

- dungeon name and expansion bucket: Vanilla, Burning Crusade, or Wrath
- bot names, classes, and levels
- whether bots were in combat, dead, mounted, taxiing, trading, looting, or pathing
- whether LFG role check and proposal appeared to complete
- whether bots accepted but stayed outside
- whether bots entered late, after combat ended, or after summon/reinvite
- whether the issue affects all bots or specific roles/classes

### Progression Coverage

Track dungeon entry, role check, teleport, follow behavior, boss strategy, wipe recovery, and final completion for each expansion bucket.

Start with representative smoke tests:

| Bucket | Level Bands | First Smoke Tests | What To Watch |
|---|---:|---|---|
| Vanilla | 15-60 | Ragefire Chasm, Deadmines, Scarlet Monastery, Zul'Farrak, Blackrock Depths, Stratholme | early LFG eligibility, long travel/summon behavior, multi-wing dungeon handling |
| Burning Crusade | 60-70 | Hellfire Ramparts, Blood Furnace, Slave Pens, Sethekk Halls, Shadow Labyrinth, Mechanar | Outland map transitions, heroic/normal confusion, bots accepting but staying outside |
| Wrath | 70-80 | Utgarde Keep, Nexus, Azjol-Nerub, Drak'Tharon Keep, Halls of Lightning, Forge of Souls | Northrend teleport behavior, role check reliability, implemented instance strategies |

Then expand to a completion checklist for every leveling dungeon:

- **Vanilla:** Ragefire Chasm, Wailing Caverns, Deadmines, Shadowfang Keep, Blackfathom Deeps, Stockade, Gnomeregan, Razorfen Kraul, Scarlet Monastery wings, Razorfen Downs, Uldaman, Zul'Farrak, Maraudon wings, Sunken Temple, Blackrock Depths, Lower Blackrock Spire, Dire Maul wings, Scholomance, Stratholme.
- **Burning Crusade:** Hellfire Ramparts, Blood Furnace, Slave Pens, Underbog, Mana-Tombs, Auchenai Crypts, Sethekk Halls, Old Hillsbrad Foothills, Shadow Labyrinth, Steamvault, Shattered Halls, Botanica, Mechanar, Arcatraz, Black Morass, Magisters' Terrace.
- **Wrath:** Utgarde Keep, Nexus, Azjol-Nerub, Ahn'kahet, Drak'Tharon Keep, Violet Hold, Gundrak, Halls of Stone, Halls of Lightning, Oculus, Culling of Stratholme, Utgarde Pinnacle, Trial of the Champion, Forge of Souls, Pit of Saron, Halls of Reflection.

For each dungeon, record:

- queue formed
- role check completed
- all bots zoned in
- bots followed from entrance
- first boss killed
- wipe recovery works
- final boss killed
- bots leave/requeue cleanly

## Iteration 2: LFG Watchdog Design

If diagnostics confirm bots now accept LFG but still fail to enter, add a native watchdog in `mod-playerbots`:

- Track a pending dungeon proposal/teleport state per bot.
- Retry LFG teleport if the bot is outside the instance after a short delay.
- Avoid retrying while the bot is in combat, taxiing, teleporting, or being removed from world.
- Tell the master a short reason when retry is blocked.
- Clear the pending state once the bot is inside the expected map or leaves the group.

## Iteration 3: Social Explanation Layer

Add event-driven messages for real friction points:

- "I am still in combat, trying to zone in after this."
- "I accepted the queue, waiting on teleport."
- "I am outside the instance, retrying."
- "I cannot enter while dead."
- "I need a summon."

These should use `PlayerbotTextMgr` text keys and probability/rate limits.

## Iteration 4: Personality And Memory

After reliability is stable:

- Add personality tags that select different text pools.
- Add lightweight relationship memory for repeated grouping, dungeon clears, wipes, trades, and resurrection.
- Keep combat, pathing, questing, and dungeon strategy deterministic unless explicitly testing a separate branch.
