extends SceneTree
## Headless test for the scenario scene (M3.5 portrait touch, M3.6 2D board):
## column hit areas, press/hold/release with the blue flash, cancel,
## full-column entry error, red opponent flash, turn timer + timeout roll, drop
## and roll animations, end overlay, draw replay, and the portrait layout with
## simulated safe-area insets; M6b pixel HUD, turn banners, pause menu,
## Normal / Fast / Skip, haptics + screen shake options. Window sizes are physical (project stretch maps
## 1080x1920 to the 720x1280 base).
## Run: godot --headless -s res://tests/test_scenario.gd

const SCENE := "res://scenes/scenario/scenario.tscn"
const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT
const E := BoardState.CellOwner.EMPTY
const PHONE := Vector2i(1080, 1920)

var _failures := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = PHONE # 720×1280 base at 1.5×; headless root defaults to 64×64
	# Never touch the player's settings file; start from the defaults.
	_settings().path = "user://test_settings.cfg"
	_settings().reset()
	var saved_first: bool = _flow().player_moves_first

	await _test_hit_areas()
	await _test_tap_drops_then_opponent()
	await _test_hold_slide_release()
	await _test_release_off_board_cancels()
	await _test_full_column_entry()
	await _test_touch_during_opponent_turn()
	await _test_second_finger_and_mouse_ignored()
	await _test_red_opponent_flash()
	await _test_turn_timer_hud()
	await _test_timeout_random()
	await _test_timeout_is_obvious()
	await _test_timeout_under_finger()
	await _test_timeout_rolls_off_full_column()
	await _test_win_shows_end()
	await _test_draw_shows_replay()
	await _test_opponent_first()
	await _test_free_during_opponent_delay()
	await _test_drop_animation_locks_input()
	await _test_roll_animation()
	await _test_hand_at_start()
	await _test_column_without_selection_ignored()
	await _test_tap_aims_then_drops()
	await _test_drag_drop_and_cancel()
	await _test_small_move_is_tap()
	await _test_double_tap_inspects_hand()
	await _test_double_tap_inspects_board()
	await _test_full_column_greyed()
	await _test_hand_full_toast()
	await _test_timeout_plays_selected()
	await _test_stalemate_replay()
	await _test_hand_fan_layout()
	await _test_sounds()
	await _test_effects_on_board()
	await _test_effect_animations()
	await _test_scoring_sequence()
	await _test_scoring_animated()
	await _test_hud()
	await _test_turn_banners()
	await _test_pause_menu()
	await _test_speed_settings()
	await _test_skip_scoring_sounds()
	await _test_screen_shake_option()
	await _test_m6c_reactions()
	await _test_m6c_fuse()
	await _test_m6c_playtest()
	await _test_layout(PHONE, false)
	await _test_layout(PHONE, true)
	await _test_layout(Vector2i(1080, 2340), true)
	root.size = PHONE

	_flow().player_moves_first = saved_first
	await process_frame
	await process_frame
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Helpers -----------------------------------------------------------------

## GameFlow is an autoload; its name is not a compile-time identifier in -s scripts.
func _flow() -> Node:
	return root.get_node("GameFlow")


func _settings() -> Node:
	return root.get_node("Settings")


func _make(delay: float, player_first := true, flash := 0.0, turn := 30.0, animate := false) -> Control:
	_flow().player_moves_first = player_first
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = animate
	scenario.deck = _vanilla_deck()
	scenario.opponent_delay_sec = delay
	scenario.opponent_flash_sec = flash
	scenario.turn_seconds = turn
	scenario.timeout_reveal_sec = 0.0
	root.add_child(scenario)
	await process_frame
	await process_frame
	return scenario


## 21 Vanilla Goobs: no effects, so turn tests stay deterministic.
func _vanilla_deck() -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	for i in 21:
		goobs.append(TurnLoop.VANILLA)
	return goobs


func _free(scenario: Control) -> void:
	if is_instance_valid(scenario):
		scenario.queue_free()
	await process_frame
	await process_frame


func _view(scenario: Control) -> BoardView2D:
	return scenario.get_node("%BoardView")


func _board(scenario: Control) -> BoardState:
	return scenario._loop.board


func _count(board: BoardState, side: BoardState.CellOwner) -> int:
	var n := 0
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if board.get_owner(column, row) == side:
				n += 1
	return n


## Same pattern as test_turn_loop.gd: a full board with no four; (6,5) is PLAYER.
func _fill_owner(column: int, row: int) -> BoardState.CellOwner:
	return P if ((row / 2) + column) % 2 == 0 else O


func _fill_column(scenario: Control, column: int) -> void:
	var board := _board(scenario)
	for i in BoardState.ROWS:
		board.drop(column, O if i % 2 == 0 else P)
	_view(scenario).sync_from_board(board)


func _glows(view: BoardView2D, cell: Vector2i) -> bool:
	return view.is_highlighted(cell)


## Middle of a column's slot, in viewport coordinates.
func _col_pos(scenario: Control, column: int) -> Vector2:
	var rect: Rect2 = scenario.column_hit_rect(column)
	return Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.3)


func _off_board(scenario: Control) -> Vector2:
	return scenario.get_node("%HudSlot").get_global_rect().get_center()


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true) # viewport (720-base) coords


func _drag(pos: Vector2, index := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	root.push_input(ev, true) # viewport (720-base) coords


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	_touch(pos, false)


## Animated scenarios lock input while the turn's drawn Goob flies in.
func _wait_input(scenario: Control) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame


## Taps hand Goob `index` to select it (clearing any pending double tap).
func _select_hand(scenario: Control, index := 0) -> void:
	scenario._last_tap_key = ""
	var hand: HandView = scenario.get_node("%PlayerHand")
	_tap(hand.slot_center(index))


## Tap style: select a hand Goob, tap the column to aim, tap again to drop.
func _play_col(scenario: Control, column: int, index := 0) -> void:
	_select_hand(scenario, index)
	_tap(_col_pos(scenario, column))
	_tap(_col_pos(scenario, column))


# --- Tests -------------------------------------------------------------------

func _test_hit_areas() -> void:
	var scenario := await _make(0.0)
	var aim: Rect2 = scenario.get_node("%AimLane").get_global_rect()
	var last_right := -1.0
	for column in BoardState.COLUMNS:
		var rect: Rect2 = scenario.column_hit_rect(column)
		_check(scenario.column_at(_col_pos(scenario, column)) == column, "slot hits column %d" % column)
		var in_lane := Vector2(rect.get_center().x, aim.get_center().y)
		_check(scenario.column_at(in_lane) == column, "aim lane hits column %d" % column)
		_check(rect.size.x >= 85.0, "column %d is ≥ 85 px wide (got %.1f)" % [column, rect.size.x])
		_check(rect.position.x > last_right - 0.5, "columns left to right, no overlap")
		last_right = rect.end.x
	_check(scenario.column_at(_off_board(scenario)) == -1, "HUD is off the board")
	_check(scenario.column_at(Vector2(360, 1270)) == -1, "hand zone is off the board")
	await _free(scenario)


func _test_tap_drops_then_opponent() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	_play_col(scenario, 3)
	await process_frame
	_check(board.get_owner(3, 0) == P, "tap drops player at (3,0)")
	_check(_count(board, O) == 1, "opponent replied once (got %d)" % _count(board, O))
	_check(_count(board, P) == 1, "one player token")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "back to player turn")
	_check(view._tokens.size() == 2, "view shows 2 tokens (got %d)" % view._tokens.size())
	_check(scenario._input_enabled, "input re-enabled for player")
	_check(not scenario._flash.visible, "no flash after the drop")
	_check(view.shows_goob(Vector2i(3, 0), BoardView2D.VANILLA, BoardState.CellOwner.PLAYER), "player Goob is blue")
	_check(view._tokens[Vector2i(3, 0)].position == view.cell_position(3, 0), "player Goob sits in its hole")
	for cell in view._tokens:
		if board.get_owner(cell.x, cell.y) == O:
			_check(view.shows_goob(cell, BoardView2D.VANILLA, BoardState.CellOwner.OPPONENT), "opponent Goob is red")
	await _free(scenario)


