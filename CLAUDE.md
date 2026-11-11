# Four in a Rogue — solo dev + Claude Code

**Sean Bishop** · Godot **4.7** (develop and test on this version only; was 4.6.3 until 2026-11-09) · https://github.com/chumbb/four-in-a-rogue

Roguelike Connect 4 with deck Goobs. **You are the only programmer.** Implement **one milestone per session**, playtest in Godot, commit, stop. **Do not invent mechanics** — if a rule is missing, ask Sean.

---

## Design source of truth (global GameDev Obsidian vault)

| What | Where (Sean’s machine) |
|------|-------------------------|
| **Vault root (all games)** | `C:\Users\Sean\Documents\GameDev\` |
| **v0.1 locked rules (canonical)** | `...\GameDev\Projects\Four-in-a-Rogue\Design\vertical-slice-v0.1.md` |
| **Full-game GDD** (incl. Art direction) | `...\GameDev\Projects\Four-in-a-Rogue\Design\GDD.md` |
| **Decision log** | `...\GameDev\Projects\Four-in-a-Rogue\Decisions\Decision-Log.md` |
| **Art research** | `...\GameDev\Projects\Four-in-a-Rogue\Research\HD 2D art style in Godot.md` |
| **Vault AI rules** | `...\GameDev\CLAUDE.md` |

**Conflict rule:** If this file disagrees with the vault, **the vault wins**. After changing design in Obsidian, update §Locked rules here if needed.

**Cursor:** Open `four-in-a-rogue.code-workspace` (repo + GameDev vault).

**Claude Code + Obsidian MCP:** Project `.mcp.json` in repo root (gitignored; matches Cursor). Run `claude` from repo root; approve **obsidian** MCP once. Keep **Obsidian open** on GameDev. Setup/troubleshooting: `docs/CLAUDE_CODE_MCP.md`. Session handoff: `docs/CLAUDE_CODE_HANDOFF.md`.

**Art (Sean, 2026-11-09): Claude makes all Goob art and animation directly in Aseprite** through [pixel-plugin](https://github.com/willibrandon/pixel-plugin) (no Blender). Install once in local Claude Code: `claude plugin marketplace add willibrandon/pixel-plugin`, `claude plugin install pixel-plugin`, then `/pixel-setup` (Aseprite 1.3+). Claude app sessions can't reach Aseprite; do art from local `claude`. Painted biome background tooling is still being researched.

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

Implement the next incomplete milestone (currently M3.5 — portrait & touch conversion; M3 merged and 4.7 upgrade committed 2026-11-10; then M3.6 — 2D board conversion). Rules: vault slice spec + §Locked rules below.
Small diff, match existing GDScript style, no new scope. When done: what to press in F5 to verify, then stop.
```

| Now | Next |
|-----|------|
| **M2** ✅, **M3** turn loop ✅ merged to `main` (2026-11-10, tested in the M3.5 pass), **Godot 4.7** upgrade committed | **M3.5** portrait & touch conversion (vault slice §2A, §2B incl. *Column touch, flash and turn timer*, §6), then **M3.6** 2D board |
| Local copy → pull (Git Sync) → open `project.godot` → **F5** | On `main`: click → Strange Man → flip → turn loop vs opponent. Still the old 1920×1080 desktop layout until M3.5 |

---

## How we work (solo)

1. **One milestone** (M3.5…M7, incl. M3.6) per session unless Sean says otherwise.
2. **Playtest before the next milestone** — Sean always playtests from the **local copy** at `C:\Users\Sean\four-in-a-rogue` (Sean, 2026-11-09): pull first (Git Sync in Godot), then F5 on his vertical **1080×1920** monitor, **mouse clicks as touch**, full flow for that milestone. Cloud / Claude-app sessions must push so the local copy can pull; tell Sean which branch to check out.
3. **Small commits** — e.g. `M2: BoardState drop and win check`. No drive-by refactors.
   **Push every commit/merge right away** — never leave local-only commits; Git Sync in Godot only fast-forwards (Sean, 2026-11-02).
