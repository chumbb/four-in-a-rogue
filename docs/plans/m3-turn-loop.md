# M3 Turn Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the M2 click-both-sides harness with a real turn loop. Press Start by click, then the coin flip goes straight into the scenario. Player and opponent alternate. The opponent plays win, else block, else random. The game ends on a four or a full board. A win or loss returns to the title, and a draw replays from the coin flip.

**No-four fill (used by several tests):** owner of `(column, row)` = `PLAYER if ((row / 2) + column) % 2 == 0 else OPPONENT` (integer division). A full board in this pattern has no four anywhere, and cell (6, 5) is PLAYER. Put it in each test file as `_fill_owner(column, row)`.

**Architecture:** Turn rules live in a pure `TurnLoop` (RefCounted) over `BoardState`, so they test headless with no scene. `OpponentAI` is a static, stateless function that takes an injected `RandomNumberGenerator`. The scenario scene only routes clicks to `TurnLoop`, runs the opponent after a short delay, syncs the 3D view and shows the end overlay. `GameFlow` keeps owning every scene change.

**Tech Stack:** Godot 4.6.3, GDScript, headless `SceneTree` test scripts (`_check(cond, msg)` harness, exit 1 on any failure; copy the pattern from `tests/test_board_state.gd`).

**Spec:** GameDev vault `Projects/Four-in-a-Rogue/Design/vertical-slice-v0.1.md` (§4 Scenario & flow, Turn and win/lose, Opponent AI; §6 M3). Repo `CLAUDE.md` §Locked rules mirrors it; the vault wins on conflict.

## Global Constraints

- Godot **4.6.3** only. Run tests with `godot --headless -s res://tests/<file>.gd` (Godot 4.6.3 binary).
- **Mouse only.** No new keyboard requirement (keeping `ui_accept` as an extra on the title is fine).
- **Enemy red, player blue.** `BoardState.CellOwner.PLAYER` = blue, `OPPONENT` = red.
- Scene changes go through the **`GameFlow`** autoload only.
- "**Scenario begins as soon as the flip is decided** — no extra start step."
- "Clicking the start menu counts as Press Start."
- **M3 opponent:** "drops a plain red Goob with no effect. It chooses a column that wins immediately, otherwise a column that blocks an immediate player four, otherwise a random legal column."
- **Win check is last** after the drop. A four ends the scenario immediately. Mutual four = draw (`BoardState.Outcome.DRAW`).
- **Draw replay:** reset board, coin flip again, **no Strange Man**. Win or lose → title.
- No decks, hands, effects, multipliers or scoring sequence in M3 (M4/M5). Do not add them.
- Small commits, **push every commit immediately** (Git Sync is ff-only).

## Review Focus

1. **Click during the opponent's turn or its delay** → ignored: no drop, no toast, no sound. (Task 3 test `_test_click_during_opponent_turn`)
2. **Player clicks a full column** → shake + error sound + "Column full" toast, and it is **still the player's turn**. (Task 2 `_test_full_column_keeps_turn`, Task 3 `_test_full_column_on_player_turn`)
3. **The 42nd drop makes four** → that is a win, not a full-board draw. (Task 2 `_test_last_cell_win_beats_full_board`)
4. **Opponent moves first** → it plays without any click, then the player can click. (Task 3 `_test_opponent_first`)
5. **Leaving the scene (Back to title) during the opponent's delay** → no error or crash from the pending move. (Task 3 `_test_free_during_opponent_delay`)

---

## File structure

