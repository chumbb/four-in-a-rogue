# Four in a Rogue — solo dev + Claude Code

**Sean Bishop** · Godot **4.6.3** (develop and test on this version only) · https://github.com/chumbb/four-in-a-rogue

Roguelike Connect 4 with deck Goobs. **You are the only programmer.** Implement **one milestone per session**, playtest in Godot, commit, stop. **Do not invent mechanics** — if a rule is missing, ask Sean.

---

## Start here (copy into Claude Code)

```text
Repo: four-in-a-rogue. Read CLAUDE.md fully.

Implement the next incomplete milestone (currently M2). Rules in §Locked rules and §Milestones only.
Small diff, match existing GDScript style, no new scope. When done: what to press in F5 to verify, then stop.
```

| Now | Next |
|-----|------|
| **M1** shell + scene flow | **M2** board core (drops, win detect, column UX) |
| Open `project.godot` → **F5** | Expected today: menu → Strange Man → coin flip → empty grid |

---

## How we work (solo)

1. **One milestone** (M2…M6) per session unless Sean says otherwise.
2. **Playtest before the next milestone** — F5, mouse only, full flow for that milestone.
3. **Small commits** — e.g. `M2: BoardState drop and win check`. No drive-by refactors.
4. **Logic first** — `BoardState` / rules scripts before polish; 3D view follows grid state.
5. **No design drift** — no shop, runs, new Goobs, or “nice to have” unless Sean asks.
6. **Stuck on design?** Ask Sean (see §Ask Sean). Stuck on Godot? Fix with docs; don’t change rules.

---

## Locked rules (v0.1 — do not change)

Full acceptance list: **§Ship checklist** (A1–A8). Details below are authoritative for coding.

### Flow

- Boot → Title → **Strange Man** (dialogue below) → **Coin flip** (player picks heads/tails) → Scenario.
- Coin winner moves first (`GameFlow.player_moves_first`).
- Win or lose → **Title**. **Draw** → skip Strange Man (`GameFlow.skip_strange_man_on_next_run = true`), coin flip again, reshuffle decks, hand size 3, empty board.

**Strange Man (exact):**

> Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...

### Board & turns

| Rule | Value |
|------|--------|
| Grid | 7×6, empty at start |
| Drop | Column → lowest empty cell |
| Win | 4 in a row (H/V/diag), either side |
| Turn | Draw 1 (if deck not empty), play **exactly 1** Goob; no skip |
| Hand | Start 3 after shuffle; max 10 |
| Deck | 21 cards each side, identical; shuffle once; **no reshuffle** |
| Empty deck | No draws; may still play from hand |
| Stalemate | Both cannot draw and cannot play, no win → **draw** → replay per flow |
| Resolution | **Land → effect → win check last** |

### Starter deck (each side)

18× Vanilla, 1× Convincing, 1× Fat, 1× Popular — see `resources/goobs/*.tres` + `starter_deck.json`.

| Goob | Mult | Effect (8-way adjacency from **landed** cell) |
|------|------|-----------------------------------------------|
| Vanilla | 1.0 | — |
| Convincing | 0.5 | Flip random **adjacent opposing** Goob to yours |
| Fat | 0.5 | Destroy random **adjacent** Goob |
| Popular | 0.5 | Extra **Vanilla** in random column (gravity) |

**Score on win:** sum multipliers of Goobs in the **winning line of four** (UI only in v0.1).

### Invalid column UX

- **Full column:** shake + error SFX + toast (e.g. “Column full”).
- **Blocked** (future): same + **“A Goob stops you from playing here”**.

### AI (v0.1)

Win if possible → block player’s immediate 4 → else reasonable heuristic (not random). Stub in `opponent_ai.gd` is not shipping quality.

### Tech

- **1920×1080**, mouse only, red vs blue: **enemy red, player blue**.
- Grid truth: `scripts/rules/board_state.gd`. View: `scenes/board/board_view_3d.tscn` (upright 3D board like the real game; frame is solid on physics layer `board_frame` so physics Goobs can fall into columns).
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

### M2 — Board core ← **you are here**

- [ ] `BoardState`: `drop(col, owner) -> row or -1`, `column_full`, `find_winner()`
- [ ] Mouse column pick (raycast or buttons); full-column feedback
- [ ] View syncs tokens on grid (quads/Sprite3D OK)

**Test:** F5 → reach scenario → drops stack correctly; full column shakes/toast; four in a row detectable (temp both sides OK).

### M3 — Turn loop

- [ ] Alternate sides after coin flip; end on win/lose; overlay → Title via `GameFlow`
- [ ] Draw replay flag path

**Test:** Full win/lose returns to title; draw path skips Strange Man on retry.

### M4 — Decks & hands

- [ ] Load/shuffle `starter_deck.json`; draw pile + hand per side
- [ ] Turn draw/play rules; empty deck; draw stalemate → replay

**Test:** Hands visible; deck counts behave; stalemate replays correctly.

### M5 — Goob effects

- [ ] Hand UI: pick Goob, then column; land → effect → win check
- [ ] Flip / destroy / extra vanilla; win screen shows multiplier sum

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
- [ ] A5 Win + multiplier score
- [ ] A6 Lose on opponent 4
- [ ] A7 No softlocks after end
- [ ] A8 Goob text readable in UI

---

## Out of scope (unless Sean asks)

Multi-scenario runs, shop, encounters, money, meta, saves, networking, mobile, Steam, non–7×6 boards, **new Goob types**, balance changes beyond starter four.

Full-game vision (9+boss, shop, unlocks) lives in Sean’s design doc — **not v0.1 tasks**.

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

*Last updated: 2026-11-01 · Companion: `docs/CLAUDE_CODE_HANDOFF.md` (pointer only)*
