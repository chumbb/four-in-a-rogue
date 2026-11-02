# Game design vault (Obsidian)

This folder is the **source of truth** for all game design documentation for repos that link here (starting with **Four in a Rogue**).

## Open in Obsidian

1. Obsidian → **Open folder as vault**
2. Select this folder: `four-in-a-rogue/design-vault` (full path on your machine)

Do not use the Godot repo root as the vault unless you add a separate vault config—keep design isolated for clarity and token use.

## Cursor + Claude Code

- Open the **Godot repo root** in Cursor (`four-in-a-rogue/`). Agents read and write `design-vault/**/*.md` as normal files.
- Optional: add `.mcp.json` from repo root (see `.mcp.json.example`) if you want Obsidian Local REST API tools while the app is open.
- **Rule:** When design changes, edit markdown **here first**, then update code/repo `CLAUDE.md` if implementation summary needs to match.

## Layout

```text
design-vault/
├── CLAUDE.md                 # AI rules for this vault
├── Projects/
│   └── Four-in-a-Rogue/
│       ├── Four-in-a-Rogue.md
│       └── Design/           # GDD, vertical slice, decisions
└── +Inbox/                   # quick capture (optional)
```

Future games: add `Projects/<Other-Game>/`.