| File | Change | Responsibility |
|------|--------|----------------|
| `scripts/rules/board_state.gd` | Modify | Add `copy()` for look-ahead |
| `scripts/ai/opponent_ai.gd` | Modify | M3 win / block / random column choice |
| `scripts/rules/turn_loop.gd` | Create | Whose turn, legal play, end result |
| `scripts/scenario/scenario_placeholder.gd` + `scenes/scenario/scenario.tscn` | Modify | Wire clicks → `TurnLoop`, opponent delay, end overlay; remove M2 harness (right click, Reset Board) |
| `scripts/core/game_flow.gd` | Modify | `replay_after_draw()`; remove the now-dead `skip_strange_man_on_next_run` path |
| `scripts/ui/coin_flip.gd` + `scenes/ui/coin_flip.tscn` | Modify | Auto-continue after the flip; remove ContinueButton |
| `scripts/app/title.gd` | Modify | Left click = Press Start |
| `tests/test_opponent_ai.gd`, `tests/test_turn_loop.gd`, `tests/test_flow_m3.gd` | Create | Unit tests |
| `tests/test_scenario_m2.gd` → `tests/test_scenario.gd` | Rename + modify | Scene smoke test for the turn loop |
| `CLAUDE.md` | Modify | Tick M3, fix draw-replay line, update F5 expectation |

---

### Task 1: BoardState.copy and M3 OpponentAI

**Files:**
- Modify: `scripts/rules/board_state.gd`, `scripts/ai/opponent_ai.gd`
- Test: `tests/test_opponent_ai.gd` (create)

**Interfaces:**
- Produces: `BoardState.copy() -> BoardState` (deep copy of the grid; mutating the copy never changes the original).
- Produces: `static func OpponentAI.choose_column(board: BoardState, rng: RandomNumberGenerator) -> int`. Returns a column 0–6 that is not full, or `-1` if every column is full. Does not mutate `board`.

- [ ] **Step 1: Write the failing tests** in `tests/test_opponent_ai.gd` (`O` = OPPONENT, `P` = PLAYER):
  - `_test_copy_is_independent`: drop P in col 0 on `a`; `b := a.copy()`; drop O in col 1 on `b` → `a.is_empty(1, 0)`, `b.get_owner(0, 0) == P`.
  - `_test_takes_win`: O in cols 0,1,2 row 0; P in cols 0,1,2 row 1 → `choose_column == 3`.
  - `_test_win_beats_block`: O three in col 6 (rows 0–2), P three in row 0 cols 0–2 → returns `6`.
  - `_test_blocks_player`: P in cols 1,2,3 row 0; one O in col 6 → returns `0` (lowest blocking column; `4` also blocks — spec it as **lowest index** among blocking columns, and the same rule for winning columns).
  - `_test_random_is_legal`: fill cols 0–5 with `_fill_owner` (bottom to top) → with seeds 1..20, every result is `6`. (Col 6 empty: confirm in the test that neither side wins or blocks there, i.e. the result came from the random branch — assert `6` regardless.)
  - `_test_random_spread`: empty board, seeds 1..50 → every result in 0..6, and at least 3 distinct values.
  - `_test_full_board_returns_minus_one`: fill all 42 with `_fill_owner` → `-1`.
  - `_test_does_not_mutate`: `to_debug_string()` before == after a call.
- [ ] **Step 2: Run** `godot --headless -s res://tests/test_opponent_ai.gd` → FAIL (`copy` missing; AI returns 3).
- [ ] **Step 3: Implement `BoardState.copy()`** (duplicate `_cells` deeply) **and `OpponentAI.choose_column`**: for each legal column ascending, drop O on a copy and win if `get_outcome() == OPPONENT_WIN`; else same with P for a block; else `rng.randi_range` over the legal columns list. Update the class doc comment (M3 rule; M6 replaces it).
- [ ] **Step 4: Run** the new test → `N checks, 0 failures`, exit 0. Re-run `test_board_state.gd` → still 65/0.
- [ ] **Step 5: Commit and push** `M3: BoardState.copy and win/block/random opponent`.

### Task 2: TurnLoop rules

**Files:**
- Create: `scripts/rules/turn_loop.gd` (`class_name TurnLoop extends RefCounted`)
- Test: `tests/test_turn_loop.gd` (create)