func _test_hold_slide_release() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	var flash: ColorRect = scenario._flash
	_select_hand(scenario)
	_touch(_col_pos(scenario, 1), true)
	_check(flash.visible, "press shows the flash")
	_check(flash.color.b > flash.color.r, "player flash is blue")
	var lane: Rect2 = scenario.get_node("%AimLane").get_global_rect()
	var rect1: Rect2 = scenario.column_hit_rect(1)
	_check(flash.get_global_rect().is_equal_approx(rect1), "flash covers column 1")
	_check(is_equal_approx(flash.global_position.y, lane.position.y), "flash covers the aim lane")
	_check(_count(board, P) == 0, "holding does not drop")
	var view := _view(scenario)
	_check(view.is_preview_visible(), "held Goob floats over the column")
	_check(view._preview.texture == BoardView2D.VANILLA.still(BoardState.CellOwner.PLAYER), "floating Goob is blue")
	_check(view._preview.position == Vector2(view.cell_position(1, 0).x, BoardView2D.TOP_Y), "floats on top of column 1")
	_drag(_col_pos(scenario, 5))
	_check(flash.get_global_rect().is_equal_approx(scenario.column_hit_rect(5)), "flash follows to column 5")
	_check(view._preview.position.x == view.cell_position(5, 0).x, "floating Goob follows to column 5")
	_touch(_col_pos(scenario, 5), false)
	await process_frame
	_check(board.get_owner(5, 0) == P, "release drops where the finger is (5)")
	_check(board.get_owner(1, 0) != P, "no player Goob in the pressed column")
	_check(not view.is_preview_visible(), "floating Goob gone after the drop")
	await _free(scenario)


func _test_release_off_board_cancels() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 2), true)
	_drag(_off_board(scenario))
	_check(not scenario._flash.visible, "flash hides off the board")
	_check(not _view(scenario).is_preview_visible(), "floating Goob hides off the board")
	_touch(_off_board(scenario), false)
	await process_frame
	_check(_count(board, P) == 0, "release off the board cancels")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "still player turn")
	_check(scenario._touch_column == -1, "cancel clears the timeout column")
	# A press that starts off the board does nothing.
	_touch(_off_board(scenario), true)
	_drag(_col_pos(scenario, 2))
	_touch(_col_pos(scenario, 2), false)
	_check(_count(board, P) == 0, "gesture starting off the board is ignored")
	await _free(scenario)


func _test_full_column_entry() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	var view := _view(scenario)
	_fill_column(scenario, 3)
	var before := board.to_debug_string()
	_select_hand(scenario)
	_touch(_col_pos(scenario, 3), true)
	_check(scenario._toast._label.text == Toast.MSG_COLUMN_FULL, "toast says Column full")
	_check(scenario._toast.modulate.a > 0.9, "toast visible on entry")
	_check(scenario._sfx.history.back() == &"error", "error sound on entry")
	_check(not scenario._flash.visible, "no flash on a full column")
	_check(not view.is_preview_visible(), "no floating Goob over a full column")
	await process_frame
	await process_frame
	_check(view._shake_px != 0, "board shakes on entry")
	# Staying on the column does not repeat the error.
	scenario._toast.modulate.a = 0.0
	_drag(_col_pos(scenario, 3) + Vector2(0, -40))
	_check(scenario._toast.modulate.a < 0.1, "no repeat while staying on the full column")
	# Leaving and coming back does.
	_drag(_col_pos(scenario, 2))
	_check(scenario._flash.visible, "legal column flashes again")
	_drag(_col_pos(scenario, 3))
	_check(scenario._toast.modulate.a > 0.9, "re-entry errors again")
	_touch(_col_pos(scenario, 3), false)
	await process_frame
	_check(board.to_debug_string() == before, "release on a full column: no drop")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "still player turn")
	_check(scenario._touch_column == -1, "release on full clears the timeout column")
	_check(scenario.try_drop(3) == -1, "try_drop on full column returns -1")
	await _free(scenario)


func _test_touch_during_opponent_turn() -> void:
	var scenario := await _make(5.0)
	var board := _board(scenario)
	_play_col(scenario, 0)
	_check(board.get_owner(0, 0) == P, "first tap drops player")
	_tap(_col_pos(scenario, 1))
	_check(board.is_empty(1, 0), "tap during opponent turn ignored")
	_check(not scenario._flash.visible, "no flash during opponent turn")
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "phase is opponent turn")
	_check(not scenario._input_enabled, "input disabled during opponent turn")
	_check(scenario._turn_timer.is_stopped(), "turn timer stopped while input is locked")
	_check(scenario._hud.timer_text() == "—", "no countdown on the opponent's turn (got '%s')" % scenario._hud.timer_text())
	_check(scenario._toast.modulate.a < 0.1, "no toast for out-of-turn tap")
	_check(scenario.try_drop(2) == -1, "try_drop refused during opponent turn")
	await _free(scenario)


func _test_second_finger_and_mouse_ignored() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	_select_hand(scenario)
	_tap(_col_pos(scenario, 1)) # aim; pressing it again drops on release
	_touch(_col_pos(scenario, 1), true, 0)
	_touch(_col_pos(scenario, 4), true, 1)
	_touch(_col_pos(scenario, 4), false, 1)
	_check(_count(board, P) == 0, "second finger does nothing")
	_touch(_col_pos(scenario, 1), false, 0)
	_check(board.get_owner(1, 0) == P, "first finger still drops")
	# Raw mouse clicks are not gameplay input (they arrive as emulated touches).
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = _col_pos(scenario, 6)
		ev.pressed = pressed
		root.push_input(ev, true) # viewport (720-base) coords
	_check(_count(board, P) == 1, "raw mouse click ignored")
	await _free(scenario)


func _test_red_opponent_flash() -> void:
	var scenario := await _make(0.0, true, 0.2)
	var board := _board(scenario)
	_play_col(scenario, 3)
	_check(scenario._flash.visible, "opponent flash shows before its drop")
	_check(scenario._flash.color.r > scenario._flash.color.b, "opponent flash is red")
	_check(_count(board, O) == 0, "opponent has not dropped during the flash")
	var col: int = scenario._opponent_column
	_check(scenario._flash.get_global_rect().is_equal_approx(scenario.column_hit_rect(col)), "flash on the chosen column")
	await create_timer(0.35).timeout
	_check(_count(board, O) == 1, "opponent dropped after the flash")
	var in_col := false
	for row in BoardState.ROWS:
		in_col = in_col or board.get_owner(col, row) == O
	_check(in_col, "dropped in the flashed column")
	_check(not scenario._flash.visible, "flash hidden after the drop")
	await _free(scenario)


func _test_turn_timer_hud() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	_check(scenario.TURN_SECONDS == 30.0, "slice turn limit is 30 s")
	_check(hud.timer_text() == "30" and not hud.is_timer_red(), "countdown shows 30 (got '%s')" % hud.timer_text())
	_check(not scenario._turn_timer.is_stopped(), "timer runs on the player turn")
	await _free(scenario)


func _test_timeout_random() -> void:
	var scenario := await _make(5.0, true, 0.0, 0.2)
	var board := _board(scenario)
	await create_timer(0.35).timeout
	_check(_count(board, P) == 1, "timeout with no touch plays a Goob")
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "turn passes after timeout")
	await _free(scenario)


