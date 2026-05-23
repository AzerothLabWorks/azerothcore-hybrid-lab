# GitHub Repo Setup

Create a new GitHub repository, for example:

```text
wow-hybrid-server-lab
```

Recommended visibility:

- Private while experimenting.
- Public later if you want to share installer scripts or the module.

After creating the empty GitHub repo, run these commands from Windows PowerShell in this local repo:

```powershell
cd "C:\Users\rcart\OneDrive\Documents\Wow Modules\wow-hybrid-server-lab"
git remote add origin https://github.com/YOUR_USER/wow-hybrid-server-lab.git
git branch -M main
git push -u origin main
```

If GitHub asks you to authenticate, use Git Credential Manager or a personal access token.

## Repo Strategy

Keep this repo focused on your custom layer:

- scripts
- docs
- module source
- example config
- Docker Compose overrides

Do not commit full AzerothCore checkouts, database dumps, client files, logs, or built binaries.
