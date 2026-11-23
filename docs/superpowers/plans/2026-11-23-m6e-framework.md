# M6e Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything the M6e category sessions share: ×2 specials, "Goob" name, rolled 11 + 10 decks, discard/destroyed piles, effect step lists, statuses with gap pills, the roll rule, the discard reveal, an F4 debug picker and debug auto-play.

**Architecture:** Rules stay headless in `TurnLoop` / `Deck` / `BoardState` plus a new `DeckBuilder` + `GoobRoster`; the scenario replays `TurnLoop.effect_steps` and draws `TurnLoop.statuses` as pills. Debug tools hang off `OS.is_debug_build()`.

**Tech Stack:** Godot 4.7 GDScript; headless tests via `G="/c/Users/Sean/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"; "$G" --headless -s res://tests/<file>.gd` (prints `N checks, 0 failures`).

**Spec:** `docs/superpowers/specs/2026-11-23-m6e-framework-design.md`

## Global Constraints

- Every special ×2, a plain Goob ×1. Vanilla is shown as **"Goob"**; its id stays `vanilla`.
- Deck per side = 11 Goobs + 10 specials: 1–2 from UNIQUE+TECH, 2 different categories from MOVE/DESTROY/DISCARD at 4–5 each, total 10. DRAW Goobs fill 0–1 slots of one main pool and 0–2 of the other (which pool is random). No duplicate types while the pool has enough. A category with no Goobs gives plain Goobs.
- A draw replay reshuffles the same two decks. A new game from the title rolls new ones.
- Roll (Sean's correction after the build, 2026-11-23): a Goob moves sideways while the cell beside it in the next column is free, falling to the top of that column; a column level with it or higher, or the edge, stops it, so on the floor or a flat top it rolls on to the next Goob or the edge (Sean, 2026-11-23); never off the board.
- Discard reveal: centre pop, name in the gap ~1.2 s, off screen (down = yours, up = his), one at a time, **never sped up by Fast**.
- Debug picker, category deck and auto-play exist only when `OS.is_debug_build()`.
- Gameplay input stays on `InputEventScreenTouch` / `InputEventScreenDrag`. Buttons ≥ 96 px. Match the repo's GDScript style. Never `git add -u`. After any `--editor` run, `git checkout -- project.godot`.

## Review Focus

- Hand full when the picker adds a Goob → the oldest Goob is replaced, and the fan redraws with no gap (Task 7 test).
- Auto-play switched off while its think timer runs → no second move, input unlocked, timer at 30 (Task 8 test).
- Auto-play switched on mid-drag → the drag is cancelled, the ghost hidden, and the AI moves once (Task 8 test).
- Draw replay while auto-play is on → the decks keep their composition and auto-play keeps going (Task 8 test).
- Roll from the middle of a column → the Goobs above fall into place, and `goob_at` follows every moved Goob (Task 5 test).

---

### Task 1: Multipliers, names, categories

**Files:**
- Modify: `scripts/goobs/goob_definition.gd` (add `enum Category { NONE, UNIQUE, TECH, MOVE, DESTROY, DISCARD, DRAW }`, `@export var category: Category = Category.NONE`)
- Modify: `resources/goobs/{vanilla,convincing,fat,popular,plentiful}_goob.tres`
- Modify: `tests/test_turn_loop.gd`, `tests/test_scenario.gd` (any ×0.5 / "Vanilla Goob" expectations)

**Interfaces:**
- Produces: `GoobDefinition.Category`, `GoobDefinition.category`

- [ ] **Step 1:** Add `_test_m6e_multipliers_and_names()` to `tests/test_turn_loop.gd`: Convincing/Fat/Popular/Plentiful `.multiplier == 2.0` and categories UNIQUE/DESTROY/UNIQUE/DRAW; Vanilla `multiplier == 1.0`, `display_name == "Goob"`, `category == NONE`; Popular `effect_description == "Drop a Goob into a random column."`.
- [ ] **Step 2:** Run test_turn_loop → FAIL.
- [ ] **Step 3:** Add the enum and field; edit the five `.tres` files (multiplier 2.0, category, Vanilla `display_name = "Goob"`, Popular text).
- [ ] **Step 4:** Run all five suites (`test_turn_loop`, `test_board_state`, `test_opponent_ai`, `test_scenario`, `test_flow_m3`). Fix expectations that assumed ×0.5 or "Vanilla Goob" (e.g. scoring sums now use 2 / 1). All 0 failures.
- [ ] **Step 5:** Commit `M6e: specials x2, Vanilla shown as Goob, Goob categories`.

### Task 2: Rolled decks

**Files:**
- Create: `scripts/deck/goob_roster.gd` (`class_name GoobRoster`, `const PATHS: Array[String]` = the 5 `.tres` paths; `static func all() -> Array[GoobDefinition]`; `static func specials(category) -> Array[GoobDefinition]`; `static func plain() -> GoobDefinition`). Category sessions add paths here.
- Create: `scripts/deck/deck_builder.gd` (`class_name DeckBuilder`)
- Modify: `scripts/rules/turn_loop.gd` (`start`), `scripts/core/game_flow.gd`, `scripts/scenario/scenario_placeholder.gd:193`
- Test: `tests/test_turn_loop.gd`

**Interfaces:**
- Produces: `DeckBuilder.roll(rng: RandomNumberGenerator, forced := {}) -> Array[GoobDefinition]` (21 Goobs, unshuffled). `forced` keys (all optional): `"top": GoobDefinition.Category` (UNIQUE or TECH: restrict the 1–2 pool to it), `"main": Array` of two MOVE/DESTROY/DISCARD categories.
- Produces: `TurnLoop.start(player_first, rng = null, deck: Array[GoobDefinition] = [], opponent_goobs: Array[GoobDefinition] = [])`. `deck` alone = both sides (tests, unchanged); both given = per side; neither = `DeckBuilder.roll(rng, forced)` once per side, where `forced` is a new last param `forced := {}` on `start`. TurnLoop must not read `GameFlow` (it stays headless). Expose `var player_goobs` / `var opponent_goobs` (the unshuffled lists used).
- Produces: `GameFlow.rolled_decks: Dictionary` (`{"player": Array, "opponent": Array}`, empty = roll new), cleared in `begin_play_flow_from_title()` and `return_to_title()`, kept by `replay_after_draw()`. `GameFlow.debug_forced_categories: Dictionary` (passed as `forced`).

- [ ] **Step 1:** Add tests, running each over seeds 1..200:
  - `_test_deck_builder_shape`: size 21; ≥ 11 Goobs with `category == NONE` (11 + the plain fill for empty categories); UNIQUE/TECH Goobs count 1–2 (TECH has none yet, so 1–2 UNIQUE or plain); every special is in `GoobRoster.all()`.
  - `_test_deck_builder_main_pools`: with `forced = {"main": [DESTROY, DISCARD], "top": UNIQUE}`, the DESTROY pool + DISCARD pool + top = 10 slots; DRAW Goobs ≤ 3 in total; DISCARD slots are plain (no Goobs yet); DESTROY slots are Fat or Plentiful.
  - `_test_deck_builder_no_dupes_when_enough`: with a stub roster passed through a test-only `DeckBuilder.roll_from(rng, roster: Array[GoobDefinition], forced)`, give 6 distinct DESTROY types and check no type repeats inside the pool.
  - `_test_start_rolls_per_side`: `t.start(true, _seeded(3))`: player and opponent decks have 21 + their own composition; `t.start(true, _seeded(3), t.player_goobs, t.opponent_goobs)` reproduces the same compositions.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement `roll` / `roll_from`. Pick the top count (1–2) and the 2 main categories, split the remaining 8–9 as 4/4, 4/5 or 5/4 (random among the splits that sum right), then choose the DRAW slot counts (0–1 for one random pool, 0–2 for the other), draw those from DRAW, and fill the rest from the pool's category. Picking from a category: shuffle its types, take in order, cycle when exhausted; empty category → `GoobRoster.plain()`.
- [ ] **Step 4:** Wire it in: the scenario uses `GameFlow.rolled_decks` if set, else lets `TurnLoop` roll (with `GameFlow.debug_forced_categories`) and stores `_loop.player_goobs/opponent_goobs` in `GameFlow.rolled_decks`. A non-empty scenario `deck` (tests) still wins.
- [ ] **Step 5:** All suites pass (the old `_test_starter_deck` keeps testing `StarterDeck.build()`). Commit `M6e: rolled 11+10 decks per side, kept across draw replays`.

### Task 3: Discard and destroyed piles

**Files:** Modify `scripts/deck/deck.gd`, `scripts/rules/turn_loop.gd`; Test `tests/test_turn_loop.gd`

**Interfaces:**
- Produces: `Deck.discard_pile: Array[GoobDefinition]`, `Deck.destroyed_pile: Array[GoobDefinition]`, `Deck.discard(index: int) -> GoobDefinition` (null if out of range).
- Produces: `TurnLoop.destroy_at(cell: Vector2i) -> void`: destroys the cell, pushes its Goob into the destroyed pile of the side that owned it, and moves the `_cell_goobs` of the Goobs above down one (the existing Fat loop moves here as `_collapse_goobs(column: int, from_row: int)`). Fat uses it.
- Produces: `TurnLoop.discard_from(side, index: int) -> GoobDefinition`, which also appends a step `{"kind": EffectType.NONE, "discarded": goob, "side": side, "cell": Vector2i(-1, -1), "fizzled": false}` to `effect_steps` (Task 4).

- [ ] **Step 1:** Tests:
  - `_test_fat_fills_destroyed_pile`: rig a player Fat next to an opponent Vanilla; after the play, `opponent_deck.destroyed_pile == [VANILLA]` and the player's pile is empty.
  - `_test_discard`: `deck.discard(0)` moves the hand Goob to `discard_pile`; `discard(9)` returns null and changes nothing.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** All suites pass. **Step 5:** Commit `M6e: discard and destroyed piles`.

### Task 4: Effect steps and statuses

**Files:** Modify `scripts/rules/turn_loop.gd`; Test `tests/test_turn_loop.gd`

**Interfaces:**
- Produces: `TurnLoop.effect_steps: Array[Dictionary]`, reset at the start of each `play()`. `_resolve_effect` appends its dict, and `last_effect` stays `effect_steps[0]` (or `{}`).
- Produces: `TurnLoop.statuses: Array[Dictionary]` with keys `id: StringName, side: CellOwner, label: String, text: String, turns_left: int` (−1 = until removed). `add_status(id, side, label, text, turns_left) -> void`, `remove_status(id, side) -> void`, `has_status(id, side) -> bool`. `_begin_turn` ticks before the draw: every status with `turns_left > 0` loses 1, and those reaching 0 are removed. Also `func _on_turn_start(side) -> void` (empty hook for category sessions, called after the tick and before the draw) and `func _on_turn_end(side) -> void` (called in `play()` after the effect, before the win check).
- Cleared by `start()`.

- [ ] **Step 1:** Tests:
  - `_test_effect_steps`: a Fat play gives `effect_steps.size() == 1` and `last_effect == effect_steps[0]`; a Vanilla play gives one step with kind NONE.
  - `_test_status_ticks`: `add_status(&"t", P, "Test", "x", 2)` survives one `_begin_turn` with 1 left and is gone after two plays' turn starts; a −1 status survives 10 plays; `start()` clears it.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** All suites pass. **Step 5:** Commit `M6e: effect step list, statuses with turn hooks`.

### Task 5: Roll rule

**Files:** Modify `scripts/rules/turn_loop.gd`; Test `tests/test_turn_loop.gd`

**Interfaces:**
- Produces: `TurnLoop.roll_goob(cell: Vector2i, dir: int) -> Array[Vector2i]`: the cells it passes through after leaving `cell` (empty = didn't move). `dir` is −1 or +1. It keeps its owner and `GoobDefinition`, and the Goobs above its old cell fall (`_collapse_goobs`).

Algorithm (per the spec's roll rule):
```
while true:
    next = cell.x + dir
    if next out of range or height(next) >= cell.y: break   # level or higher surface stops it
    remove cell (collapse its column), drop into next (row = height of next)
    cell = landed cell; path.append(cell)
```

- [ ] **Step 1:** Tests:
  - `_test_roll_downhill`: heights [3,1,0,...], roll the top Goob of column 0 to the right → path ends at (2,0), column 0 height 2.
  - `_test_roll_stops_equal`: heights [2,2] → the top of column 0 rolling right doesn't move.
  - `_test_roll_border`: a Goob in column 0 rolling left → empty path.
  - `_test_roll_middle`: a column 3 Goobs tall; roll the middle one (row 1) to the right into an empty column 1 → the top Goob falls to row 1 in column 0, and `goob_at` and owners match for both.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** Pass. **Step 5:** Commit `M6e: shared roll rule (logic)`.

### Task 6: Scenario — steps, pills, discard reveal

**Files:**
- Create: `scripts/ui/status_pills.gd` (`class_name StatusPills extends Control`; `func show_statuses(statuses: Array[Dictionary]) -> void`; `signal pill_pressed(text: String)`; pills as `PixelStage` buttons with the toast-pill stylebox, Monogram 1×, blue `#4d9be6`-family text for PLAYER and red for OPPONENT taken from the existing banner colours; one row along the bottom of the gap, player pills from the left, opponent from the right; buttons ≥ 96 px wide per the touch floor, height as the gap allows)
- Modify: `scripts/scenario/scenario_placeholder.gd` (`_land_then_continue` / `_play_effect`: play every entry of `_loop.effect_steps` in order; `_play_effect_impact`: a step with `"discarded"` → `await _show_discard(goob, side)`; `_refresh_hud` → `_pills.show_statuses(_loop.statuses)`; `pill_pressed` → `_toast.show_message(text)`)
- Modify: `scripts/hand/hand_view.gd` (add `func play_discard(goob: GoobDefinition, side: BoardState.CellOwner) -> void` reusing the reveal pop + hold, then flying to below the screen (PLAYER) or above it (OPPONENT) and freeing)
- Test: `tests/test_scenario.gd`

**Interfaces:**
- Consumes: `TurnLoop.effect_steps`, `TurnLoop.statuses`, `TurnLoop.discard_from` (Tasks 3–4).
- Produces: `Scenario._show_discard(goob, side) -> void` (awaitable): `_hud.show_caption(goob.display_name, 1.2)`, plus `await _hand.play_discard(goob, side)`. Its timing ignores `Settings.anim_scale()`.
- Produces: `Scenario._pills: StatusPills`.

- [ ] **Step 1:** Tests in `test_scenario.gd`:
  - `_test_status_pill_shows_and_toasts`: `_loop.add_status(&"t", P, "Test", "Explain", -1)`, then `_refresh_hud()` → one visible pill with text "Test" on the left half; pressing it shows the toast "Explain".
  - `_test_discard_reveal_not_faster_on_fast`: with Settings speed Fast, `_show_discard` takes ≥ 1.2 s (measured with `Time.get_ticks_msec()`), and the player's hand loses the Goob only through `discard_from`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** All suites pass. **Step 5:** Commit `M6e: effect steps replay, status pills, discard reveal`.

### Task 7: F4 debug picker and category deck

**Files:**
- Create: `scripts/debug/debug_panel.gd` (`class_name DebugPanel extends Control`; built in code like `pause_menu.gd`, scrim + panel stylebox; rows: side switch "You / Opponent"; one button per `GoobRoster.all()` Goob (display name); "Discard random"; "Add test status"; category deck row: top pool Auto/Unique/Tech, main pool Auto or a pair from MOVE/DESTROY/DISCARD; "New game with these"; "Close")
- Modify: `scripts/scenario/scenario_placeholder.gd` (create the panel only `if OS.is_debug_build()`; F4 toggles it while in the scenario; the tree pauses like the pause menu)
- Test: `tests/test_scenario.gd`

**Interfaces:**
- Produces on the scenario: `debug_give(goob: GoobDefinition, side) -> void` (append to the hand; if `hand.size() == Deck.HAND_MAX`, replace index 0 first; the player fan is rebuilt), `debug_discard_random(side) -> void` (via `_loop.discard_from` + `_show_discard`), `debug_add_status(side) -> void` (adds `&"debug"` with label "Test" and text "A test status from the debug panel.", turns_left 2, then `_refresh_hud`).
- "New game with these" sets `GameFlow.debug_forced_categories`, clears `GameFlow.rolled_decks`, and calls `GameFlow.replay_after_draw()` (coin flip → fresh roll).

- [ ] **Step 1:** Tests:
  - `_test_debug_give_full_hand_replaces_oldest`: fill the player hand to 5, `debug_give(FAT, P)` → size 5, last == FAT, the old index 0 is gone, and the fan shows 5.
  - `_test_debug_give_opponent`: the opponent hand gains the Goob.
  - `_test_debug_status`: the pill appears.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** Pass. **Step 5:** Commit `M6e: F4 debug Goob picker and category deck`.

### Task 8: Debug auto-play

**Files:**
- Modify: `scripts/core/settings.gd` (`var autoplay_button := true`, persisted like `auto_flip`, `set_autoplay_button(on)`), `scripts/ui/options_panel.gd` (toggle row "Auto-play button", appended to `TOGGLES` only `if OS.is_debug_build()`; check the panel still fits)
- Modify: `scripts/ui/scenario_hud.gd` (a "»" button the same size as Pause, `PAUSE_INSET` to its right, Monogram 2× label, lit = `UiKit` pressed/accent style while on; `signal autoplay_pressed`; visible only when `OS.is_debug_build() and Settings.autoplay_button`; hidden with Pause at the end)
- Modify: `scripts/rules/board_state.gd` (`func mirrored() -> BoardState`: a copy with PLAYER ↔ OPPONENT)
- Modify: `scripts/core/game_flow.gd` (`var autoplay := false`), `scripts/ui/coin_flip.gd:148` (`auto` also true when `GameFlow.autoplay`)
- Modify: `scripts/scenario/scenario_placeholder.gd`
- Test: `tests/test_scenario.gd`, `tests/test_board_state.gd`

**Interfaces:**
- Scenario: `set_autoplay(on: bool) -> void`.
  - On, during the player's turn with input enabled: cancel the touch/drag/aim (`_end_touch`, `_hide_aim`, `_clear_aim`), stop `_turn_timer`, hide the fuse, timer shows "—", input locked, then `_run_autoplay_turn()`.
  - Off while the auto think timer runs: stop it, unlock input, restart the turn timer at 30 s, show the timer.
- `_run_autoplay_turn()`: `OpponentAI.choose_move(_loop.board.mirrored(), _loop.player_deck.hand, _loop.player_deck.draw_pile.size(), _rng)`, wait `_think_sec(blocking or close)` on a new `_autoplay_timer`, then `_play_player(column, hand_index)`.
- `_after_play()` player branch: after the draw, `if GameFlow.autoplay: _run_autoplay_turn()` instead of enabling input.
- `_show_end()`: PLAYER_WIN / OPPONENT_WIN → `GameFlow.autoplay = false`. DRAW with autoplay on → after 1.0 s, press Replay (`_on_end_pressed()`).

- [ ] **Step 1:** Tests:
  - `test_board_state._test_mirrored`: owners swapped, original untouched.
  - `test_scenario._test_autoplay_plays_for_player`: `set_autoplay(true)` on the player's turn → within the think delay + animations, a player Goob is on the board and it's the opponent's turn; the player timer was never started.
  - `_test_autoplay_off_during_think`: `set_autoplay(true)` then `set_autoplay(false)` the same frame → no player Goob dropped after 2 s, input enabled, timer at 30.
  - `_test_autoplay_cancels_drag`: start a drag on a hand Goob, `set_autoplay(true)` → the aim ghost is hidden and exactly one player Goob gets played.
  - `_test_autoplay_draw_replay_keeps_decks`: force a draw with autoplay on → `GameFlow.rolled_decks` is unchanged after Replay and `GameFlow.autoplay` is still true.
  - `_test_autoplay_button_hidden_by_setting`: `Settings.set_autoplay_button(false)` → the HUD button is hidden.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** All suites pass. **Step 5:** Commit `M6e: debug auto-play button and option`.

### Task 9: Docs and push

**Files:** `CLAUDE.md` (tick Framework under M6e, add to the manual test cheat sheet: `| M6e framework | F5, F4 picker, » auto-play | ×2 scoring, rolled decks, pills, discard reveal, auto-play |`), `docs/CLAUDE_CODE_HANDOFF.md` (M6e framework section: new APIs from Tasks 2–5 so the category sessions find them), vault session log.

- [ ] **Step 1:** Run all five suites. All 0 failures.
- [ ] **Step 2:** Commit `M6e framework: docs` and `git push`.