4. **Logic first** — `BoardState` / rules scripts before polish; the view follows grid state (2D from M3.6).
5. **No design drift** — no shop, runs, new Goobs, or “nice to have” unless Sean asks.
6. **Stuck on design?** Ask Sean (see §Ask Sean). Stuck on Godot? Fix with docs; don’t change rules.

---

## Locked rules (v0.1 — do not change)

Full acceptance list: **§Ship checklist** (A1–A10) and vault `vertical-slice-v0.1.md`. Summary below for fast coding sessions.

### Flow

- Boot → Title → **Strange Man** (dialogue below) → **Coin flip** (player picks heads/tails) → Scenario.
- **Tapping the start screen counts as Press Start** (a mouse click on desktop). Strange Man plays **after every Press Start** (portrait: old man in Goob-land clothes holding one Goob). No separate tutorial.
- Coin winner moves first (`GameFlow.player_moves_first`). **Scenario begins as soon as the flip is decided** (no extra start button).
- Win or lose → scoring sequence → **Title**. **Draw** (no four, or both sides four) → no scoring sequence, skip Strange Man (`GameFlow.replay_after_draw()` on `m3-turn-loop` goes straight to the coin flip), coin flip again, reshuffle decks, hand size 3, empty board.

**Strange Man (exact):**

> Hey, you must not be from around here. This is a land of Goobs. If you want to progress, you'll need to get 4 goobs in a row before your opponent does. You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know...

### Board & turns

