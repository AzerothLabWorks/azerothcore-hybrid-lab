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