## Timeout auto-play is announced before the Goob drops (Sean, 2026-11-11).
func _test_timeout_is_obvious() -> void:
	_flow().player_moves_first = true
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = false
	scenario.opponent_delay_sec = 5.0
	scenario.turn_seconds = 0.2
	scenario.timeout_reveal_sec = 0.4
	root.add_child(scenario)
	await process_frame
	var board := _board(scenario)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 4), true)
	await create_timer(0.3).timeout
	_check(scenario._toast._label.text == "Time's up!", "timeout shows Time's up!")
	_check(scenario._toast.modulate.a > 0.9, "Time's up! toast visible")
	_check(scenario._flash.visible, "timeout flashes the column")
	_check(scenario._flash.get_global_rect().is_equal_approx(scenario.column_hit_rect(4)), "flash on the held column")
	_check(_view(scenario).is_preview_visible(), "Goob floats over the timeout column")
	_check(not scenario._input_enabled, "input locked during the reveal")
	_check(scenario._hud.timer_text() == "0" and scenario._hud.is_timer_red(), "timer reads a red 0")
	_check(_count(board, P) == 0, "Goob not dropped yet during the reveal")
	_drag(_col_pos(scenario, 1))
	_touch(_col_pos(scenario, 1), false)
	await create_timer(0.4).timeout
	_check(board.get_owner(4, 0) == P, "then drops in the held column")
	_check(_count(board, P) == 1, "release during the reveal does nothing (P=%d, O=%d, phase=%d)
%s" % [_count(board, P), _count(board, O), scenario._loop.phase, board.to_debug_string()])
	_check(not scenario._flash.visible, "flash gone after the drop")
	_check(not _view(scenario).is_preview_visible(), "floating Goob gone after the timeout drop")
	await _free(scenario)


func _test_timeout_under_finger() -> void:
	var scenario := await _make(5.0, true, 0.0, 0.2)
	var board := _board(scenario)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 2), true)
	await create_timer(0.35).timeout
	_check(board.get_owner(2, 0) == P, "timeout plays into the held column")
	_check(not scenario._flash.visible, "flash cleared at timeout")
	_touch(_col_pos(scenario, 2), false) # the finger lifts later
	_check(_count(board, P) == 1, "late release does not drop again")
	await _free(scenario)


func _test_timeout_rolls_off_full_column() -> void:
	var scenario := await _make(5.0, true, 0.0, 0.2)
	var board := _board(scenario)
	_fill_column(scenario, 6)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 6), true)
	await create_timer(0.35).timeout
	# Column 6 is the right edge: rolling right bounces, rolling left goes 5.
	_check(board.get_owner(5, 0) == P, "held full edge column rolls into 5")
	_check(_count(board, P) == 4, "one new player Goob (3 from the fill)")
	await _free(scenario)


func _test_win_shows_end() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	var end_button: Button = scenario._end_screen.primary_button()
	_check(not scenario.get_node("%EndOverlay").visible, "result overlay hidden during play")
	for c in [0, 1, 2]:
		board.drop(c, P)
	for c in [6, 6, 5]:
		board.drop(c, O)
	view.sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "player wins")
	_check(scenario._end_screen.result_text() == "You win!", "announces You win! (got %s)" % scenario._end_screen.result_text())
	_check(scenario.get_node("%EndOverlay").visible, "result overlay shown")
	_check(end_button.is_visible_in_tree(), "end button visible")
	_check(end_button.text == "Back to title", "end button says Back to title")
	_check(end_button.get_global_rect().size.y >= 96.0, "end button ≥ 96 px tall (got %s)" % end_button.get_global_rect().size)
	_check(not scenario._input_enabled, "input disabled after win")
	_check(scenario._turn_timer.is_stopped(), "timer stopped after win")
	_check(_glows(view, Vector2i(0, 0)) and _glows(view, Vector2i(3, 0)), "winning line highlighted")
	_check(_count(board, O) == 3, "opponent did not move after win")
	_tap(_col_pos(scenario, 4))
	_check(board.is_empty(4, 0), "no drops after win")
	await _free(scenario)


func _test_draw_shows_replay() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if column == 6 and row == 5:
				continue
			board.drop(column, _fill_owner(column, row))
	view.sync_from_board(board)
	_play_col(scenario, 6)
	await process_frame
	var end_button: Button = scenario._end_screen.primary_button()
	_check(scenario._loop.result == TurnLoop.Result.DRAW, "full board is a draw")
	_check(scenario._end_screen.result_text() == "Draw", "announces Draw (got %s)" % scenario._end_screen.result_text())
	_check(scenario.get_node("%EndOverlay").visible, "result overlay shown on draw")
	_check(end_button.is_visible_in_tree(), "end button visible on draw")
	_check(end_button.text == "Replay", "end button says Replay")
	_check(not scenario._input_enabled, "input disabled after draw")
	await _free(scenario)


func _test_opponent_first() -> void:
	var scenario := await _make(0.0, false)
	var board := _board(scenario)
	_check(_count(board, O) == 1, "opponent opens (got %d O)" % _count(board, O))
	_check(_count(board, P) == 0, "no player tokens yet")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "player turn after opener")
	_check(scenario._input_enabled, "input enabled after opener")
	await _free(scenario)


func _test_free_during_opponent_delay() -> void:
	var scenario := await _make(0.2)
	_play_col(scenario, 0)
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "opponent move pending")
	var loop: TurnLoop = scenario._loop # RefCounted: outlives the scene
	scenario.queue_free()
	await create_timer(0.3).timeout
	_check(not is_instance_valid(scenario), "scenario freed during opponent delay")
	_check(loop.phase == TurnLoop.Phase.OPPONENT_TURN, "pending opponent move never fired (phase)")
	_check(_count(loop.board, O) == 0, "pending opponent move never fired (no O on board)")


