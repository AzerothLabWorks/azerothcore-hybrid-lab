# Profession Master

Adds an NPC-driven profession helper for local AzerothCore WotLK servers.

Default NPC:

- Entry: `190020`
- Name: `Artisan Nexus-Weaver`
- Subname: `Profession Master`
- ScriptName: `npc_profession_master`

The NPC can:

- Teach every primary and secondary profession.
- Increase known profession skill in configurable steps.
- Learn profession abilities and recipes available at the player's current skill.
- Optionally bypass the normal two-primary-profession limit.
- Grant a beacon item that summons a temporary Profession Master near the player.
- Grant a separate vendor beacon item that summons a temporary neutral vendor near the player.

Install with:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install professionmaster
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-profession-master
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

After the rebuild, spawn the NPC where you want it:

```text
.npc add 190020
```

The world SQL also creates item `3500`, `Profession Master Beacon`, with `ScriptName` set to `item_profession_master_beacon`.

By default, the module grants the item to players on login. Using the item summons a temporary Profession Master near the player. Temporary trainers show a `Dismiss summoned trainer` gossip option.

## Traveling Vendor Beacon

The module also creates a QA convenience vendor:

- NPC entry: `190021`
- Name: `Mira Packwhistle`
- Subname: `Traveling Vendor`
- ScriptName: `npc_profession_vendor`
- Item entry: `3501`
- Item name: `Traveling Vendor Beacon`
- Item ScriptName: `item_profession_vendor_beacon`

By default, players receive item `3501` on login. Using it summons a temporary neutral vendor near the player for selling and basic supplies, using the same general vendor stock as NPC `12959`. The summoned vendor includes a gossip option to browse goods and a dismiss option for the summoning player.

This is intended to replace risky `.npc add` / `.npc delete` vendor macros during QA play.

If the database row exists but `.npc add 190020` says the creature does not exist, verify that the model row exists and restart `ac-worldserver`:

```bash
docker exec -it ac-database sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world -e "
SELECT *
FROM creature_template_model
WHERE CreatureID = 190020;
"'
```