**Interfaces:**
- Consumes: `BoardState` (`drop`, `column_full`, `is_valid_column`, `get_outcome`, `is_board_full`, `reset`).
- Produces:
  - `enum Phase { PLAYER_TURN, OPPONENT_TURN, OVER }`
  - `enum Result { NONE, PLAYER_WIN, OPPONENT_WIN, DRAW }` (DRAW covers both mutual four and full board with no four)
  - `var board: BoardState` (created in `_init`), `var phase: Phase`, `var result: Result`
  - `func start(player_first: bool) -> void` — reset board, `result = NONE`, phase per flip.
  - `func current_side() -> BoardState.CellOwner` — PLAYER / OPPONENT / EMPTY when OVER.
  - `func can_play(column: int) -> bool` — not OVER, valid column, not full.
  - `func play(column: int) -> int` — drops for `current_side()`. Returns landed row, or `-1` with **no state change** if `can_play` is false. After a drop: win check first (`get_outcome()` → PLAYER_WIN / OPPONENT_WIN / DRAW sets `result`, `phase = OVER`); else if `board.is_board_full()` → `DRAW`, OVER; else switch phase.

- [ ] **Step 1: Write the failing tests:**
  - `_test_start_player_first` / `_test_start_opponent_first`: phase and `current_side()` match; board empty; result NONE.
  - `_test_alternates`: start(true); `play(0)` → OPPONENT_TURN, cell (0,0) = P; `play(0)` → PLAYER_TURN, (0,1) = O.
  - `_test_full_column_keeps_turn`: fill col 0 via `board.drop` directly; `play(0) == -1`; still PLAYER_TURN; board unchanged.
  - `_test_invalid_column`: `play(7) == -1`, `play(-1) == -1`, no change.
  - `_test_player_win`: alternate P at cols 0,1,2,3 row 0 with O stacked in col 6 → after P's 4th, result PLAYER_WIN, phase OVER, `current_side() == EMPTY`, `play(5) == -1`.
  - `_test_opponent_win`: start(false), mirror → OPPONENT_WIN.
  - `_test_full_board_draw`: start(true); fill all cells except (6, 5) with `_fill_owner` via `board.drop` (bottom to top per column); `play(6)` → `result == DRAW`, phase OVER.
  - `_test_last_cell_win_beats_full_board`: start(true); fill all except (6, 5) with `_fill_owner`, then `set_owner` (6,2),(6,3),(6,4) to PLAYER; assert `get_outcome() == NONE` before; `play(6)` → PLAYER_WIN, not DRAW.
  - `_test_restart_resets`: after a finished game, `start(true)` → empty board, NONE, PLAYER_TURN.
- [ ] **Step 2: Run** `godot --headless -s res://tests/test_turn_loop.gd` → FAIL (class missing).
- [ ] **Step 3: Implement `scripts/rules/turn_loop.gd`** to the interface above.
- [ ] **Step 4: Run** → 0 failures.
- [ ] **Step 5: Commit and push** `M3: TurnLoop alternation and end result`.

### Task 3: Scenario runs the turn loop

**Files:**
- Modify: `scripts/scenario/scenario_placeholder.gd`, `scenes/scenario/scenario.tscn`, `scripts/core/game_flow.gd`
- Rename + modify: `tests/test_scenario_m2.gd` → `tests/test_scenario.gd` (`git mv`)

**Interfaces:**
- Consumes: `TurnLoop` (Task 2), `OpponentAI.choose_column` (Task 1), `GameFlow.player_moves_first`.
- Produces:
  - `GameFlow.replay_after_draw() -> void` → `go_to(SceneKey.COIN_FLIP)`. Remove `skip_strange_man_on_next_run` and its branch in `begin_play_flow_from_title()` (nothing sets it once draws skip the title).
  - Scenario: `const OPPONENT_DELAY_SEC := 0.6`, `var opponent_delay_sec := OPPONENT_DELAY_SEC` (tests set `0.0`), `var _loop := TurnLoop.new()` (replaces `_board`; read the board as `_loop.board`), `var _rng := RandomNumberGenerator.new()` (randomize in `_ready`).
  - `func try_drop(column: int) -> int` — player entry point. Returns -1 with no feedback if it is not `PLAYER_TURN`; full column → existing `_reject_placement(Toast.MSG_COLUMN_FULL)` and -1; otherwise `_loop.play`, sync view, then `_after_play()`.
  - `func _after_play() -> void` — if OVER → `_show_end()`; if OPPONENT_TURN → `_run_opponent_turn()`; else re-enable input.
  - `func _run_opponent_turn() -> void` — `_board_view.input_enabled = false`; if delay > 0, `await get_tree().create_timer(opponent_delay_sec).timeout` then `if not is_inside_tree(): return`; `_loop.play(OpponentAI.choose_column(_loop.board, _rng))`, drop sound, sync view, `_after_play()`.
  - `func _show_end() -> void` — input off; highlight the winning line for a win (`find_winning_line(PLAYER|OPPONENT)`); ResultLabel text `"Win"`, `"Lose"` or `"Draw"`; show `EndButton` (new Button in HUD/Sidebar, hidden until the end) with text `"Back to title"` (win/lose → `GameFlow.return_to_title()`) or `"Replay"` (draw → `GameFlow.replay_after_draw()`).
