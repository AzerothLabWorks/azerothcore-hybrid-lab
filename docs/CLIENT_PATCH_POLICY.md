# Client Patch Policy

This repository may document client-side experiments that are useful for a private WotLK 3.3.5a QA workflow, but it does not distribute Blizzard client files or client-derived binary patch archives.

## Current Position

- Client MPQ patches are local QA artifacts only.
- Do not commit generated `*.mpq` files to this repository.
- Do not publish or attach Blizzard client assets, extracted DBCs, models, textures, sounds, GlueXML, or other proprietary client data.
- Use only a disposable test client for client-side experiments.

The current QA test client path is:

```text
C:\Games\WoW-3.3.5a-HD-Test
```

## What Can Be Documented

It is acceptable to document the engineering surface for reproducibility and future promotion decisions, including:

- Which client tables or files were investigated.
- Which server features require matching client behavior.
- Which spell IDs, DBC columns, or high-level records were adjusted during local testing.
- How to safely install a locally generated patch into a disposable client.
- How to back up, remove, or replace local patch files.

## What Should Stay Out Of Git

Keep these out of the public repository:

- Generated MPQ patch files.
- Extracted client DBC files.
- Blizzard model, texture, sound, interface, or other game asset files.
- Full client archives or links to client downloads.

## QA Features With Local Client Patch Dependencies

The QA branch currently tracks several experiments that may require a local client patch to match server behavior:

- Any race / any class character creation DBC support.
- Unsupported race/class starter outfit DBC support.
- Reagent tooltip cleanup for reagent-free hybrid spells.
- Azeroth flying tooltip and client-side mount restriction cleanup.
- Selected Warrior stance tooltip/client data cleanup.

These are documented so the work can be understood and reproduced by someone using their own legally obtained client copy. The patch binaries themselves should remain local unless a separate private distribution decision is made with the related IP risk understood.

## Future Installer Guidance

If an installer is added later, it should:

- Refuse to install into the normal development or production client by default.
- Require an explicit disposable client path.
- Back up any existing patch file before replacing it.
- Explain that the user must generate or provide their own local patch files.
- Avoid downloading or bundling Blizzard client-derived assets.