## Input stays locked while the Goob falls; the turn passes once it lands.
func _test_drop_animation_locks_input() -> void:
	var scenario := await _make(5.0, true, 0.0, 30.0, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var board := _board(scenario)
	_play_col(scenario, 2)
	_check(board.get_owner(2, 0) == P, "grid updates at once")
	_check(not scenario._input_enabled, "input locked while the Goob falls")
	var token: Sprite2D = view._tokens[Vector2i(2, 0)]
	_check(token.position == Vector2(view.cell_position(2, 0).x, BoardView2D.TOP_Y), "Goob appears on top of the board over its column")
	_check(scenario._opponent_timer.is_stopped(), "opponent waits for the landing")
	await create_timer(BoardView2D.TOP_PAUSE_SEC * 0.5).timeout
	_check(token.position.y == BoardView2D.TOP_Y, "Goob pauses on top of the board")
	await create_timer(BoardView2D.TOP_PAUSE_SEC * 0.5 + 0.1).timeout
	_check(token.position.y > BoardView2D.TOP_Y, "then falls")
	_check(token.position == token.position.round(), "Goob moves on whole game pixels")
	await create_timer(0.6).timeout
	_check(token.position == view.cell_position(2, 0), "Goob landed in its hole")
	_check(not scenario._opponent_timer.is_stopped(), "opponent turn started after the landing")
	await _free(scenario)


## Timeout into a full column: the Goob rolls on top of the board, bouncing
## off the edge, then falls into the first open column.
func _test_roll_animation() -> void:
	var scenario := await _make(5.0, true, 0.0, 0.2, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var board := _board(scenario)
	_fill_column(scenario, 6)
	_fill_column(scenario, 5)
	var right: Array[int] = scenario._roll_path(6, true)
	var left: Array[int] = scenario._roll_path(6, false)
	var open: Array[int] = scenario._roll_path(2, true)
	_check(right == [6, 7, 5, 4], "roll path bounces off the right edge (got %s)" % str(right))
	_check(left == [6, 5, 4], "roll path left (got %s)" % str(left))
	_check(open == [2], "open column: no roll (got %s)" % str(open))
	_select_hand(scenario)
	_touch(_col_pos(scenario, 6), true)
	await create_timer(0.3).timeout
	_check(board.get_owner(4, 0) == P, "timeout Goob lands in column 4")
	var token: Sprite2D = view._tokens[Vector2i(4, 0)]
	_check(token.position == Vector2(view.cell_position(6, 0).x, BoardView2D.TOP_Y), "Goob appears on top of the full column first (%s)" % token.position)
	_check(not scenario._input_enabled, "input locked while rolling")
	var rolled_on_top := false
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline and token.position != view.cell_position(4, 0):
		await process_frame
		if token.position.y == BoardView2D.TOP_Y and token.position.x < view.cell_position(6, 0).x:
			rolled_on_top = true
	_check(rolled_on_top, "Goob rolls along the top before falling")
	_check(token.position == view.cell_position(4, 0), "rolled Goob ends in its hole")
	_touch(_col_pos(scenario, 6), false)
	await _free(scenario)


# --- M5 effects + scoring ------------------------------------------------------

const CONVINCING := preload("res://resources/goobs/convincing_goob.tres")
const FAT := preload("res://resources/goobs/fat_goob.tres")
const POPULAR := preload("res://resources/goobs/popular_goob.tres")
const PLENTIFUL := preload("res://resources/goobs/plentiful_goob.tres")


## Puts `goob` in the player's hand at index 0 (model and fan).
func _give(scenario: Control, goob: GoobDefinition) -> void:
	scenario._loop.player_deck.hand[0] = goob
	scenario.get_node("%PlayerHand").rebuild(scenario._loop.player_deck.hand)


## Every board Goob has exactly one view token, sitting in its hole.
func _view_matches(scenario: Control) -> bool:
	var view := _view(scenario)
	var board := _board(scenario)
	var n := 0
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var cell := Vector2i(c, r)
			if board.is_empty(c, r):
				continue
			n += 1
			if not view._tokens.has(cell) or view._token_owner[cell] != board.get_owner(c, r):
				return false
			var token: Sprite2D = view._tokens[cell]
			if token.position != view.cell_position(c, r):
				return false
			# Each Goob shows its own type's still (Art pass D2); unknown = Vanilla
			var goob: GoobDefinition = scenario._loop.goob_at(c, r)
			if goob == null:
				goob = BoardView2D.VANILLA
			if not view.shows_goob(cell, goob, board.get_owner(c, r)):
				return false
	return n == view._tokens.size()


func _test_effects_on_board() -> void:
	# Convincing: the only adjacent enemy turns blue.
	var scenario := await _make(5.0)
	var board := _board(scenario)
	board.drop(2, O)
	_view(scenario).sync_from_board(board)
	_give(scenario, CONVINCING)
	_play_col(scenario, 3)
	await process_frame
	_check(board.get_owner(2, 0) == P, "convincing (scenario): enemy flipped")
	_check(_view_matches(scenario), "convincing: view matches the board")
	await _free(scenario)
	# Fat: a neighbour is destroyed and the one above falls.
	scenario = await _make(5.0)
	board = _board(scenario)
	board.drop(2, O)
	board.drop(2, O)
	board.drop(2, O)
	_view(scenario).sync_from_board(board)
	_give(scenario, FAT)
	_play_col(scenario, 3)
	await process_frame
	_check(_count(board, O) == 2, "fat (scenario): one enemy destroyed")
	_check(board.lowest_empty_row(2) == 2, "fat (scenario): Goobs above fell")
	_check(_view_matches(scenario), "fat: view matches the board")
	await _free(scenario)
	# Popular: a second blue Goob appears.
	scenario = await _make(5.0)
	board = _board(scenario)
	_give(scenario, POPULAR)
	_play_col(scenario, 3)
	await process_frame
	_check(_count(board, P) == 2, "popular (scenario): extra Vanilla dropped")
	_check(_view_matches(scenario), "popular: view matches the board")
	await _free(scenario)
	# Plentiful: two more Goobs in the fan.
	scenario = await _make(5.0)
	var hand: HandView = scenario.get_node("%PlayerHand")
	_give(scenario, PLENTIFUL)
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.player_deck.hand.size() == 4, "plentiful (scenario): 3 - 1 + 2 in hand")
	_check(hand.count() == 4, "plentiful: fan shows 4 (got %d)" % hand.count())
	await _free(scenario)


## With animation on, each effect plays its impact (sound) and the view ends
## matching the board before the opponent's turn starts.
func _test_effect_animations() -> void:
	for setup in [[CONVINCING, &"flip"], [FAT, &"crunch"], [POPULAR, &"popular"], [PLENTIFUL, &"draw_pop"]]:
		var goob: GoobDefinition = setup[0]
		var sound: StringName = setup[1]
		var scenario := await _make(5.0, true, 0.0, 30.0, true)
		await _wait_input(scenario)
		var board := _board(scenario)
		board.drop(2, O)
		board.drop(2, O)
		board.drop(2, O)
		_view(scenario).sync_from_board(board)
		_give(scenario, goob)
		_play_col(scenario, 3)
		var deadline := Time.get_ticks_msec() + 8000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "%s: play finishes, opponent's turn starts" % goob.id)
		_check(scenario._sfx.history.has(sound), "%s: impact sound %s" % [goob.id, sound])
		_check(_view_matches(scenario), "%s: animated view matches the board" % goob.id)
		await _free(scenario)
	# No target: fizzle cue.
	var scenario := await _make(5.0, true, 0.0, 30.0, true)
	await _wait_input(scenario)
	_give(scenario, CONVINCING)
	_play_col(scenario, 3)
	var deadline := Time.get_ticks_msec() + 3000
	while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(scenario._sfx.history.has(&"fizzle"), "no target: fizzle sound")
	_check(_view(scenario)._tokens[Vector2i(3, 0)].modulate == Color.WHITE, "fizzle: Goob back to normal")
	await _free(scenario)


func _test_scoring_sequence() -> void:
	var scenario := await _make(5.0)
	var board := _board(scenario)
	for c in 3:
		board.drop(c, P)
	_view(scenario).sync_from_board(board)
	_give(scenario, PLENTIFUL) # ×0.5, no board change
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "scoring: player wins")
	_check(scenario.sum_label != null and scenario.sum_label.text == "3.5", "scoring: sum 1+1+1+0.5 = 3.5 (got %s)" % (scenario.sum_label.text if scenario.sum_label else "none"))
	_check(scenario.score_labels.is_empty(), "scoring: multipliers collapsed into the sum")
	var history: Array[StringName] = scenario._sfx.history
	var ladder := history.filter(func(s: StringName) -> bool: return String(s).begins_with("score_"))
	_check(ladder == [&"score_recognise", &"score_0", &"score_1", &"score_2", &"score_3", &"score_collapse", &"score_4"], "scoring: rising ladder, collapse, sum on the top note (got %s)" % str(ladder))
	_check(scenario.get_node("%EndOverlay").visible, "scoring: then the result overlay")
	for c in 4:
		_check(_view(scenario).has_gold_outline(Vector2i(c, 0)), "scoring: scored Goob %d has the gold outline" % c)
	_check(scenario.format_score(1.0) == "1" and scenario.format_score(0.5) == "0.5" and scenario.format_score(3.5) == "3.5", "scoring: number format")
	await _free(scenario)
	# A draw has no scoring sequence.
	scenario = await _make(5.0)
	board = _board(scenario)
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if c == 6 and r == 5:
				continue
			board.drop(c, _fill_owner(c, r))
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 6)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.DRAW, "scoring: full board draw")
	_check(scenario.sum_label == null, "scoring: draws skip the sequence")
	await _free(scenario)


