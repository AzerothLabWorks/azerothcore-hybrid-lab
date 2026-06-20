# Startup QoL

Grants a configurable starter package to brand-new characters on first login.

Default package:

- Riding spells: `33388`, `33391`, `34090`, `34091`, `54197`
- Mount spells: `58983`, `61425`, `17229`, `72808`, `60021`, `69395`, `60002`, `40192`
- Four `Gigantique Bags` (`23162`)
- `20000` gold
- All weapon proficiencies
- All armor proficiencies

Install with:

```bash
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid install startupqol
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid setup-startup-qol
./scripts/manage-wow-modules.sh --server-dir ~/wow-server-playerbots-hybrid rebuild
```

The package is granted by AzerothCore's first-login player hook, so existing
characters are not modified retroactively.
