# Four in a Rogue — solo dev + Claude Code

**Sean Bishop** · Godot **4.6.3** (develop and test on this version only) · https://github.com/chumbb/four-in-a-rogue

Roguelike Connect 4 with deck Goobs. **You are the only programmer.** Implement **one milestone per session**, playtest in Godot, commit, stop. **Do not invent mechanics** — if a rule is missing, ask Sean.

---

## Design source of truth (global GameDev Obsidian vault)

| What | Where (Sean’s machine) |
|------|-------------------------|
| **Vault root (all games)** | `C:\Users\Sean\Documents\GameDev\` |
| **v0.1 locked rules (canonical)** | `...\GameDev\Projects\Four-in-a-Rogue\Design\vertical-slice-v0.1.md` |
| **Full-game GDD** | `...\GameDev\Projects\Four-in-a-Rogue\Design\GDD.md` |
| **Vault AI rules** | `...\GameDev\CLAUDE.md` |

**Conflict rule:** If this file disagrees with the vault, **the vault wins**. After changing design in Obsidian, update §Locked rules here if needed.

**Cursor:** Open `four-in-a-rogue.code-workspace` (repo + GameDev vault).

**Claude Code + Obsidian MCP:** Project `.mcp.json` in repo root (gitignored; matches Cursor). Run `claude` from repo root; approve **obsidian** MCP once. Keep **Obsidian open** on GameDev. Setup/troubleshooting: `docs/CLAUDE_CODE_MCP.md`. Session handoff: `docs/CLAUDE_CODE_HANDOFF.md`.

**Seed vault once:** copy everything from `docs/game-dev-vault-seed/` into your `GameDev` folder.

**Record everything in the vault (Sean, 2026-11-02):** every Claude and Cursor session stores its work in the GameDev vault, during the session:
- Session summary → `Projects/Four-in-a-Rogue/Session-Logs/YYYY-MM-DD <Claude|Cursor> - <topic>.md`
- Decisions Sean makes → append to `Projects/Four-in-a-Rogue/Decisions/Decision-Log.md`; if a rule changed, update the vault spec and §Locked rules here
- Research / findings → `Projects/Four-in-a-Rogue/Research/<title>.md`
- Read the latest session log and decision log before starting. Local `claude` uses the Obsidian MCP; Claude app sessions use folder access to the vault; Cursor follows `.cursor/rules/obsidian-vault.mdc`.

---

## Start here (copy into Claude Code)

```text
Repo: four-in-a-rogue. Read CLAUDE.md, then GameDev vault vertical-slice-v0.1.md (path in §Design source of truth) for rules.