## M6c: portrait thinking / angry, end lead-in faces, defeat explodes the bust.
func _test_m6c_reactions() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	_play_col(scenario, 0)
	await process_frame
	_check(hud.portrait_face() == &"thinking", "m6c: portrait thinks during the opponent's delay (got %s)" % hud.portrait_face())
	await _free(scenario)
	# Blocking his open three makes him angry.
	scenario = await _make(5.0)
	hud = scenario._hud
	var board := _board(scenario)
	for c in 3:
		board.drop(c, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	_check(hud.portrait_face() == &"angry", "m6c: a block makes him angry (got %s)" % hud.portrait_face())
	await _free(scenario)
	# Player win: winning four celebrates, portrait says well played then explodes.
	scenario = await _make(5.0)
	hud = scenario._hud
	board = _board(scenario)
	for c in 3:
		board.drop(c, P)
	board.drop(6, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	await process_frame
	_check(_view(scenario).face_at(Vector2i(0, 0)) == &"celebrating", "m6c: winning four celebrates")
	_check(_view(scenario).face_at(Vector2i(6, 0)) == &"sad", "m6c: loser's Goob is sad")
	_check(hud.portrait_face() == &"exploded", "m6c: portrait explodes on a player win (got %s)" % hud.portrait_face())
	_check(scenario._sfx.history.has(&"win_sting"), "m6c: win sting")
	await _free(scenario)
	# Opponent win: he celebrates, his four celebrates, your Goobs are sad.
	scenario = await _make(0.0)
	hud = scenario._hud
	board = _board(scenario)
	for r in 3:
		board.drop(5, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 0)
	await process_frame
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.OPPONENT_WIN, "m6c: opponent takes his four")
	_check(hud.portrait_face() == &"celebrating", "m6c: portrait celebrates his win (got %s)" % hud.portrait_face())
	_check(_view(scenario).face_at(Vector2i(0, 0)) == &"sad", "m6c: your Goobs are sad when he wins")
	_check(scenario._sfx.history.has(&"lose_sting"), "m6c: lose sting")
	await _free(scenario)


## M6c playtest (Sean): drawn Goob's name above the board; hand reacts to the
## result; the end overlay minimises to review and inspect the board.
func _test_m6c_playtest() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	_check(hud.caption_text() == "Vanilla Goob", "playtest: drawn Goob's name shows above the board (got '%s')" % hud.caption_text())
	var board := _board(scenario)
	for c in 3:
		board.drop(c, P)
	board.drop(6, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	await process_frame
	var hand: HandView = scenario.get_node("%PlayerHand")
	_check(hand.count() > 0 and hand.face_of(0) == &"happy", "playtest: hand Goobs happy on a win (got %s)" % hand.face_of(0))
	var overlay: Control = scenario.get_node("%EndOverlay")
	_check(overlay.visible, "playtest: result overlay up")
	scenario._end_screen.view_button().pressed.emit()
	_check(scenario.is_reviewing() and not overlay.visible, "playtest: View board minimises the overlay")
	_check(scenario._hud.show_result_button().visible, "playtest: Show result button while reviewing")
	scenario._last_tap_key = ""
	_tap(_view(scenario).cell_center(Vector2i(3, 0)))
	_tap(_view(scenario).cell_center(Vector2i(3, 0)))
	_check(scenario._inspect.is_open(), "playtest: double tap inspects a board Goob after the end")
	_tap(_view(scenario).cell_center(Vector2i(3, 0)))
	_check(not scenario._inspect.is_open(), "playtest: next tap closes the inspect view")
	scenario._hud.show_result_button().pressed.emit()
	_check(not scenario.is_reviewing() and overlay.visible, "playtest: Show result restores the overlay")
	await _free(scenario)
	# Loss: hand Goobs are sad.
	scenario = await _make(0.0)
	board = _board(scenario)
	for r in 3:
		board.drop(5, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 0)
	await process_frame
	await process_frame
	hand = scenario.get_node("%PlayerHand")
	_check(hand.count() > 0 and hand.face_of(0) == &"sad", "playtest: hand Goobs sad on a loss (got %s)" % hand.face_of(0))
	await _free(scenario)


## M6c: the fuse burns only for the last 10 s, with worried hand Goobs.
func _test_m6c_fuse() -> void:
	var scenario := await _make(5.0, true, 0.0, 10.4)
	await _wait_input(scenario)
	var fuse: FuseStrip = scenario._fuse
	var hand: HandView = scenario.get_node("%PlayerHand")
	await process_frame
	_check(not fuse.visible, "fuse: hidden above 10 s left")
	_check(hand.face_of(0) == &"idle", "fuse: hand idle before the fuse (got %s)" % hand.face_of(0))
	await create_timer(0.6).timeout
	_check(fuse.visible, "fuse: burns in the last 10 s")
	_check(fuse.fraction_left() < 1.0 and fuse.fraction_left() > 0.8, "fuse: almost whole at ~9.8 s (got %.2f)" % fuse.fraction_left())
	_check(hand.face_of(0) == &"worried", "fuse: hand Goobs worried (got %s)" % hand.face_of(0))
	_check(scenario._fuse_sound.playing, "fuse: crackle loop plays")
	_play_col(scenario, 3)
	await process_frame
	await process_frame
	_check(not fuse.visible and not scenario._fuse_sound.playing, "fuse: gone once the Goob is played")
	await _free(scenario)


## Balatro rhythm: multipliers appear one by one before the sum and overlay.
func _test_scoring_animated() -> void:
	var scenario := await _make(5.0, true, 0.0, 30.0, true)
	await _wait_input(scenario)
	var board := _board(scenario)
	for c in 3:
		board.drop(c, P)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	var overlay: Control = scenario.get_node("%EndOverlay")
	var seen := 0
	var sum_before_overlay := false
	var deadline := Time.get_ticks_msec() + 10000
	while not overlay.visible and Time.get_ticks_msec() < deadline:
		seen = maxi(seen, scenario.score_labels.size())
		if scenario.sum_label != null:
			sum_before_overlay = true
		await process_frame
	_check(seen == 4, "animated scoring: four multipliers shown (max %d)" % seen)
	_check(sum_before_overlay, "animated scoring: sum shown before the overlay")
	_check(overlay.visible, "animated scoring: overlay arrives")
	_check(scenario.sum_label.text == "4", "animated scoring: four Vanilla = 4")
	await _free(scenario)


## Top area, board and hand stack inside the safe area; the board sits in
## the middle when there is room; Quit is top right; the table starts under
## the board.
func _test_layout(size: Vector2i, insets: bool) -> void:
	root.size = size
	SafeArea.simulate_insets = insets
	var scenario := await _make(5.0)
	await process_frame
	await process_frame
	var tag := "%s insets=%s" % [str(size), str(insets)]
	var view_size := root.get_visible_rect().size # logical, 720 wide
	var top := float(SafeArea.SIM_TOP if insets else 0)
	var bottom := view_size.y - float(SafeArea.SIM_BOTTOM if insets else 0)
	var top_area: Rect2 = scenario.get_node("%TopArea").get_global_rect()
	var board: Rect2 = scenario.get_node("%BoardView").get_global_rect()
	var hand: Rect2 = scenario.get_node("%PlayerHand").get_global_rect()
	_check(top_area.position.y >= top - 0.5, "%s: top area under the top inset" % tag)
	_check(board.position.y >= top_area.end.y - 0.5 and hand.position.y >= board.end.y - 0.5, "%s: zones in order" % tag)
	_check(hand.end.y <= bottom + 0.5, "%s: hand zone above the home strip (%.0f ≤ %.0f)" % [tag, hand.end.y, bottom])
	_check(hand.size.y >= 170.0, "%s: hand zone ≥ 170 px" % tag)
	var lane: Rect2 = scenario.get_node("%AimLane").get_global_rect()
	_check(is_equal_approx(lane.end.y, board.position.y), "%s: aim lane right above the board" % tag)
	if top_area.size.y > scenario.get_node("%TopArea").get_combined_minimum_size().y + 0.5:
		var mid := (top + bottom) * 0.5
		_check(absf(board.get_center().y - mid) < 1.0, "%s: board centred (%.0f vs %.0f)" % [tag, board.get_center().y, mid])
	var hud: ScenarioHud = scenario._hud
	var pause_rect := hud.pause_button().get_global_rect()
	_check(pause_rect.position.x <= 30.0 and pause_rect.end.y <= bottom + 0.5 and pause_rect.end.y >= bottom - 40.0, "%s: Pause bottom left in the safe area (%s)" % [tag, pause_rect])
	_check(pause_rect.size.x >= 96.0 and pause_rect.size.y >= 96.0, "%s: Pause button ≥ 96 px (%s)" % [tag, pause_rect.size])
	_check(hud.bottom() <= lane.position.y + 0.5, "%s: HUD above the aim lane (%.0f ≤ %.0f)" % [tag, hud.bottom(), lane.position.y])
	var block: Rect2 = hud._block.get_global_rect()
	_check(block.position.y >= top - 0.5, "%s: HUD block under the top inset" % tag)
	_check(scenario.column_hit_rect(3).size.x >= 85.0, "%s: columns ≥ 85 px" % tag)
	var view := _view(scenario)
	_check(view.pixel_scale == 4, "%s: board at 4× physical (got %d)" % [tag, view.pixel_scale])
	var origin_phys: Vector2 = view._pixel.global_position * 1.5
	_check(origin_phys.is_equal_approx(origin_phys.round()), "%s: board origin on a whole physical pixel (%s)" % [tag, origin_phys])
	_check(view.column_rect(0).position.x >= board.position.x - 0.5 and view.column_rect(6).end.x <= board.end.x + 0.5, "%s: columns inside the board zone" % tag)
	var stump: Rect2 = scenario.get_node("%Stump").get_global_rect()
	_check(stump.position.x < 0.0 and stump.end.x > view_size.x, "%s: stump base runs off both screen edges" % tag)
	_check(absf(stump.get_center().x - view_size.x * 0.5) < 1.0, "%s: stump centred" % tag)
	_check(stump.position.y > board.get_center().y, "%s: stump below the board" % tag)
	_check(stump.end.y >= view_size.y - 0.5, "%s: stump runs off the screen bottom" % tag)
	SafeArea.simulate_insets = false
	await _free(scenario)


# --- M4: decks and hands --------------------------------------------------------

func _hand_view(scenario: Control) -> HandView:
	return scenario.get_node("%PlayerHand")


func _test_hand_at_start() -> void:
	var scenario := await _make(0.0)
	var hand := _hand_view(scenario)
	_check(scenario._loop.player_deck.hand.size() == 3, "start: player holds 2 + turn draw")
	_check(hand.count() == 3, "start: fan shows 3 (got %d)" % hand.count())
	_check(scenario._input_enabled, "start: input on after the draw reveal")
	await _free(scenario)
	scenario = await _make(0.0, false)
	_check(_hand_view(scenario).count() == 3, "opp first: fan shows 3 after its opener")
	_check(scenario._loop.opponent_deck.hand.size() == 2, "opp first: opponent played 1 of 3")
	await _free(scenario)


func _test_column_without_selection_ignored() -> void:
	var scenario := await _make(0.0)
	_touch(_col_pos(scenario, 2), true)
	_check(not scenario._flash.visible, "no selection: no flash")
	_check(not _view(scenario).is_preview_visible(), "no selection: no float")
	_drag(_col_pos(scenario, 4))
	await create_timer(0.3).timeout
	_touch(_col_pos(scenario, 4), false)
	_check(_count(_board(scenario), P) == 0, "no selection: hold + release does not drop")
	_check(scenario._toast.modulate.a < 0.1, "no selection: no toast")
	await _free(scenario)


func _test_tap_aims_then_drops() -> void:
	var scenario := await _make(5.0)
	var board := _board(scenario)
	var hand := _hand_view(scenario)
	_select_hand(scenario, 2)
	_check(scenario._selected == 2 and hand.selected() == 2, "tap selects hand Goob 2")
	var chosen: GoobDefinition = scenario._loop.player_deck.hand[2]
	_tap(_col_pos(scenario, 1))
	_check(_count(board, P) == 0, "quick tap on a column only aims")
	_check(scenario._flash.visible and _view(scenario).is_preview_visible(), "aim shows flash + float after the tap")
	_tap(_col_pos(scenario, 4))
	_check(_count(board, P) == 0, "tapping another column moves the aim")
	_check(scenario._flash.get_global_rect().is_equal_approx(scenario.column_hit_rect(4)), "flash moved to column 4")
	_tap(_col_pos(scenario, 4))
	_check(board.get_owner(4, 0) == P, "tapping the aimed column again drops")
	_check(scenario._loop.goob_at(4, 0) == chosen, "the selected Goob was played")
	_check(hand.count() == 2, "played Goob left the fan")
	_check(not scenario._flash.visible, "aim cleared after the drop")
	await _free(scenario)


func _test_drag_drop_and_cancel() -> void:
	var scenario := await _make(5.0)
	var board := _board(scenario)
	var hand := _hand_view(scenario)
	scenario._last_tap_key = ""
	var start := hand.slot_center(1)
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_check(hand.is_dragging(), "moving > 12 px starts a drag")
	_drag(_off_board(scenario))
	_touch(_off_board(scenario), false)
	_check(_count(board, P) == 0, "release off the board cancels")
	_check(not hand.is_dragging() and hand.count() == 3, "Goob flies back to the hand")
	_check(scenario._selected == -1, "cancel deselects")
	scenario._last_tap_key = ""
	var chosen: GoobDefinition = scenario._loop.player_deck.hand[0]
	start = hand.slot_center(0)
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_drag(_col_pos(scenario, 5))
	_check(scenario._flash.visible, "dragging over a column flashes it")
	_check(_view(scenario).is_preview_visible(), "ghost floats over the column")
	_check(not hand._cards[0].visible, "dragged Goob hides while the float shows it")
	_touch(_col_pos(scenario, 5), false)
	_check(board.get_owner(5, 0) == P, "release over the board drops")
	_check(scenario._loop.goob_at(5, 0) == chosen, "the dragged Goob was played")
	_check(hand.count() == 2, "fan closes up")
	await _free(scenario)


func _test_small_move_is_tap() -> void:
	var scenario := await _make(5.0)
	var hand := _hand_view(scenario)
	scenario._last_tap_key = ""
	var start := hand.slot_center(2)
	_touch(start, true)
	_drag(start + Vector2(5, -5))
	_check(not hand.is_dragging(), "a 7 px move is not a drag")
	_touch(start + Vector2(5, -5), false)
	_check(scenario._selected == 2, "small move + release selects")
	await _free(scenario)


func _test_double_tap_inspects_hand() -> void:
	var scenario := await _make(5.0)
	var hand := _hand_view(scenario)
	var inspect: InspectPanel = scenario._inspect
	var goob: GoobDefinition = scenario._loop.player_deck.hand[1]
	_select_hand(scenario, 1)
	_tap(hand.slot_center(1))
	_check(inspect.is_open(), "double tap opens inspect")
	_check(inspect.name_text() == goob.display_name, "inspect shows the name")
	_check(inspect.effect_text() == goob.effect_description, "inspect shows the card text")
	_tap(_col_pos(scenario, 3))
	_check(not inspect.is_open(), "next tap closes inspect")
	_check(_count(_board(scenario), P) == 0 and not scenario._flash.visible, "closing tap does nothing else")
	await _free(scenario)


func _test_double_tap_inspects_board() -> void:
	var scenario := await _make(5.0)
	var board := _board(scenario)
	var view := _view(scenario)
	var vanilla: GoobDefinition = load("res://resources/goobs/vanilla_goob.tres")
	board.drop(2, O)
	scenario._loop._cell_goobs[Vector2i(2, 0)] = vanilla
	view.sync_from_board(board)
	var rect := view.column_rect(2)
	var cell_pos := Vector2(rect.get_center().x, rect.end.y - 20.0)
	_check(view.cell_at(cell_pos) == Vector2i(2, 0), "cell_at finds (2,0)")
	_tap(cell_pos)
	_tap(cell_pos)
	_check(scenario._inspect.is_open(), "double tap on a board Goob inspects (nothing selected)")
	_check(scenario._inspect.effect_text() == "", "Vanilla: name + flavour only")
	_check(scenario._inspect.flavour_text() == vanilla.flavour_text and vanilla.flavour_text != "",
			"inspect shows the Goob's flavour line")
	_tap(cell_pos)
	_check(not scenario._inspect.is_open(), "tap closes it")
	_select_hand(scenario)
	_tap(cell_pos)
	_tap(cell_pos)
	_check(not scenario._inspect.is_open(), "with a Goob selected a board double tap does not inspect")
	_check(board.get_owner(2, 1) == P, "... it aims and drops instead")
	await _free(scenario)


func _test_full_column_greyed() -> void:
	var scenario := await _make(5.0)
	_fill_column(scenario, 3)
	_check(not scenario._grey[3].visible, "no grey without a selection")
	_select_hand(scenario)
	_check(scenario._grey[3].visible, "full column greyed while a Goob is selected")
	_check(not scenario._grey[2].visible, "open column not greyed")
	await _free(scenario)


func _test_hand_full_toast() -> void:
	var scenario := await _make(0.0, true, 0.0, 30.0)
	var loop: TurnLoop = scenario._loop
	# As after Plentiful: the player's hand is full when their next turn starts.
	while loop.player_deck.hand.size() < Deck.HAND_MAX + 1:
		loop.player_deck.hand.append(loop.player_deck.hand[0])
	_hand_view(scenario).rebuild(loop.player_deck.hand)
	scenario.try_drop(0, 0)
	await process_frame
	_check(loop.phase == TurnLoop.Phase.PLAYER_TURN, "hand full: player's turn again")
	_check(loop.last_draw_hand_full, "hand full: draw skipped")
	_check(scenario._toast._label.text == "Hand full", "hand full: toast")
	_check(_heard(scenario, &"hand_full"), "hand full: sound")
	_check(_hand_view(scenario).count() == Deck.HAND_MAX, "hand full: fan holds 5")
	await process_frame
	_check(scenario.position.x != 0.0, "hand full: screen shakes")
	await create_timer(0.4).timeout
	_check(scenario.position.x == 0.0, "hand full: shake settles")
	await _free(scenario)


func _test_timeout_plays_selected() -> void:
	var scenario := await _make(5.0, true, 0.0, 0.2)
	var chosen: GoobDefinition = scenario._loop.player_deck.hand[2]
	_select_hand(scenario, 2)
	await create_timer(0.35).timeout
	var played: GoobDefinition = null
	for column in BoardState.COLUMNS:
		if scenario._loop.goob_at(column, 0) != null:
			played = scenario._loop.goob_at(column, 0)
	_check(played == chosen, "timeout plays the selected Goob")
	_check(_hand_view(scenario).count() == 2, "timeout Goob left the fan")
	await _free(scenario)


func _test_stalemate_replay() -> void:
	var scenario := await _make(0.0)
	var loop: TurnLoop = scenario._loop
	loop.opponent_deck.hand.clear()
	loop.opponent_deck.draw_pile.clear()
	loop.player_deck.draw_pile.clear()
	loop.player_deck.hand.resize(1)
	_hand_view(scenario).rebuild(loop.player_deck.hand)
	_play_col(scenario, 0)
	await process_frame
	_check(loop.result == TurnLoop.Result.DRAW, "stalemate: draw")
	_check(not loop.board.is_board_full(), "stalemate: board not full")
	_check(scenario._end_screen.result_text() == "Draw", "stalemate: announces Draw")
	_check(scenario._end_screen.primary_button().text == "Replay", "stalemate: Replay")
	await _free(scenario)


func _test_hand_fan_layout() -> void:
	var scenario := await _make(5.0)
	var hand := _hand_view(scenario)
	var loop: TurnLoop = scenario._loop
	loop.player_deck.hand.append(loop.player_deck.hand[0])
	hand.rebuild(loop.player_deck.hand)
	var px := _view(scenario).hand_px()
	_check(is_equal_approx(px * 1.5, 5.0), "hand Goobs at 5x physical (got %.2f)" % (px * 1.5))
	var goob := HandView.GOOB_PX * px
	_check(goob >= 96.0, "hand Goob >= 96 px (got %.1f)" % goob)
	var zone := hand.get_global_rect()
	for i in hand.count():
		var c := hand.slot_center(i)
		_check(c.x - goob * 0.5 >= 24.0 - 0.5 and c.x + goob * 0.5 <= zone.end.x - 24.0 + 0.5, "card %d >= 24 px from the sides" % i)
		_check(c.y + goob * 0.5 <= zone.end.y + 0.5, "card %d inside the hand zone" % i)
		if i > 0:
			_check(c.x - hand.slot_center(i - 1).x >= goob, "cards %d/%d do not overlap" % [i - 1, i])
		_check(hand.goob_at(c) == i, "card %d hit-tests" % i)
	await _free(scenario)


func _heard(scenario: Control, sound: StringName) -> bool:
	return scenario._sfx.history.has(sound)


## Every M4 event has its sound (slice §2B Sound), alongside its visual cue.
func _test_sounds() -> void:
	var scenario := await _make(5.0, true, 0.0, 30.0, true)
	await _wait_input(scenario)
	_check(_heard(scenario, &"draw_pop") and _heard(scenario, &"fly"), "sound: draw pop + fly into the fan")
	var hand := _hand_view(scenario)
	_select_hand(scenario, 0)
	_check(_heard(scenario, &"select"), "sound: select")
	_tap(_col_pos(scenario, 1))
	_check(_heard(scenario, &"column_tick"), "sound: first column touch clicks")
	_tap(_col_pos(scenario, 2))
	_check(_heard(scenario, &"column_tick"), "sound: column change tick")
	_tap(hand.slot_center(0))
	_check(scenario._inspect.is_open() and _heard(scenario, &"inspect_open"), "sound: inspect open")
	_tap(_off_board(scenario))
	_check(_heard(scenario, &"inspect_close"), "sound: inspect close")
	scenario._last_tap_key = ""
	var start := hand.slot_center(1)
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_check(_heard(scenario, &"drag"), "sound: drag pickup")
	_drag(_off_board(scenario))
	_touch(_off_board(scenario), false)
	_check(_heard(scenario, &"cancel"), "sound: cancel fly-back")
	_play_col(scenario, 3)
	await create_timer(0.1).timeout
	_check(_heard(scenario, &"rest"), "sound: rest on top")
	await create_timer(0.6).timeout
	_check(_heard(scenario, &"fall") and _heard(scenario, &"land"), "sound: fall + land")
	await _free(scenario)
	scenario = await _make(5.0, true, 0.0, 0.2)
	_fill_column(scenario, 6)
	_fill_column(scenario, 5)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 6), true)
	await create_timer(0.3).timeout
	_check(_heard(scenario, &"times_up"), "sound: Time's up!")
	_touch(_col_pos(scenario, 6), false)
	await _free(scenario)
	scenario = await _make(5.0, true, 0.0, 0.2, true)
	await _wait_input(scenario)
	_fill_column(scenario, 6)
	_fill_column(scenario, 5)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 6), true)
	await create_timer(1.2).timeout
	_check(_heard(scenario, &"roll"), "sound: roll")
	_touch(_col_pos(scenario, 6), false)
	await _free(scenario)


