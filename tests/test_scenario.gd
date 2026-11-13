extends SceneTree
## Headless test for the scenario scene (M3.5 portrait touch, M3.6 2D board):
## column hit areas, press/hold/release with the blue flash, cancel,
## full-column entry error, red opponent flash, turn timer + timeout roll, drop
## and roll animations, end overlay, draw replay, and the portrait layout with
## simulated safe-area insets. Window sizes are physical (project stretch maps
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


func _make(delay: float, player_first := true, flash := 0.0, turn := 30.0, animate := false) -> Control:
	_flow().player_moves_first = player_first
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = animate
	scenario.opponent_delay_sec = delay
	scenario.opponent_flash_sec = flash
	scenario.turn_seconds = turn
	scenario.timeout_reveal_sec = 0.0
	root.add_child(scenario)
	await process_frame
	await process_frame
	return scenario


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
	return scenario.get_node("%HUD").get_global_rect().get_center()


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
	var deadline := Time.get_ticks_msec() + 3000
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
	_check(view._tokens[Vector2i(3, 0)].texture == BoardView2D.TEX_PLAYER, "player Goob is blue")
	_check(view._tokens[Vector2i(3, 0)].position == view.cell_position(3, 0), "player Goob sits in its hole")
	for cell in view._tokens:
		if board.get_owner(cell.x, cell.y) == O:
			_check(view._tokens[cell].texture == BoardView2D.TEX_OPPONENT, "opponent Goob is red")
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
	_check(view._preview.texture == BoardView2D.TEX_PLAYER, "floating Goob is blue")
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
	_check(not scenario._timer_label.visible, "no countdown on the opponent's turn")
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
	var label: Label = scenario._timer_label
	_check(scenario.TURN_SECONDS == 30.0, "slice turn limit is 30 s")
	_check(label.visible and label.text == "30s", "countdown shows 30s (got '%s')" % label.text)
	_check(not scenario._turn_timer.is_stopped(), "timer runs on the player turn")
	_check(scenario.get_node("%TurnLabel").text == "Your turn", "turn label")
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
	_check(scenario._timer_label.text == "0s", "timer reads 0s")
	_check(_count(board, P) == 0, "Goob not dropped yet during the reveal")
	_drag(_col_pos(scenario, 1))
	_touch(_col_pos(scenario, 1), false)
	await create_timer(0.4).timeout
	_check(board.get_owner(4, 0) == P, "then drops in the held column")
	_check(_count(board, P) == 1, "release during the reveal does nothing")
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
	var end_button: Button = scenario.get_node("%EndButton")
	_check(not scenario.get_node("%EndOverlay").visible, "result overlay hidden during play")
	for c in [0, 1, 2]:
		board.drop(c, P)
	for c in [6, 6, 5]:
		board.drop(c, O)
	view.sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "player wins")
	_check(scenario._result_label.text == "You Win!", "announces You Win! (got %s)" % scenario._result_label.text)
	_check(scenario.get_node("%EndOverlay").visible, "result overlay shown")
	_check(end_button.is_visible_in_tree(), "end button visible")
	_check(end_button.text == "Back to title", "end button says Back to title")
	_check(end_button.size.y >= 96.0, "end button ≥ 96 px tall")
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
	var end_button: Button = scenario.get_node("%EndButton")
	_check(scenario._loop.result == TurnLoop.Result.DRAW, "full board is a draw")
	_check(scenario._result_label.text == "Draw", "announces Draw (got %s)" % scenario._result_label.text)
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
	var quit_btn: Button = scenario.get_node("%QuitButton")
	var quit_rect := quit_btn.get_global_rect()
	_check(quit_rect.end.x >= view_size.x - 16.5 and quit_rect.position.y <= top + 10.0, "%s: Quit top right" % tag)
	_check(quit_btn.text == "Quit" and quit_rect.size.y >= 96.0, "%s: Quit button ≥ 96 px" % tag)
	_check(scenario.column_hit_rect(3).size.x >= 85.0, "%s: columns ≥ 85 px" % tag)
	var view := _view(scenario)
	_check(view.pixel_scale == 4, "%s: board at 4× physical (got %d)" % [tag, view.pixel_scale])
	var origin_phys: Vector2 = view._pixel.global_position * 1.5
	_check(origin_phys.is_equal_approx(origin_phys.round()), "%s: board origin on a whole physical pixel (%s)" % [tag, origin_phys])
	_check(view.column_rect(0).position.x >= board.position.x - 0.5 and view.column_rect(6).end.x <= board.end.x + 0.5, "%s: columns inside the board zone" % tag)
	var table: Rect2 = scenario.get_node("%Table").get_global_rect()
	_check(table.position.y > board.get_center().y and table.position.y <= board.end.y + 0.5, "%s: table starts under the board" % tag)
	_check(is_equal_approx(table.end.y, view_size.y), "%s: table runs to the screen bottom" % tag)
	SafeArea.simulate_insets = false
	await _free(scenario)


# --- M4: decks and hands --------------------------------------------------------

func _hand_view(scenario: Control) -> HandView:
	return scenario.get_node("%PlayerHand")


func _test_hand_at_start() -> void:
	var scenario := await _make(0.0)
	var hand := _hand_view(scenario)
	_check(scenario._loop.player_deck.hand.size() == 4, "start: player holds 3 + turn draw")
	_check(hand.count() == 4, "start: fan shows 4 (got %d)" % hand.count())
	_check(scenario._input_enabled, "start: input on after the draw reveal")
	await _free(scenario)
	scenario = await _make(0.0, false)
	_check(_hand_view(scenario).count() == 4, "opp first: fan shows 4 after its opener")
	_check(scenario._loop.opponent_deck.hand.size() == 3, "opp first: opponent played 1 of 4")
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
	_check(hand.count() == 3, "played Goob left the fan")
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
	_check(not hand.is_dragging() and hand.count() == 4, "Goob flies back to the hand")
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
	_check(hand.count() == 3, "fan closes up")
	await _free(scenario)


func _test_small_move_is_tap() -> void:
	var scenario := await _make(5.0)
	var hand := _hand_view(scenario)
	scenario._last_tap_key = ""
	var start := hand.slot_center(3)
	_touch(start, true)
	_drag(start + Vector2(5, -5))
	_check(not hand.is_dragging(), "a 7 px move is not a drag")
	_touch(start + Vector2(5, -5), false)
	_check(scenario._selected == 3, "small move + release selects")
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
	var chosen: GoobDefinition = scenario._loop.player_deck.hand[3]
	_select_hand(scenario, 3)
	await create_timer(0.35).timeout
	var played: GoobDefinition = null
	for column in BoardState.COLUMNS:
		if scenario._loop.goob_at(column, 0) != null:
			played = scenario._loop.goob_at(column, 0)
	_check(played == chosen, "timeout plays the selected Goob")
	_check(_hand_view(scenario).count() == 3, "timeout Goob left the fan")
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
	_check(scenario._result_label.text == "Draw", "stalemate: announces Draw")
	_check(scenario.get_node("%EndButton").text == "Replay", "stalemate: Replay")
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
	_check(_heard(scenario, &"column"), "sound: column flash blip")
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
