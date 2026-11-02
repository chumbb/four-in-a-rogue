# Design lives in your global GameDev vault (Plan B)

**Do not store canonical design in this repo.**

Sean’s **source of truth** is one Obsidian vault for all games:

```text
C:\Users\Sean\Documents\GameDev\
├── CLAUDE.md
├── Projects/
│   └── Four-in-a-Rogue/
│       ├── Four-in-a-Rogue.md
│       └── Design/
│           ├── GDD.md
│           └── vertical-slice-v0.1.md
└── +Inbox/
```

## One-time setup

1. Create that folder (or your preferred path).
2. Copy the seed from Project Context: [GameDev vault seed](/cursor/stores/self/docs/templates/GameDev-vault-seed) into `GameDev\`.
3. Obsidian → **Open folder as vault** → select `GameDev`.
4. In Cursor: **File → Add Folder to Workspace** → add `GameDev` next to `four-in-a-rogue`, or edit `four-in-a-rogue.code-workspace` (see repo) with your vault path.

## Agents

- **Cursor / Claude Code:** Read and write markdown under `GameDev/Projects/...` using the full path on your machine.
- Repo `CLAUDE.md` documents the same paths; **vault wins** on any conflict.

This `design-vault/` folder exists only as a pointer; it may be removed from git in a future commit.