# --- M6b: HUD, banners, pause, options ------------------------------------------

func _test_hud() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	_check(hud.objective() == "Get four in a row", "HUD: objective text")
	_check(hud._block.find_children("*", "Label", true, false).all(func(l: Label) -> bool: return l.text != "Objective"), "HUD: no Objective heading")
	_check(hud._scenario.text == "1", "HUD: scenario shows 1")
	await process_frame
	var emblem: Rect2 = hud._emblem.get_global_rect()
	var block: Rect2 = hud._block.get_global_rect()
	_check(block.encloses(emblem) and absf(emblem.get_center().x - block.get_center().x) < 30.0, "HUD: timer emblem inside the block, centre section")
	_check(hud._objective.get_global_rect().position.y >= emblem.end.y - 0.5, "HUD: objective under the emblem")
	var ribbon: Rect2 = hud._ribbon.get_global_rect()
	var board_top: float = scenario.get_node("%BoardView").get_global_rect().position.y
	_check(ribbon.position.y >= hud.bottom() - 0.5 and ribbon.end.y <= board_top + 0.5, "HUD: banner band between the HUD and the board (%s, %.0f..%.0f)" % [ribbon, hud.bottom(), board_top])
	_check(hud.stage.k > 0.0 and hud._block.size == Vector2(258, 76), "HUD: one 76 px block across the screen (%s)" % hud._block.size)
	var portrait: TextureRect = hud._block.get_child(0)
	_check(portrait.texture == ScenarioHud.PORTRAIT and portrait.size == Vector2(64, 64), "HUD: Strange Man bust at 1:1 (64 px)")
	hud.set_seconds(11)
	_check(not hud.is_timer_red(), "HUD: 11 s not red")
	hud.set_seconds(10)
	_check(hud.is_timer_red() and hud.timer_text() == "10", "HUD: last 10 s red")
	# A touch on the Pause button never starts a gesture (or selects a Goob).
	await process_frame
	var centre := hud.pause_button().get_global_rect().get_center()
	_touch(centre, true)
	_check(scenario._touch_index == -1 and scenario._selected == -1, "HUD: touch on Pause is not gameplay input")
	_touch(centre, false)
	await _free(scenario)


