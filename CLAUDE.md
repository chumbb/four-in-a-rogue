# Four in a Rogue — Claude Code handoff

**Purpose:** Single document so [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (or any local coding agent) can implement the Godot game **without inventing design**. Owner: **Sean Bishop** (`chumbb` on GitHub).

**Last updated:** 2026-11-01

---

## 1. Start here

| Item | Value |
|------|--------|
| **GitHub repo** | https://github.com/chumbb/four-in-a-rogue |
| **Engine** | Godot **4.3+**, Forward+, PC-first, **1920×1080**, **mouse only** (v0.1) |
| **Current milestone** | **M2 done** → implement **M3 → M4 → M5 → M6** (see §7) |
| **Scope now** | One playable **scenario** (not full 9+boss run yet) |

### Clone and run

```bash
git clone https://github.com/chumbb/four-in-a-rogue.git
cd four-in-a-rogue
# Open project.godot in Godot 4.3+, press F5
```

Expected flow today: **Boot → Title (Press Start) → Strange Man → Coin flip → Scenario** (M2 board test harness: LMB = red/player, RMB = blue/opponent, Reset Board; no turn loop yet).

### Companion docs (same design intent)

If you have access to Sean’s Cursor Project **Context** store, full GDD + slice spec live at:

- `/cursor/stores/self/docs/four-in-a-rogue-design.md` — high-level vision, full-game direction
- `/cursor/stores/self/docs/four-in-a-rogue-vertical-slice.md` — **authoritative v0.1 rules** and milestones

This handoff duplicates everything needed to **code v0.1**; use those files for full-game scope later.

---

## 2. Game pitch (do not change for v0.1)

**Four in a Rogue** is a single-player **Connect 4 roguelike**. Players fight the game with **decks of Goobs** (chips with multipliers and special effects). Ordinary Connect 4 is solved; this game adds **randomness, combos, and deckbuilding** for variety and depth.

- **Tone:** Absurdist “land of Goobs”; atmosphere like *Balatro*; bright colors (*Fields of Mistria* / *Hearthstone*); chiptune (later).
- **Full game (later):** 9 scenarios + boss per run, shop/encounters, meta unlocks — **not in v0.1**.
- **Monetization (later):** One-time purchase; no FOMO — **ignore for coding slice**.

**Strange Man opening dialogue (exact):**

> Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...

---

## 3. Architecture principles (Godot)

1. **Logic vs render:** Keep a **7×6 integer grid** (`BoardState` or successor) as source of truth. Isometric 3D view **only displays** grid state.
2. **Isometric 3D + 2D sprites:** Playfield in `Node3D` (`scenes/board/board_view_3d.tscn`); Goobs as `Sprite3D` or quads; HUD on `CanvasLayer`.
3. **Column input:** Mouse raycast to column colliders (layer `board_columns` in `project.godot`).
4. **Data-driven Goobs:** `GoobDefinition` Resource + `resources/goobs/*.tres` + `starter_deck.json`.
5. **Scene flow:** `GameFlow` autoload (`scripts/core/game_flow.gd`) — do not duplicate scene transitions ad hoc.

---

## 4. v0.1 rules (LOCKED — implement exactly)

### 4.1 App flow

| Step | Behavior |
|------|----------|
| Launch | `boot.tscn` → `title.tscn` |
| Press Start | → `strange_man.tscn` (dialogue above) → Continue |
| Coin flip | Player picks **heads/tails**, flip animation (stub OK), **player wins flip → player moves first** |
| Scenario | Play until win / lose / draw |
| Win or lose | Return to **title** (main menu) |
| Draw replay | **Skip Strange Man**; set `GameFlow.skip_strange_man_on_next_run = true` before title → **coin flip again**; reshuffle decks, new **starting hand 3**, empty board |

### 4.2 Board

- **7 columns × 6 rows**, **empty** at scenario start.
- Drop: chosen column → **lowest empty row** (gravity).
- **Win:** four in a row (H/V/diag), **either side**. No point threshold in v0.1.
- **Lose:** opponent four in a row only.
- **Resolution order:** piece **lands** → **special effect** → **win check last**.

### 4.3 Turn structure

- Strict **alternation** (after coin flip determines first player).
- Each turn: **draw 1** from deck (if deck not empty), then **play exactly 1** Goob from hand (unless a future effect says otherwise).
- **No skipping turns.**
- **Starting hand:** 3 after shuffle at scenario start.
- **Max hand size:** 10.

### 4.4 Decks (player + opponent)

- **Identical composition:** 18× Vanilla + 1× Convincing + 1× Fat + 1× Popular = **21 cards**.
- **Shuffle once** at scenario start; **no reshuffle** when deck empty.
- **Empty deck:** cannot draw; may still play from hand until hand empty.
- **Draw stalemate:** both sides cannot draw and cannot play (define precisely: empty hands + empty decks, no win) → **draw** → replay per §4.1.

### 4.5 Goobs (starter roster)

| ID | Name | Mult | Effect (after landing, 8-way adjacency from **landed cell**) |
|----|------|------|---------------------------------------------------------------|
| vanilla | Vanilla Goob | 1.0 | None |
| convincing | Convincing Goob | 0.5 | Flip **random adjacent opposing** Goob to yours |
| fat | Fat Goob | 0.5 | **Destroy random adjacent** Goob |
| popular | Popular Goob | 0.5 | **Extra Vanilla** in **random column**, then gravity |

**Scoring (v0.1 UI):** Sum **multipliers** of Goobs in the **winning line of four**; show on win screen. Money/shop **skipped**.

### 4.6 Invalid placement UX

- **Full column:** shake + error sound + toast (e.g. “Column full”).
- **Blocked cell** (future freeze Goobs): same shake + sound + toast: **“A Goob stops you from playing here”**.

### 4.7 Opponent AI (v0.1)

- **Win immediately** if possible.
- **Block** player’s immediate four-in-a-row if any column prevents it.
- Otherwise play **human-like** (use hand/deck — not pure random). Stub in `OpponentAI` is placeholder only.
- Full game will add easy/med/hard/boss tiers — **not now**.

### 4.8 Presentation

- **Red vs blue** sides (add pattern/shape redundancy before shipping accessibility).
- Mouse only.

---

## 5. Repo map (M1 as of commit `d8ac834`)

```
project.godot              # Main scene: scenes/app/boot.tscn; autoload GameFlow
scenes/app/
  boot.tscn, title.tscn, strange_man.tscn
scenes/ui/coin_flip.tscn
scenes/scenario/scenario.tscn
scenes/board/board_view_3d.tscn
scripts/core/
  game_flow.gd             # SceneKey enum, player_moves_first, skip_strange_man_on_next_run
  boot.gd
scripts/app/title.gd, strange_man.gd
scripts/ui/coin_flip.gd    # Heads/tails + stub flip
scripts/scenario/scenario_placeholder.gd
scripts/rules/board_state.gd   # 7×6 grid stub — NO drops/win detect yet
scripts/board/board_view_3d.gd # Visual grid quads only
scripts/goobs/goob_definition.gd
scripts/deck/starter_deck.gd
scripts/ai/opponent_ai.gd  # Returns column 3 — replace in M6
resources/goobs/
  vanilla_goob.tres, convincing_goob.tres, fat_goob.tres, popular_goob.tres
  starter_deck.json
```

### Key types already defined

```gdscript
# GoobDefinition.EffectType
NONE, FLIP_ADJACENT, DESTROY_ADJACENT, EXTRA_VANILLA_DROP

# BoardState.CellOwner
EMPTY, PLAYER, OPPONENT
```

---

## 6. What M1 already does vs missing

| Done (M1) | Not done yet |
|-----------|----------------|
| Scene flow wired | Real column pick + drops |
| Strange Man text | Connect-four detection |
| Coin flip logic (random) | Turn loop with sides |
| BoardState empty grid | Deck shuffle, hand UI, draw/play |
| 3D grid placeholder | Special Goob effects |
| Goob `.tres` + JSON | AI beyond stub |
| | Win/lose/draw overlays + score |
| | Coin flip animation |
| | Sprite3D Goobs on board |

---

## 7. Suggested implementation order (milestones)

Implement in order; each milestone should be playable/testable.

### M2 — Board core

- Extend `BoardState`: `drop(column, owner) -> row or -1`, `column_full`, `find_winner() -> owner or none`.
- Raycast or column buttons → drop for **both** PLAYER and OPPONENT (temporary hotkeys OK for test).
- Full-column feedback (shake + sound + toast).
- Sync `board_view_3d` (or new script) to place/remove visual tokens.

### M3 — Turn loop

- Track `active_side`, enforce alternation after coin flip.
- End scenario on win/lose; overlay + return to title via `GameFlow.return_to_title()`.
- Draw detection stub (can defer full stalemate until M4).

### M4 — Decks and hands

- Build deck from `starter_deck.json`, shuffle, draw pile + hand arrays per side.
- Start with 3 cards; draw 1 at turn start; play 1 per turn; max hand 10.
- Empty deck rules; draw-replay reshuffle + `skip_strange_man_on_next_run`.

### M5 — Goob effects

- Hand UI: show Goob name + `effect_description`; click Goob then column to play.
- On play: land → resolve effect → win check.
- Implement flip / destroy / extra vanilla per §4.5.
- Win screen: multiplier sum on winning four.

### M6 — AI + polish

- Replace `OpponentAI.choose_column` with win/block/heuristic search (consider 1-ply win + block).
- Drop animations, connect highlight, coin flip animation.
- Smoke-test full acceptance criteria A1–A8 from vertical slice doc.

---

## 8. Acceptance checklist (v0.1 “done”)

- [ ] A1 Menu → scenario → menu
- [ ] A2 Scenario shows goals (four in a row; score explanation)
- [ ] A3 Deck/hand/draw rules
- [ ] A4 Connect 4 placement + 4-in-a-row
- [ ] A5 Win + multiplier score
- [ ] A6 Lose on opponent 4
- [ ] A7 No softlocks after end
- [ ] A8 Goob text readable in UI

---

## 9. Explicitly OUT of scope (do not build unless Sean asks)

- Multi-scenario runs, shop, encounters, money, meta unlocks, achievements
- Non–7×6 boards, campaign map
- Mobile, Steam API, networking, saves
- Full accessibility suite (design targets exist in GDD for later)
- New Goob types or balance changes not in §4.5

---

## 10. Claude Code kickoff prompt (paste)

```text
I'm building Four in a Rogue in Godot 4.3+ from https://github.com/chumbb/four-in-a-rogue

Read CLAUDE.md or docs/four-in-a-rogue-claude-code-handoff.md if present; otherwise read README.md and implement milestone M2 (board core) per the handoff rules:

- 7×6 Connect 4 logic in BoardState: drop, full column, four-in-a-row detection
- Mouse column selection with full-column shake/sound/toast
- Keep grid logic separate from isometric BoardView3D
- Do not invent new game rules or scope beyond one scenario v0.1

After M2, stop and summarize what to test in the editor (F5).
```

**Recommendation:** Copy this file into the repo as `docs/CLAUDE_CODE_HANDOFF.md` or `CLAUDE.md` on next commit so Claude Code sees it in-repo.

---

## 11. Full game pointer (context only — not v0.1 tasks)

When v0.1 is fun, expand using `four-in-a-rogue-design.md`:

- Run: 3 easy + 3 medium + 3 hard scenarios + boss (~30–60 min)
- Between scenarios: shop OR random encounter
- Meta: unlock Goobs, build starting decks, high scores, cosmetic achievements
- PC first, then mobile; one-time purchase

Do **not** implement full-game systems until vertical slice passes.
