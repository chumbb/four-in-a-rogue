# Claude Code handoff — Four in a Rogue

**Owner:** Sean Bishop · **Repo:** https://github.com/chumbb/four-in-a-rogue · **Engine:** Godot 4.6.3 (only)

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
You are coding Four in a Rogue (Godot 4.6.3) in this repo.

1. Read CLAUDE.md and docs/CLAUDE_CODE_HANDOFF.md.
2. Read v0.1 rules from Obsidian: Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md (MCP or path on disk).
3. Implement the next incomplete milestone (currently M3 — turn loop).
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
| M2 Board core | Done (merged to `main`) | `BoardState` drop/win/outcome, mouse column picking, full-column UX, view sync, headless tests |
| Upright 3D board | Branch `upright-board` — awaiting Sean's playtest | Real-game upright board; physics-ready frame (layer `board_frame`) |
| **M3 Turn loop** | **Next** | Alternate sides after coin flip; win/lose overlay → Title; draw replay flag path |
| M4–M6 | Queued | See `CLAUDE.md` §Milestones |

### M3 acceptance (short)

- Alternate sides after the coin flip; end on win/lose; overlay → Title via `GameFlow`
- Draw replay via `GameFlow.replay_after_draw()` (straight to coin flip, skips Strange Man)
- **Test:** full win/lose returns to title; draw retry skips Strange Man

### Decided by Sean (2026-11-01, Claude session)

- Destroyed Goob: pieces above fall (`BoardState.destroy_cell`)
- Both sides connect four on the same play: draw (`BoardState.Outcome.DRAW`)
- Enemy red, player blue
- Scenario starts as soon as the coin flip is decided (M3)
- Upright 3D board; Goobs with physics, 3D effects and play animations; hand shown like Hearthstone / Slay the Spire
- All of the above are recorded in the vault `vertical-slice-v0.1.md` (2026-11-01 history rows)

---

## Repo layout (code)

```
scripts/rules/board_state.gd   # grid truth (M2 done)
scripts/core/game_flow.gd      # scene flow only
scenes/board/board_view_3d.tscn
resources/goobs/, starter_deck.json
```

Presentation: flat iso board on `main`; upright 3D board on branch `upright-board`; **player blue, enemy red**; mouse only; 1920×1080.

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
- Commit messages: `M3: <short description>`
- Editor toolbar **Git: [branch] [Sync]** (addon `git_sync`) switches branch + pulls from inside Godot
- Headless tests: `godot --headless -s res://tests/<file>.gd` (all in `tests/`)
- Do not commit `.mcp.json` or secrets

---

*Last updated: 2026-11-02*