func _wait_banner(hud: ScenarioHud, text: String) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not (hud.is_banner_visible() and hud.banner_text() == text) and Time.get_ticks_msec() < deadline:
		await process_frame


func _test_turn_banners() -> void:
	var scenario := await _make(5.0, true, 0.0, 30.0, true)
	var hud: ScenarioHud = scenario._hud
	_check(hud.is_banner_visible() and hud.banner_text() == "GAME START", "banner: Game start first (got '%s')" % hud.banner_text())
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_INK, "banner: neutral ink ribbon for Game start")
	await _wait_banner(hud, "Your turn")
	_check(hud.is_banner_visible() and hud.banner_text() == "Your turn", "banner: then blue Your turn")
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_BLUE, "banner: blue ribbon")
	_check(_heard(scenario, &"turn_whoosh"), "banner: soft whoosh")
	_check(not scenario._input_enabled, "banner: input waits for the banner + draw")
	await _wait_input(scenario)
	_check(not hud.is_banner_visible(), "banner: gone when input unlocks")
	await _free(scenario)
	scenario = await _make(5.0, false, 0.0, 30.0, true)
	hud = scenario._hud
	await _wait_banner(hud, "Opponent's turn")
	_check(hud.is_banner_visible() and hud.banner_text() == "Opponent's turn", "banner: red Opponent's turn after Game start")
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_RED, "banner: red ribbon")
	_check(_heard(scenario, &"turn_whoosh"), "banner: whoosh on the opponent's turn too")
	await _free(scenario)