Implement the next incomplete milestone (currently M3). Rules: vault slice spec + §Locked rules below.
Small diff, match existing GDScript style, no new scope. When done: what to press in F5 to verify, then stop.
```

| Now | Next |
|-----|------|
| **M2** board core ✅ + **upright 3D board** ✅ (both on `main`, playtested 2026-11-02) | **M3** turn loop — plan: `docs/plans/m3-turn-loop.md` |
| Open `project.godot` → **F5** | Expected today: menu → Strange Man → coin flip → scenario with M2 test harness on the upright board (left click = blue/player, right click = red/enemy) |

---

## How we work (solo)

1. **One milestone** (M2…M6) per session unless Sean says otherwise.
2. **Playtest before the next milestone** — F5, mouse only, full flow for that milestone.
3. **Small commits** — e.g. `M2: BoardState drop and win check`. No drive-by refactors.
   **Push every commit/merge right away** — never leave local-only commits; Git Sync in Godot only fast-forwards (Sean, 2026-11-02).
4. **Logic first** — `BoardState` / rules scripts before polish; 3D view follows grid state.
5. **No design drift** — no shop, runs, new Goobs, or “nice to have” unless Sean asks.
6. **Stuck on design?** Ask Sean (see §Ask Sean). Stuck on Godot? Fix with docs; don’t change rules.

---

## Locked rules (v0.1 — do not change)

Full acceptance list: **§Ship checklist** (A1–A8) and vault `vertical-slice-v0.1.md`. Summary below for fast coding sessions.

### Flow

- Boot → Title → **Strange Man** (dialogue below) → **Coin flip** (player picks heads/tails) → Scenario.
- **Clicking the start menu counts as Press Start** (mouse only). Strange Man plays **after every Press Start** (portrait: old man in Goob-land clothes holding one Goob). No separate tutorial.
- Coin winner moves first (`GameFlow.player_moves_first`). **Scenario begins as soon as the flip is decided** (no extra start button).
- Win or lose → scoring sequence → **Title**. **Draw** (no four, or both sides four) → no scoring sequence, skip Strange Man (`GameFlow.skip_strange_man_on_next_run = true`), coin flip again, reshuffle decks, hand size 3, empty board.

**Strange Man (exact):**

> Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...

### Board & turns

| Rule | Value |
|------|--------|
| Grid | 7×6, empty at start |
| Drop | Column → lowest empty cell |
| Win | 4 in a row (H/V/diag), either side |
| Turn | Draw 1 (if deck not empty), play **exactly 1** Goob; no skip |
| Hand | Start 3 after shuffle; max 10. A draw that would make an 11th is **skipped**; those Goobs stay on top of the deck |
| Deck | 21 Goobs each side, identical; shuffle once; **no reshuffle** |
| Empty deck | No draws; may still play from hand |
| Out of Goobs | A side with no Goobs (hand + deck) takes no more turns; the other side plays on until the board is full. A four during those turns still ends the scenario |
| Stalemate | Both cannot draw and cannot play, no win → **draw** → replay per flow |
| Resolution | **Land → effect → win check last** (Plentiful's draw 2 is its effect) |
| Both sides four | Both sides have four in a row at the win check → **draw** (same replay, no tally) |
| Destroyed Goob | Goobs above it **fall** (no gaps; `BoardState.destroy_cell`) |

### Starter deck (each side)

**17× Vanilla, 1× Convincing, 1× Fat, 1× Popular, 1× Plentiful** (21). Data in `resources/goobs/*.tres` + `starter_deck.json` still has 18 Vanilla and no Plentiful — fix in M4 (deck) / M5 (Plentiful effect).

| Goob | Mult | Effect (8-way adjacency from **landed** cell) | Card text (exact) |
|------|------|-----------------------------------------------|-------------------|
| Vanilla | 1.0 | — | (none) |
| Convincing | 0.5 | Flip random **adjacent opposing** Goob to yours | “Flip a random adjacent enemy Goob to your side.” |
| Fat | 0.5 | Destroy random **adjacent** Goob; Goobs above it fall | “Destroy a random adjacent Goob.” |
| Popular | 0.5 | Extra **Vanilla** (your side) in random column (gravity) | “Drop a Vanilla Goob into a random column.” |
| Plentiful | 0.5 | Draw 2 after it lands, before win check (fewer if deck short), on top of the turn draw | “Draw 2 Goobs.” |

Card text = immediate effect only. Random targets: game picks the target first, then that Goob's impact animation plays on it.

**Multipliers are hidden during play.** **Scoring sequence** (one side has four): reveal that line Goob by Goob — lowest column to highest, bottom to top within a column — each shows its multiplier; show the sum; then declare win (player four) or lose (opponent four). Draws skip it.

### Invalid column UX

- **Full column:** shake + error SFX + toast (e.g. “Column full”).
- **Blocked** (future): same + **“A Goob stops you from playing here”**.

### AI (v0.1)

- **M3 (before decks):** opponent drops a plain red Goob, no effect: winning column, else column that blocks the player's immediate four, else **random legal column**.
- **M6:** hand-aware, human-like: win if possible → block player’s immediate 4 → else reasonable heuristic (not random). Opponent's hand is face-down (one shared back); its Goob flips from that hand into the column.

### Tech

- **1920×1080**, mouse only, red vs blue: **enemy red, player blue**.
- Grid truth: `scripts/rules/board_state.gd`. View: `scenes/board/board_view_3d.tscn` (upright 3D board like the real game; frame is solid on physics layer `board_frame` so physics Goobs can fall into columns).
- Presentation direction: Goobs look visually interesting, with **real physics, 3D effects and play animations** (Hearthstone / Marvel Snap); the **hand is visible** like Hearthstone / Slay the Spire.
- Scenes via **`GameFlow`** autoload only (`scripts/core/game_flow.gd`).
- Goobs: `GoobDefinition` + `.tres`; column rays use layer `board_columns`.

---

## Repo map

```
project.godot                 # boot.tscn, autoload GameFlow
scenes/app/                   # boot, title, strange_man
scenes/ui/coin_flip.tscn
scenes/scenario/scenario.tscn
scenes/board/board_view_3d.tscn
scripts/core/game_flow.gd
scripts/rules/board_state.gd  # extend for M2+
scripts/goobs/, scripts/deck/, scripts/ai/
resources/goobs/*.tres, starter_deck.json
```

```gdscript
# BoardState.CellOwner — EMPTY, PLAYER, OPPONENT
# GoobDefinition.EffectType — NONE, FLIP_ADJACENT, DESTROY_ADJACENT, EXTRA_VANILLA_DROP
```

---

## Milestones

Tick in commit messages. **Do not start M(n+1) until M(n) is playable.**

### M1 — Project shell ✅

Scene flow, Strange Man text, coin flip, empty grid display, Goob resources, `BoardState` stub.

### M2 — Board core ✅

- [x] `BoardState`: `drop(col, owner) -> row or -1`, `column_full`, `find_winner()`
- [x] Mouse column pick (raycast or buttons); full-column feedback
- [x] View syncs tokens on grid (quads/Sprite3D OK)

**Test:** F5 → reach scenario → drops stack correctly; full column shakes/toast; four in a row detectable (temp both sides OK).

### M3 — Turn loop ← **you are here**

- [ ] Alternate sides after coin flip; end on win/lose; overlay → Title via `GameFlow`
- [ ] Draw replay flag path

**Test:** Full win/lose returns to title; draw path skips Strange Man on retry.

### M4 — Decks & hands

- [ ] Load/shuffle `starter_deck.json`; draw pile + hand per side
- [ ] Turn draw/play rules; empty deck; draw stalemate → replay

**Test:** Hands visible; deck counts behave; stalemate replays correctly.

### M5 — Goob effects

- [ ] Hand UI: pick Goob, then column; land → effect → win check
- [ ] Flip / destroy / extra vanilla / draw 2; scoring sequence on a one-sided four

**Test:** Each special once in a session; order land → effect → win.

### M6 — AI & polish

- [ ] Real `OpponentAI`; drop/highlight animations; coin flip anim
- [ ] Smoke **A1–A8**

---

## Ship checklist (v0.1 done)

- [ ] A1 Menu ↔ scenario
- [ ] A2 Scenario goals visible
- [ ] A3 Deck/hand/draw rules
- [ ] A4 Connect 4 + detection
- [ ] A5 Win + scoring sequence
- [ ] A6 Lose on opponent 4
- [ ] A7 No softlocks after end
- [ ] A8 Goob text readable in UI

---

## Out of scope (unless Sean asks)

Multi-scenario runs, shop, encounters, money, meta, saves, networking, mobile, Steam, non–7×6 boards, **new Goob types**, balance changes beyond starter four.

Full-game vision: GameDev vault `Design/GDD.md` — **not v0.1 tasks**.

---

## Ask Sean (don’t guess)

- New Goob effects, multipliers, or deck sizes
- Changes to draw/stalemate, AI personality, or UX copy beyond locked strings
- Scope creep (“while we’re here…” features)

Everything else: implement from this file + existing scripts.

---

## Manual test cheat sheet

| Milestone | F5 flow | Pass if |
|-----------|---------|---------|
| M2 | Title → scenario, click columns | Gravity, full column error, 4-in-a-row fires |
| M3 | Play until win/lose/draw | Returns to title; draw retry skips Strange Man |
| M4 | Several turns | Draw/play limits; empty deck |
| M5 | Play each special Goob | Effects match table; score on win line |
| M6 | Let AI play | Blocks/wins when obvious; no softlock |

---

*Last updated: 2026-11-02 (synced to vault slice after the Cursor grill) · Handoff: `docs/CLAUDE_CODE_HANDOFF.md`*