- Scene: delete `ResetBoardButton` and its connection; keep `BackToMenuButton`. `_on_column_clicked` accepts **left button only**. `_ready` calls `_loop.start(GameFlow.player_moves_first)`, syncs, then `_after_play()` (so an opponent-first game starts the opponent turn). GridStatusLabel text: drop the "M2 test" line; show whose turn it is ("Your turn" / "Opponent's turn") above the debug grid.

- [ ] **Step 1: Rewrite the scene test** `tests/test_scenario.gd`. Keep the raycast-pick and token-colour checks. Before adding the scene, set `GameFlow.player_moves_first = true`; after instantiation and before `add_child`, set `opponent_delay_sec = 0.0`. Tests:
  - `_test_player_then_opponent`: emit `column_clicked(3, MOUSE_BUTTON_LEFT)`; await 2 frames → (3,0) = P, exactly one O on the board, phase PLAYER_TURN, `view._tokens.size() == 2`.
  - `_test_right_click_ignored`: emit RMB on col 0 → board unchanged.
  - `_test_click_during_opponent_turn`: new scene with `opponent_delay_sec = 5.0`; click col 0, then click col 1 immediately → col 1 empty, only one P on board, `_toast.modulate.a < 0.1`.
  - `_test_full_column_on_player_turn`: fill col 3 via `_loop.board.drop`; click col 3 → toast text `Toast.MSG_COLUMN_FULL`, `_sfx_error.playing`, phase still PLAYER_TURN, board unchanged.
  - `_test_win_shows_end`: preset P at cols 0,1,2 row 0 via `_loop.board.drop` (and O elsewhere with no threat); click col 3 → result label `"Win"`, `%EndButton.visible`, text `"Back to title"`, `view.input_enabled == false`.
  - `_test_draw_shows_replay`: fill all except (6, 5) with `_fill_owner` via `_loop.board.drop`; click col 6 → label `"Draw"`, button `"Replay"`.
  - `_test_opponent_first`: `GameFlow.player_moves_first = false`, delay 0 → after 2 frames exactly one O, phase PLAYER_TURN, input enabled.
  - `_test_free_during_opponent_delay`: delay 0.2; click; `queue_free()` the scene; await a 0.3 s timer → no `printerr`/crash (test reaches its final checks).
  - Free each scene before building the next.
- [ ] **Step 2: Run** `godot --headless -s res://tests/test_scenario.gd` → FAIL.
- [ ] **Step 3: Implement** the scenario, scene and `GameFlow` changes above.
- [ ] **Step 4: Run** `test_scenario.gd` → 0 failures; also `test_board_view_upright.gd`, `test_board_state.gd`, `test_opponent_ai.gd`, `test_turn_loop.gd` → all 0 failures.
- [ ] **Step 5: Commit and push** `M3: scenario turn loop, opponent turn, end overlay, draw replay`.

### Task 4: Click to start, flip goes straight to the scenario

**Files:**
- Modify: `scripts/app/title.gd`, `scripts/ui/coin_flip.gd`, `scenes/ui/coin_flip.tscn`
- Test: `tests/test_flow_m3.gd` (create)