| Rule | Value |
|------|--------|
| Grid | 7×6, empty at start |
| Drop | Column → lowest empty cell |
| Win | 4 in a row (H/V/diag), either side |
| Turn | Draw 1 (if deck not empty), play **exactly 1** Goob; no skip, no mana or cost — every Goob in hand is always playable |
| Hand | Start 3 after shuffle; **max 5** (Sean, 2026-11-09; was 10). A draw that would make a 6th is **skipped** (also Plentiful's draw 2); those Goobs stay on top of the deck |
| Deck | 21 Goobs each side, identical; shuffle once; **no reshuffle** |
| Empty deck | No draws; may still play from hand |
| Out of Goobs | A side with no Goobs (hand + deck) takes no more turns; the other side plays on until the board is full. A four during those turns still ends the scenario |
| Turn timer | **30 s** per player turn (Sean, 2026-11-10), a per-scenario value; HUD countdown; starts when input unlocks, never runs while input is locked; opponent untimed. Timeout → Goob plays into the column under the finger, or (none: never touched / cancelled / released on full column) a **random column, full ones included** |
| Roll | A Goob played into a full column (only at timeout) lands on top, rolls left/right 50/50, keeps going over full columns, **bounces** off the edge, falls into the first open column; then land → effect → win check |
| Stalemate | Both cannot draw and cannot play, no win → **draw** → replay per flow |
| Resolution | **Land → effect → win check last** (Plentiful's draw 2 is its effect) |
| Both sides four | Both sides have four in a row at the win check → **draw** (same replay, no tally) |
| Destroyed Goob | Goobs above it **fall** (no gaps; `BoardState.destroy_cell`) |

### Starter deck (each side)

**17× Vanilla, 1× Convincing, 1× Fat, 1× Popular, 1× Plentiful** (21). Data in `resources/goobs/*.tres` + `starter_deck.json` (updated 2026-11-09: 17 Vanilla + `plentiful_goob.tres`, `EffectType.DRAW_TWO`). The draw-2 effect itself is implemented in M5.

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

- **Full column:** greyed while aiming; drop attempt → shake + error SFX + toast (e.g. “Column full”); Goob stays in hand.
- **Blocked** (future): same + **“A Goob stops you from playing here”**.

### AI (v0.1)

- **M3 (before decks):** opponent drops a plain red Goob, no effect: winning column, else column that blocks the player's immediate four, else **random legal column**.
- **Red flash** (Sean, 2026-11-10): after the think delay, the AI's chosen column flashes red (~0.15 s) right before its Goob is played.
- **M6:** hand-aware, human-like: win if possible → block player’s immediate 4 → else reasonable heuristic (not random). Opponent's hand is face-down (one shared back); its Goob flips from that hand into the column.

### Platform & screen (Sean, 2026-11-09 — vault slice §2A/§2B)

- **iOS/Android phones held vertically (portrait)**, developed portrait-first. A landscape Steam version comes later (not v0.1).
- `project.godot`: viewport **720×1280** base; window override **1080×1920** (Sean's monitor); handheld orientation **portrait**; stretch **canvas_items** / aspect **expand** / scale **fractional**; `emulate_touch_from_mouse` **on**, `emulate_mouse_from_touch` **on**; default canvas texture filter **Nearest**; pixel art imported **lossless**; `application/run/max_fps` **60** (fixed 60 fps).
- **Renderer: decided later** (after M7). Project uses **mobile** for now; only use effects that also work in **Compatibility** (no DoF, no CompositorEffects, no HDR 2D). Enable the shader baker at export.
- **Gameplay input reads `InputEventScreenTouch` / `InputEventScreenDrag` only** (never also the emulated mouse events). Single pointer, no hover, no multitouch. Buttons use normal Control signals.
- **Safe area:** full-screen background; HUD/board/hand inside a SafeArea MarginContainer from `DisplayServer.get_display_safe_area()`, reapplied on resize; debug toggle simulates phone insets (~110 px top, ~70 px bottom at 720 base). Nothing interactive in the bottom home-gesture strip; hand inset ≥ 24 px from side edges.
- **Layout (top → bottom, 720 base):** HUD 100 (pause in corner, goal text, turn) · opponent hand 60 (smaller red backs) · flex band (coin result, scoring tally, toasts) · aim lane 100 · board (2D pixel board from M3.6: 32 game-px columns ≈ 85 px at 4×; zone heights rechecked in M3.6) · player strip 56 (deck, "n/5") · hand 170 (up to 5 Goobs, one row). **Touch-target floor 96 px** (open: board columns fall just under it, vault slice §5 item 5).
- **Column touch (M3.5, Sean 2026-11-10):** touch down on a legal column = **blue flash** over column + aim lane; flash stays while held and follows the finger; **release over a column = drop**, release outside board = cancel (quick tap drops at once). Touching/sliding onto a full column = shake + error SFX + toast **once per entry**, no flash; releasing there = neutral. Input locked from release until the drop finishes.
- **Playing a Goob (M4):** drag (lift > ~12 px, ghost over the column under the finger, **release over board = drop, release outside = cancel**) or tap (tap Goob to select, tap column to aim, **tap same column again = drop**; how this fits the M3.5 press/hold model is decided at M4, slice §5 item 7). **No undo.** Column hit area = full column height + aim lane. Full column greyed while aiming. **Double tap = inspect** (name + card text; Sean 2026-11-10, was long-press): always on hand Goobs, on board Goobs only when no hand Goob is selected. Input locked during the opponent's turn and animations.
- **Options:** animation speed **Normal / Fast / Skip** (affects play animations and the scoring sequence). **Haptics:** built-in `Input.vibrate_handheld()` only.

### Tech

- Red vs blue: **enemy red, player blue**.
- Grid truth: `scripts/rules/board_state.gd`. View today: `scenes/board/board_view_3d.tscn` (upright 3D board). **Replaced in M3.6** by an upright **2D pixel board** (Sean, 2026-11-09).
- **Presentation (all 2D, Sean 2026-11-09):** layers back to front: painted biome background → board back → Goobs → board front (hole mask) → effects → UI.
- **Pixel layer:** board, Goobs and aim lane on a **270×480 game-pixel canvas**, **32 px Goobs/columns**, shown at the **largest whole-number scale that fits screen width in physical pixels** (4× at 1080 wide), nearest filtering; Goob positions snap to whole game pixels while moving. Background and Control UI stay on the 720 base.
- **Goob art:** pixel sprites with a 3D look, drawn and animated by Claude in Aseprite; **lighting baked into the sprites**; **outline from a runtime canvas shader**. Placeholders OK for v0.1. Import via `.aseprite`/sprite sheet → `SpriteFrames`.
- Presentation direction: Goobs look visually interesting, with **real physics, 3D effects and play animations** (2D sprites with a 3D look) (Hearthstone / Marvel Snap); each Goob type has its own animation; the hand is a row of up to 5 faces at the bottom, the opponent's backs smaller at the top.
- Scenes via **`GameFlow`** autoload only (`scripts/core/game_flow.gd`).
- Goobs: `GoobDefinition` + `.tres`; column rays use layer `board_columns`.

---

## Repo map

```
project.godot                 # boot.tscn, autoload GameFlow
scenes/app/                   # boot, title, strange_man
scenes/ui/coin_flip.tscn
scenes/scenario/scenario.tscn
scenes/board/board_view_3d.tscn   # replaced by 2D board in M3.6
scripts/core/game_flow.gd
scripts/rules/board_state.gd  # extend for M2+
scripts/goobs/, scripts/deck/, scripts/ai/
resources/goobs/*.tres, starter_deck.json
```

```gdscript
# BoardState.CellOwner — EMPTY, PLAYER, OPPONENT
# GoobDefinition.EffectType — NONE, FLIP_ADJACENT, DESTROY_ADJACENT, EXTRA_VANILLA_DROP, DRAW_TWO
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

### M3 — Turn loop ✅ (merged 2026-11-10; playtested in M3.5)

- [x] Alternate sides after coin flip; end on win/lose; overlay → Title via `GameFlow`
- [x] Draw replay: `GameFlow.replay_after_draw()` → coin flip (no Strange Man)

**Test:** Full win/lose returns to title; draw Replay goes to coin flip, skipping Strange Man (checked in the M3.5 playtest).

### M3.5 — Portrait & touch conversion ← **implemented on `m3.5-portrait-touch`, awaiting Sean's playtest**

- [x] Open in **Godot 4.7** and let it upgrade the project; commit the result (`c81baf4`)
- [x] `project.godot` portrait settings (§Platform & screen), renderer → **Mobile**
- [x] SafeArea root + simulated-inset toggle on **F3** (debug builds only); background fills the screen
- [x] Reserve empty opponent-hand / player-strip / hand zones; keep the 3D board, fitted to the board zone (no polish)
- [x] Scenario rebuilt in the portrait zones; title, Strange Man, coin flip, end overlay laid out for portrait, ≥ 96 px targets; tap to start
- [x] Board input on touch events: press/hold/release with blue column flash, full-column error once per entry; remove mouse hover preview
- [x] Red opponent flash before its drop
- [x] 30 s turn timer (per-scenario value) with HUD countdown; timeout auto-play; `BoardState` roll resolver with placeholder animation (Goob appears in its final column)

**Test:** Full M3 loop in portrait at 1080×1920 with mouse-as-touch, and in a tall window (e.g. 1080×2340) with simulated insets.

### M3.6 — 2D board conversion

- [ ] Replace the 3D board with an upright 2D pixel board (back layer + front layer with holes)
- [ ] 270×480 pixel layer at whole-number scale; placeholder painted background; nearest filtering
- [ ] Placeholder 32 px Goob sprite + runtime outline shader; 2D drop with pixel snapping
- [ ] Roll animation for timeout plays into full columns
- [ ] Recheck portrait zone heights. Grid logic unchanged.

**Test:** Same loop with the 2D board at 1080×1920 and 1080×2340; Goobs sit inside columns; no mixed pixel sizes.

### M4 — Decks & hands

- [ ] Load/shuffle `starter_deck.json` (17 Vanilla + 4 specials); draw pile + hand per side; **hand max 5**, start 3
- [ ] Turn draw/play rules; empty deck; draw stalemate → replay
- [ ] Player hand row + smaller opponent backs; **drag and tap aim state** (ghost, release / second-tap drop, cancel outside board); double-tap inspect

**Test:** Hands visible; deck counts behave; both input styles play and cancel correctly; stalemate replays correctly.

### M5 — Goob effects

- [ ] Land → effect → win check; per-type impact animations
- [ ] Flip / destroy / extra vanilla / draw 2; scoring sequence (flex band) on a one-sided four

**Test:** Each special once in a session; order land → effect → win.

### M6 — AI & polish

- [ ] Real `OpponentAI`; flip/drop/impact/highlight animations; coin flip anim
- [ ] Options menu: animation speed Normal / Fast / Skip; built-in haptics
- [ ] Low-time turn-timer warning (Sean, 2026-11-10)
- [ ] Smoke **A1–A10**

### M7 — On-device check (optional for v0.1)

- [ ] Android debug build (one-click deploy; Mobile renderer, then Compatibility on a low-end phone); iOS when a Mac is available

---

## Ship checklist (v0.1 done)

- [ ] A1 Menu ↔ scenario
- [ ] A2 Scenario goals visible
- [ ] A3 Deck/hand/draw rules
- [ ] A4 Connect 4 + detection
- [ ] A5 Win + scoring sequence
- [ ] A6 Lose on opponent 4
- [ ] A7 No softlocks after end
- [ ] A8 Goob text readable (long-press inspect)
- [ ] A9 Portrait touch: whole loop, single pointer, 1080×1920 + tall shape, simulated safe area, ≥ 96 px targets
- [ ] A10 Animation speed Normal / Fast / Skip

---

## Out of scope (unless Sean asks)

Multi-scenario runs, biomes, shop, encounters, money, meta, saves, networking, store builds/submission, the landscape Steam version, accessibility pass (comes at the end — gameplay and UI first), non–7×6 boards, **new Goob types**, balance changes beyond the starter five, final art (placeholders OK).

Full-game vision: GameDev vault `Design/GDD.md` — **not v0.1 tasks**.

---

## Ask Sean (don’t guess)

- New Goob effects, multipliers, or deck sizes
- Changes to draw/stalemate, AI personality, or UX copy beyond locked strings
- Open slice items: board column width vs 96 px touch floor (§5 item 5); HUD/hand on the pixel grid or not (§5 item 6)
- Scope creep (“while we’re here…” features)

Everything else: implement from this file + existing scripts.

---

## Manual test cheat sheet

| Milestone | F5 flow | Pass if |
|-----------|---------|---------|
| M2 | Title → scenario, click columns | Gravity, full column error, 4-in-a-row fires |
| M3 | Play until win/lose/draw | Returns to title; draw Replay goes to coin flip, skipping Strange Man |
| M3.5 | Full loop on the portrait monitor, then a tall window with simulated insets (F3) | Everything fits inside the safe area; hold/flash/release drops; full column errors; red flash; timer auto-plays and rolls; no hover; nothing under the home strip |
| M3.6 | Same as M3.5 | 2D board; Goobs sit inside columns; even pixels at 1080×1920 and 1080×2340 |
| M4 | Several turns, drag and tap | Draw/play limits; hand cap 5; cancel outside board; empty deck |
| M5 | Play each special Goob | Effects match table; score on win line |
| M6 | Let AI play | Blocks/wins when obvious; no softlock |

---

*Last updated: 2026-11-10 (M3 merged; 4.7 upgrade; M3.5 grill: column flash, turn timer, roll, double-tap inspect) · Handoff: `docs/CLAUDE_CODE_HANDOFF.md`*
