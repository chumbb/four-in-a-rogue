# Claude Code handoff — Four in a Rogue

**Owner:** Sean Bishop · **Repo:** https://github.com/chumbb/four-in-a-rogue · **Engine:** Godot 4.3+

Read **`CLAUDE.md`** at repo root too (Claude Code loads it automatically). **Design docs live in Obsidian**, not in this repo.

---

## Session startup (Sean’s PC)

```powershell
cd $HOME\four-in-a-rogue
# Branch: upright-board or main — match Sean’s active work
claude
```

**Before coding:**

1. **Obsidian** open → vault **`C:\Users\Sean\Documents\GameDev`**
2. **Local REST API** plugin enabled (for MCP)
3. First time only: approve **obsidian** MCP when Claude prompts
4. Project **`.mcp.json`** in repo root (gitignored) — already configured like Cursor

**Read design via MCP or files:**

- Canonical v0.1 rules: `Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md`
- Full GDD: `Projects/Four-in-a-Rogue/Design/GDD.md`
- Vault agent rules: `GameDev/CLAUDE.md`

**Conflict rule:** Obsidian vault wins over repo `CLAUDE.md` for game design.

---

## Kickoff prompt (paste each session)

```text
You are coding Four in a Rogue (Godot 4.3+) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md (MCP or path on disk).
3. Implement the next incomplete milestone (currently M2 — board core).
4. One milestone only; small commits; match existing GDScript style.
5. Do not invent mechanics or add scope (no shop, runs, new Goobs).
6. When done: exact F5 playtest steps for Sean, then stop.

If a design rule is missing, ask Sean — do not guess.
```

---

## Current focus

| Milestone | Status | Deliverable |
|-----------|--------|-------------|
| M1 Shell | Done | Menu → Strange Man → coin flip → scenario placeholder |
| **M2 Board core** | **Next** | `BoardState` drop/win, column input, full-column UX, view sync |
| M3–M6 | Queued | See `CLAUDE.md` §Milestones |

### M2 acceptance (short)

- `BoardState.drop(col, owner)`, `column_full`, `find_winner()`
- Mouse column pick; shake + SFX + toast on full column
- Isometric view reflects grid (quads/Sprite3D OK)
- **Test:** F5 → scenario → gravity works; 4-in-a-row detected

---

## Repo layout (code)

```
scripts/rules/board_state.gd   # extend for M2
scripts/core/game_flow.gd      # scene flow only
scenes/board/board_view_3d.tscn
resources/goobs/, starter_deck.json
```

Presentation: isometric 3D board, 2D sprites later; **player blue, enemy red**; mouse only; 1920×1080.

---

## Locked v0.1 summary (implement exactly)

- 7×6 grid; connect-4 win; land → effect → win check last
- Deck: 21 cards (18 vanilla + 3 specials); draw 1 / play 1; hand max 10; start 3
- Draw stalemate → replay scenario; skip Strange Man; re-flip coin
- Invalid column: full = shake + error + toast; blocked = “A Goob stops you from playing here”

Full detail: vault **vertical-slice-v0.1.md**.

---

## Out of scope

Multi-scenario runs, shop, meta, saves, mobile, new Goob types, non–7×6 boards — unless Sean explicitly asks.

---

## Tooling reference

| Tool | Role |
|------|------|
| **Claude Code** | Implementation in this repo |
| **Obsidian MCP** | Read/write design markdown in GameDev vault |
| **Cursor** | Same repo + `four-in-a-rogue.code-workspace` |
| **Godot** | F5 from `project.godot` |

MCP setup notes: `docs/CLAUDE_CODE_MCP.md`

---

## Git

- Remote: `https://github.com/chumbb/four-in-a-rogue`
- Commit messages: `M2: <short description>`
- Do not commit `.mcp.json` or secrets

---

*Last updated: 2026-11-02*