**Interfaces:**
- Produces: `static func is_press_start(event: InputEvent) -> bool` in `title.gd` (no `class_name`; tests call `load("res://scripts/app/title.gd").is_press_start(e)`) — true for a pressed left mouse button or `ui_accept`. `_unhandled_input` uses it. Change the `PressStartLabel` hint text only if it mentions a key; keep "Press Start".
- Produces: coin flip `const RESULT_HOLD_SEC := 1.5` (time to read the result before the scenario loads — not a start step; no click). `_on_flip_pressed` disables Heads, Tails and Flip, sets `GameFlow.player_moves_first`, shows the result, then after `RESULT_HOLD_SEC` calls `GameFlow.go_to(SceneKey.SCENARIO)` (guard with `is_inside_tree()`). Delete `ContinueButton`, its connection and `_on_continue_pressed`. Remove "(Stub animation TBD)" from the result text only if you are touching that line anyway; the animation is M6.

- [ ] **Step 1: Write the failing tests:**
  - `_test_click_is_press_start`: `InputEventMouseButton` with `button_index = MOUSE_BUTTON_LEFT`, `pressed = true` → true; same with `pressed = false` → false; right button → false.
  - `_test_no_continue_button`: instantiate `coin_flip.tscn` → `get_node_or_null("Center/ContinueButton") == null`.
  - `_test_flip_locks_choice`: call `_on_flip_pressed()` → Flip, Heads, Tails buttons `disabled`; `GameFlow.player_moves_first` is a bool matching the result text ("You" ↔ true).
- [ ] **Step 2: Run** `godot --headless -s res://tests/test_flow_m3.gd` → FAIL.
- [ ] **Step 3: Implement** the title and coin flip changes.
- [ ] **Step 4: Run** → 0 failures. Run every suite in `tests/` → all 0 failures.
- [ ] **Step 5: Commit and push** `M3: click to start, coin flip auto-starts scenario`.

### Task 5: Docs, playtest handoff, verification

**Files:** `CLAUDE.md`; vault session log + Decision-Log (via Obsidian / folder access).

- [ ] **Step 1:** In `CLAUDE.md`: tick both M3 boxes; change the M3 marker to M4 "← you are here" only after Sean's playtest passes; Flow line → "Draw → `GameFlow.replay_after_draw()` → coin flip (no Strange Man)"; replace the `skip_strange_man_on_next_run` mention; Now/Next F5 expectation → "click → Strange Man → flip → turn loop vs opponent"; add the new tests to any test list.
- [ ] **Step 2:** Run all suites on 4.6.3: `for t in tests/test_*.gd; do godot --headless -s res://$t; done` → every suite prints `0 failures`, exit 0. Paste the counts into the session log.
- [ ] **Step 3: Commit and push** `M3: docs`.
- [ ] **Step 4:** Give Sean the F5 playtest list and stop:
  1. Click on the title → Strange Man.
  2. Continue → coin flip; pick a side, Flip → result shows, then the scenario loads with no extra click.
  3. If you won the flip you move first; if not, red drops on its own first.
  4. Each left click drops blue, then red answers about half a second later. Clicks during red's turn do nothing. Right click does nothing.
  5. Set up three blue in a row with an open end → red blocks it.
  6. Leave red three in a row with an open end → red takes the win → "Lose" → Back to title.
  7. Get four → "Win" → Back to title.
  8. Full board with no four → "Draw" → Replay → coin flip (no Strange Man).
  9. Full column on your turn → shake, sound, "Column full"; still your turn.

---

## Notes for Sean (choices this plan makes where the spec is silent)

- End text is plain **"Win" / "Lose" / "Draw"** with one button (**"Back to title"** or **"Replay"**). The scoring sequence replaces the win/lose part in M5.
- Red waits **0.6 s** before its drop, and the coin result shows for **1.5 s** before the scenario loads, so you can see what happened. Neither is a click.
- When several columns win or block, red picks the **lowest-numbered** one. The human-like opponent comes in M6.
