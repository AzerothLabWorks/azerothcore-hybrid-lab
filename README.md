# WoW Hybrid Server Lab

Personal AzerothCore lab for building a WotLK 3.3.5a private server with optional module profiles and a custom Hybrid Talent System.

This repo owns the custom work:

- `modules/mod-hybrid-talent-system`
- WSL2/Docker installer scripts
- Module management scripts
- Documentation and example configuration

It does not vendor the full AzerothCore source tree. Installer scripts clone the upstream server source that matches the selected profile.

## Profiles

- `base`: Standard AzerothCore.
- `playerbots`: Playerbot fork plus `mod-playerbots`.
- `npcbots`: NPCBots fork.

Custom modules require a source build. Fast prebuilt Docker images are useful for a clean first install, but they cannot include local custom C++ modules like the Hybrid Talent System.

## Quick Start

Inside Ubuntu/WSL2:

```bash
git clone <your-github-repo-url> ~/wow-hybrid-server-lab
cd ~/wow-hybrid-server-lab
chmod +x scripts/*.sh
./scripts/install-wow-hybrid.sh
```

After installation, use:

```bash
./scripts/manage-wow-modules.sh list
./scripts/manage-wow-modules.sh install hybrid
./scripts/manage-wow-modules.sh rebuild
```

## Current Status

The repo is scaffolded locally. The installer and module manager are first-pass scripts intended for WSL2 Ubuntu and Docker Compose. They are designed to be readable and adjustable before we run them against your live virtual server.

## References

- AzerothCore: https://github.com/azerothcore/azerothcore-wotlk
- AzerothCore Docker: https://github.com/azerothcore/acore-docker
- Playerbots fork: https://github.com/mod-playerbots/azerothcore-wotlk
- Playerbots module: https://github.com/mod-playerbots/mod-playerbots
- NPCBots fork: https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots
- Dad's MMO Lab installer inspiration: https://github.com/DadsMmoLab/dads-mmo-lab
