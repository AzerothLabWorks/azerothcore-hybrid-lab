# Playerbots Improvement Roadmap

This roadmap keeps native Playerbot AI responsible for gameplay decisions while improving reliability, observability, and social presence around it.

## Current State

Status for branch `codex/hybrid-talents-ui`:

| Area | State | Notes |
|---|---|---|
| Bot population | Live | Playerbots profile configures 1500 online random bots and aligns Docker overrides so container environment does not cap the value lower than `playerbots.conf`. |
| Leveling density | Live | Random bots start at level 15 and their maximum random level follows online player levels to improve leveling dungeon availability. |
| LFG participation | Live | Random bot LFG participation is enabled, summon-on-group is enabled, and bots are biased toward tank/healer-capable specs for healthier role coverage. |
| LFG proposal reliability | Live | Bots no longer explicitly decline LFG proposals only because they are in combat or dead. |
| LFG teleport watchdog | Live, validating | Bots in an active LFG dungeon group retry the native `lfg teleport` action when they accepted but remain outside the dungeon. Added after a Ragefire Chasm partial-entry reproduction. |
| Social chatter | Live | Random bot talk and broadcasts remain enabled so zones feel active. Repeated nearby-player hello emotes are disabled to reduce chat noise. |
| Ranked 3v3 seed config | Live, needs level-80 validation | Rated 3v3 bot participation is conservatively seeded for the level 80 bracket. Queue-time diagnostics still need more real playtest data. |
| Diagnostics | Live | `diagnose-playerbots-lfg` and `diagnose-playerbots-pvp` helpers are available through `scripts/manage-wow-modules.sh`. |

Recent player validation:

- Deadmines LFG formed successfully, bots entered, and dungeon gameplay was smooth.
- Wailing Caverns LFG popped quickly after the population and role-distribution changes.
- Ragefire Chasm reproduced a partial-entry case before the teleport watchdog was added; this is the main regression scenario to retest.
- Barrens/Crossroads felt much more populated with 1500 bots and active General chat.

## End State

Build a Living Server layer for the Playerbots profile:

- Bots reliably join, enter, recover from, and finish normal leveling/dungeon flows across Vanilla, Burning Crusade, and Wrath of the Lich King.
- Bots explain important state changes without spamming the player.
- Bots use native text, broadcast, and event hooks for personality and server culture.
- Any future LLM use is limited to controlled text/content generation unless a later experiment proves it can safely cooperate with native Playerbot AI.

## Iteration 1: LFG Reliability Baseline

The first practical target is dungeon entry reliability across the full 1-80 dungeon progression, especially when using LFG.

Status: live on `codex/hybrid-talents-ui`, still expanding dungeon coverage. After the population, role distribution, and LFG proposal changes, Deadmines formed through LFG, all bots ported in, and dungeon gameplay was reported as smooth. Wailing Caverns also popped quickly during progression testing. Ragefire Chasm later reproduced a partial-entry case where two bots joined the LFG group but stayed outside until vote-kicked, so the LFG teleport watchdog has been implemented and should be retested against that scenario. General chat activity increased enough to make the server feel more alive.

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
- Docker override alignment so container environment does not cap bots below `playerbots.conf`
- random bot levels start at 15 and sync their maximum level to online players for leveling-dungeon density
- random bot LFG participation
- PvP auto-join and conservative rated 3v3 seeding for level 80 arena queues
- instance strategy application
- summon-on-group
- role-biased tank/healer specs for dungeon queues
- quiet greetings: nearby-player greet emotes disabled to avoid chat floods
- random bot talk
- broadcasts

The current Playerbots patches improve LFG reliability in two places:

- bots no longer explicitly decline LFG proposals just because they are in combat or dead
- bots in an active LFG dungeon group retry the native LFG teleport action when they are still outside the dungeon

Together these target the two observed failure modes: one questing bot collapsing the proposal for the whole group, and bots accepting the group but not zoning in.

The current setup also biases random bot specs toward dungeon viability:

- warrior: more protection tanks
- paladin: more holy/protection, fewer retribution
- priest: more discipline/holy, fewer shadow
- death knight: modestly more blood tanks
- shaman: more restoration healers
- druid: more bear/restoration, fewer balance/cat

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

Current evidence:

- Deadmines: queue formed, bots zoned in, and gameplay was smooth.
- Wailing Caverns: queue was effectively instant after bot population and role distribution changes.
- Ragefire Chasm: queue formed and the player teleported in, but two bots stayed outside. Added the LFG teleport watchdog for the next validation pass.
- Crossroads/Barrens: high bot population and General chat made the zone feel alive, but greet emotes were noisy. Setup now keeps General chat/broadcasts enabled while disabling the repeated nearby-player hello emote.
- Continue smoke testing Vanilla, Burning Crusade, and Wrath dungeons to confirm the watchdog resolves partial-entry cases.

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

## Iteration 2: LFG Watchdog

Status: live on `codex/hybrid-talents-ui`, validating across more dungeon queues.

The current native watchdog in `mod-playerbots`:

- watches bots that are in an LFG group whose bot or group state is already `LFG_STATE_DUNGEON`
- skips bots that are dead, in combat, in a battleground/arena, already teleporting, or already inside a dungeon map
- retries the existing native `lfg teleport` action every 10 seconds while the bot remains outside

Next watchdog improvements if needed:

- Avoid retrying while a bot is taxiing or being removed from world if that proves noisy in logs.
- Tell the master a short reason when retry is blocked.
- Add diagnostics that show which group members are outside after teleport retry.

## Iteration 3: Ranked 3v3 Arena Reliability

The next PvP target is reducing long ranked 3v3 queue times.

Status: configuration is live, but gameplay validation is still pending.

Current conservative setup:

- enables random bot BG/arena participation
- enables bot auto-joining for BG/arena queues
- uses rated arena bracket `14`, the level 80 bracket
- seeds `2` rated 3v3 matches
- increases random bot 3v3 arena teams from `10` to `40`

Important notes:

- Playerbots config says lower-level arena brackets require custom code changes, so start with level 80 ranked 3v3.
- Arena teams are created when bots are initialized on server restart. Existing servers may need a bot arena-team reset/reinit if team counts were already generated with the old value.
- Keep initial rated 3v3 match count conservative to avoid over-creating arena instances.

Next diagnostics to add:

- active rated 3v3 queue count
- 3v3 bot arena team count
- eligible level 80 captains online
- rated arena bot/player counts by bracket
- average queue time before first pop

After a ranked 3v3 test, run:

```bash
cd ~/azerothcore-hybrid-lab-dev
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-pvp
```

Optional knobs:

```bash
PLAYERBOTS_PVP_LOG_SINCE=90m PLAYERBOTS_PVP_LOG_LINES=400 \
  ./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid-dev diagnose-playerbots-pvp
```

Capture these details when reproducing:

- player level and whether the queue is rated 3v3
- queue wait time before first pop
- whether the player has a valid 3v3 team and captain state
- whether any bot teams enter rated 3v3
- whether bots are already tied up in other arenas/BGs
- whether the issue is no pop, late pop, failed accept, or failed arena entry

## Iteration 4: Social Explanation Layer

Status: planned. Basic social chatter is live through Playerbots text/broadcast systems, but targeted explanation messages are not implemented yet.

Add event-driven messages for real friction points:

- "I am still in combat, trying to zone in after this."
- "I accepted the queue, waiting on teleport."
- "I am outside the instance, retrying."
- "I cannot enter while dead."
- "I need a summon."

These should use `PlayerbotTextMgr` text keys and probability/rate limits.

## Iteration 5: Personality And Memory

Status: planned for later after dungeon and PvP reliability are stable.

After reliability is stable:

- Add personality tags that select different text pools.
- Add lightweight relationship memory for repeated grouping, dungeon clears, wipes, trades, and resurrection.
- Keep combat, pathing, questing, and dungeon strategy deterministic unless explicitly testing a separate branch.