func _test_pause_menu() -> void:
	var scenario := await _make(5.0)
	var pause = scenario._pause # untyped: PauseMenu names autoloads
	_check(not pause.is_open() and not paused, "pause: closed at start")
	var left_before: float = scenario._turn_timer.time_left
	scenario._hud.pause_button().pressed.emit()
	_check(pause.is_open() and paused, "pause: Pause opens the menu and pauses the tree")
	_check(pause.button("Resume").get_global_rect().size.y >= 96.0, "pause: buttons ≥ 96 px")
	await create_timer(0.3, true).timeout
	_check(is_equal_approx(scenario._turn_timer.time_left, left_before), "pause: turn timer stopped (%.2f vs %.2f)" % [scenario._turn_timer.time_left, left_before])
	var board := _board(scenario)
	_tap(_col_pos(scenario, 3))
	_check(_count(board, P) == 0, "pause: no gameplay input while paused")
	pause.button("Options").pressed.emit()
	_check(pause.options().is_open() and not pause.options()._scrim.visible, "pause: Options opens over the pause scrim")
	pause.options()._back.pressed.emit()
	_check(not pause.options().is_open() and pause._menu.visible, "pause: Back returns to the pause menu")
	pause.button("Quit").pressed.emit()
	_check(pause.is_confirming() and pause._confirm.get_child(0).text == "Quit this scenario?", "pause: Quit asks to confirm")
	pause.button("ConfirmCancel").pressed.emit()
	_check(not pause.is_confirming() and pause._menu.visible and paused, "pause: Cancel goes back, still paused")
	pause.button("Resume").pressed.emit()
	_check(not pause.is_open() and not paused, "pause: Resume unpauses")
	await create_timer(0.2).timeout
	_check(scenario._turn_timer.time_left < left_before - 0.1, "pause: timer runs again")
	# The end overlay has no Pause.
	scenario._show_end()
	await process_frame
	_check(not scenario._hud.pause_button().visible, "pause: hidden at the end")
	await _free(scenario)
	_check(not paused, "pause: never left paused")


func _test_speed_settings() -> void:
	var settings := _settings()
	var scenario := await _make(0.0, true, 0.2, 30.0, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var hand := _hand_view(scenario)
	_check(view.animate and view.speed_scale == 1.0, "speed: Normal animates at 1×")
	settings.set_speed(1) # Fast
	_check(view.animate and view.speed_scale == 2.0 and hand.speed_scale == 2.0, "speed: Fast doubles the play animations")
	_check(is_equal_approx(settings.anim_sec(0.6), 0.3), "speed: Fast halves waits")
	settings.set_speed(2) # Skip
	_check(not view.animate and not hand.animate, "speed: Skip turns play animations off")
	_check(settings.anim_sec(0.6) == 0.0, "speed: Skip has no waits")
	# Skip: no red flash, the opponent goes straight after its think delay.
	_play_col(scenario, 3)
	await process_frame
	_check(not scenario._flash.visible, "speed: Skip removes the opponent flash")
	var deadline := Time.get_ticks_msec() + 3000
	while _count(_board(scenario), O) == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(_count(_board(scenario), O) == 1, "speed: Skip opponent still plays")
	_check(view._tokens[Vector2i(3, 0)].position == view.cell_position(3, 0), "speed: Skip lands at once")
	settings.reset()
	_check(view.animate and view.speed_scale == 1.0, "speed: back to Normal applies live")
	await _free(scenario)


## Skip plays only result sounds: the scoring sequence keeps just the sum note.
func _test_skip_scoring_sounds() -> void:
	_settings().set_speed(2)
	var scenario := await _make(5.0)
	var board := _board(scenario)
	for c in 3:
		board.drop(c, P)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	var history: Array[StringName] = scenario._sfx.history
	var ladder := history.filter(func(s: StringName) -> bool: return String(s).begins_with("score_"))
	_check(ladder == [&"score_4"], "skip: scoring plays only the sum note (got %s)" % str(ladder))
	_check(scenario.sum_label != null and scenario.sum_label.text == "4", "skip: sum still shown")
	_settings().reset()
	await _free(scenario)


func _test_screen_shake_option() -> void:
	var scenario := await _make(5.0)
	var view := _view(scenario)
	_settings().set_screen_shake(false)
	_check(not view.shake_enabled, "shake: option reaches the board")
	_fill_column(scenario, 2)
	scenario._reject_placement("Column full")
	_check(view._shake_tween == null or not view._shake_tween.is_valid(), "shake: Off = no board shake")
	scenario._shake_screen()
	_check(scenario._shake_tween == null or not scenario._shake_tween.is_valid(), "shake: Off = no screen shake")
	_check(scenario._toast._label.text == "Column full" and _heard(scenario, &"error"), "shake: Off keeps toast + error sound")
	_settings().set_screen_shake(true)
	scenario._reject_placement("Column full")
	_check(view._shake_tween != null and view._shake_tween.is_valid(), "shake: On shakes again")
	await _free(scenario)
