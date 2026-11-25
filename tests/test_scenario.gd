extends SceneTree
## Headless test for the scenario scene (M3.5 portrait touch, M3.6 2D board):
## column hit areas, press/hold/release with the blue flash, cancel,
## full-column entry error, turn timer + timeout roll, drop
## and roll animations, end overlay, draw replay, and the portrait layout with
## simulated safe-area insets; M6b pixel HUD, turn banners, pause menu,
## Normal / Fast, haptics + screen shake options. Window sizes are physical (project stretch maps
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
	await _test_move_animations()
	await _test_destroy_animations()
	await _test_discard_animations()
	await _test_draw_animations()
	await _test_tech_animations()
	await _test_unique_animations()
	await _test_scoring_sequence()
	await _test_scoring_animated()
	await _test_hud()
	await _test_turn_banners()
	await _test_pause_menu()
	await _test_speed_settings()
	_test_skip_removed()
	await _test_screen_shake_option()
	await _test_m6c_reactions()
	await _test_m6c_fuse()
	await _test_m6c_playtest()
	await _test_m6c_waiting()
	await _test_convincing_flip_colour()
	await _test_chain_loss_angry()
	await _test_status_pill_shows_and_toasts()
	await _test_discard_reveal_not_faster_on_fast()
	await _test_discard_keeps_fan_in_order()
	await _test_pills_clear_of_columns(PHONE)
	await _test_pills_clear_of_columns(Vector2i(1080, 2340))
	await _test_debug_give_full_hand_replaces_oldest()
	await _test_debug_give_opponent()
	await _test_debug_status()
	await _test_debug_discard_opponent()
	await _test_debug_no_stale_opponent_plan()
	await _test_debug_panel_f4()
	await _test_escape_closes_menus()
	await _test_autoplay_plays_for_player()
	await _test_autoplay_off_during_think()
	await _test_autoplay_cancels_drag()
	await _test_autoplay_draw_replay_keeps_decks()
	await _test_autoplay_off_at_win()
	await _test_autoplay_button_hidden_by_setting()
	await _test_autoplay_off_on_return_to_title()
	await _test_autoplay_replay_after_view_board()
	await _test_autoplay_move_needs_flag()
	await _test_debug_give_refused_in_timeout_reveal()
	await _test_debug_give_refused_in_draw_reveal()
	await _test_debug_discard_player_guards()
	await _test_pills_refresh_on_autoplay_turn_start()
	await _test_autoplay_no_move_turns_off()
	await _test_autoplay_flips_up_from_behind()
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


func _make(delay: float, player_first := true, turn := 30.0, animate := false) -> Control:
	_flow().player_moves_first = player_first
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = animate
	scenario.deck = _vanilla_deck()
	scenario.opponent_delay_sec = delay
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
	var toast_mid: Vector2 = scenario._toast.get_global_rect().get_center()
	_check(absf(toast_mid.y - scenario.gap_center().y) < 2.0 and toast_mid.y < view.get_global_rect().position.y, "toast sits in the gap between the HUD and the board (M6c playtest)")
	_check(not _heard(scenario, &"error"), "m6d: no error sound on entry (only on release)")
	_check(scenario._flash.visible and scenario._flash.color == scenario.COLOR_FLASH_FULL, "m6d: dark highlight on a full column")
	_check(scenario._flash.get_global_rect().is_equal_approx(scenario.column_hit_rect(3)), "m6d: highlight covers the full column")
	_check(not view.is_preview_visible(), "no floating Goob over a full column")
	await process_frame
	await process_frame
	_check(view._shake_px == 0, "m6d: no shake on entry")
	# Staying on the column does not repeat the error.
	scenario._toast.modulate.a = 0.0
	_drag(_col_pos(scenario, 3) + Vector2(0, -40))
	_check(scenario._toast.modulate.a < 0.1, "no repeat while staying on the full column")
	# Leaving and coming back does.
	_drag(_col_pos(scenario, 2))
	_check(scenario._flash.visible and scenario._flash.color == scenario.COLOR_FLASH_PLAYER, "legal column flashes blue again")
	_drag(_col_pos(scenario, 3))
	_check(scenario._toast.modulate.a > 0.9, "re-entry shows Column full again")
	_check(not _heard(scenario, &"error"), "m6d: still no error sound while hovering")
	_touch(_col_pos(scenario, 3), false)
	await process_frame
	await process_frame
	_check(_heard(scenario, &"error"), "m6d: release on a full column plays the error sound")
	_check(view._shake_px != 0, "m6d: release on a full column shakes")
	_check(not scenario._flash.visible, "m6d: highlight gone after release")
	_check(board.to_debug_string() == before, "release on a full column: no drop")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "still player turn")
	_check(scenario._touch_column == -1, "release on full clears the timeout column")
	_check(scenario.try_drop(3) == -1, "try_drop on full column returns -1")
	# Drag style: hovering is quiet, letting go errors and the Goob flies back.
	scenario._sfx.history.clear()
	await process_frame # the try_drop error played this frame (once per frame)
	var hand := _hand_view(scenario)
	scenario._last_tap_key = ""
	var start := hand.slot_center(0)
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_drag(_col_pos(scenario, 3))
	_check(not _heard(scenario, &"error") and scenario._flash.color == scenario.COLOR_FLASH_FULL, "m6d drag: dark highlight, no error while hovering")
	_touch(_col_pos(scenario, 3), false)
	_check(_heard(scenario, &"error"), "m6d drag: release on a full column errors")
	_check(board.to_debug_string() == before and not hand.is_dragging(), "m6d drag: no drop, Goob flies back")
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


func _test_turn_timer_hud() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	_check(scenario.TURN_SECONDS == 30.0, "slice turn limit is 30 s")
	_check(hud.timer_text() == "30" and not hud.is_timer_red(), "countdown shows 30 (got '%s')" % hud.timer_text())
	_check(not scenario._turn_timer.is_stopped(), "timer runs on the player turn")
	await _free(scenario)


func _test_timeout_random() -> void:
	var scenario := await _make(5.0, true, 0.2)
	var board := _board(scenario)
	await create_timer(0.35).timeout
	_check(_count(board, P) == 1, "timeout with no touch plays a Goob")
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "turn passes after timeout")
	# Sean's bug (M6c playtest): after a timeout the fan must still match the
	# hand, or tapping one Goob plays another.
	_check(scenario._hand.count() == scenario._loop.player_deck.hand.size(), "timeout keeps the fan in step with the hand (fan %d, hand %d)" % [scenario._hand.count(), scenario._loop.player_deck.hand.size()])
	await _free(scenario)


## Timeout auto-play is announced before the Goob drops (Sean, 2026-11-11).
func _test_timeout_is_obvious() -> void:
	_flow().player_moves_first = true
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = false
	scenario.deck = _vanilla_deck() # a timed-out Popular would add a second Goob (was flaky)
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
	var scenario := await _make(5.0, true, 0.2)
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
	var scenario := await _make(5.0, true, 0.2)
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
	var scenario := await _make(5.0, true, 30.0, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var board := _board(scenario)
	_play_col(scenario, 2)
	_check(board.get_owner(2, 0) == P, "grid updates at once")
	_check(not scenario._input_enabled, "input locked while the Goob falls")
	var token: Sprite2D = view._tokens[Vector2i(2, 0)]
	_check(token.position == Vector2(view.cell_position(2, 0).x, BoardView2D.TOP_Y), "Goob appears on top of the board over its column")
	_check(scenario._opponent_timer.is_stopped(), "opponent waits for the landing")
	_check(not view.is_preview_visible(), "the faint aim ghost is gone once the drop commits")
	_check(is_equal_approx(view._preview.modulate.a, BoardView2D.GHOST_ALPHA), "the aim float is a faint ghost")
	# It drops from the ghost's spot after the usual rest, no flip (M6c playtest).
	_check(view.shows_goob(Vector2i(2, 0), TurnLoop.VANILLA, P), "your Goob replaces the ghost face up (no flip)")
	await create_timer(BoardView2D.TOP_PAUSE_SEC * 0.5).timeout
	_check(token.position.y == BoardView2D.TOP_Y, "Goob rests on top of the board")
	await create_timer(BoardView2D.TOP_PAUSE_SEC * 0.5 + 0.1).timeout
	_check(token.position.y > BoardView2D.TOP_Y, "then falls")
	_check(token.position == token.position.round(), "Goob moves on whole game pixels")
	await create_timer(0.6).timeout
	_check(token.position == view.cell_position(2, 0), "Goob landed in its hole")
	_check(scenario._hud.is_banner_visible() or not scenario._opponent_timer.is_stopped(), "opponent turn started after the landing (red banner, then his think delay)")
	await _free(scenario)


## Timeout into a full column: the Goob rolls on top of the board, bouncing
## off the edge, then falls into the first open column.
func _test_roll_animation() -> void:
	var scenario := await _make(5.0, true, 0.2, true)
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
	_check(token.position.x == view.cell_position(6, 0).x and token.position.y <= BoardView2D.TOP_Y, "Goob appears on top of the full column first (%s)" % token.position)
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
const GREEDY := preload("res://resources/goobs/greedy_goob.tres")


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
	# Greedy: two more Goobs in the fan.
	scenario = await _make(5.0)
	var hand: HandView = scenario.get_node("%PlayerHand")
	_give(scenario, GREEDY)
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.player_deck.hand.size() == 4, "greedy (scenario): 3 - 1 + 2 in hand")
	_check(hand.count() == 4, "greedy: fan shows 4 (got %d)" % hand.count())
	await _free(scenario)


## With animation on, each effect plays its impact (sound) and the view ends
## matching the board before the opponent's turn starts.
func _test_effect_animations() -> void:
	for setup in [[CONVINCING, &"flip"], [FAT, &"crunch"], [POPULAR, &"popular"], [GREEDY, &"draw_pop"]]:
		var goob: GoobDefinition = setup[0]
		var sound: StringName = setup[1]
		var scenario := await _make(5.0, true, 30.0, true)
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
	var scenario := await _make(5.0, true, 30.0, true)
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
	_give(scenario, GREEDY) # ×2, no board change
	_play_col(scenario, 3)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "scoring: player wins")
	_check(scenario.sum_label != null and scenario.sum_label.text == "5", "scoring: sum 1+1+1+2 = 5 (got %s)" % (scenario.sum_label.text if scenario.sum_label else "none"))
	_check(scenario.score_labels.is_empty(), "scoring: multipliers collapsed into the sum")
	_check(absf(scenario.sum_label.get_global_rect().get_center().y - scenario.gap_center().y) < 2.0, "scoring: the total shows in the gap above the board (M6c playtest)")
	var face_up := true
	for c in 4:
		face_up = face_up and not _view(scenario).shows_back(Vector2i(c, 0))
	_check(face_up, "scoring: every Goob flipped back to its face")
	_check(TurnLoop.VANILLA.flip_frames(P)[4].resource_path.contains("blue_pitch"), "Vanilla flips vertically (pitch frames)")
	_check(PLENTIFUL.flip_frames(O)[4].resource_path.contains("red_yaw"), "other types keep the sideways spin")
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
	# Blocking his open three makes him sad (M6c playtest; was angry).
	scenario = await _make(5.0)
	hud = scenario._hud
	var board := _board(scenario)
	for c in 3:
		board.drop(c, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 3)
	await process_frame
	_check(hud.portrait_face() == &"sad", "m6c: blocking his three makes him sad (got %s)" % hud.portrait_face())
	await _free(scenario)
	# Blocking his two before it becomes a three: "well played" (M6c playtest).
	scenario = await _make(5.0)
	hud = scenario._hud
	board = _board(scenario)
	board.drop(0, O)
	board.drop(1, O)
	_view(scenario).sync_from_board(board)
	_play_col(scenario, 2)
	await process_frame
	_check(hud.portrait_face() == &"well_played", "m6c: blocking his two gets a well played (got %s)" % hud.portrait_face())
	# His own block of your two: he giggles.
	var before := BoardState.new()
	before.drop(4, P)
	before.drop(5, P)
	scenario._board_before = before
	scenario._loop.board = before.copy()
	scenario._loop.board.drop(6, O)
	_check(scenario._reaction_for(6, O, [] as Array[int], {}) == &"giggle", "m6c: he giggles when he blocks your two")
	scenario._board_before = BoardState.new()
	scenario._loop.board = BoardState.new()
	scenario._loop.board.drop(3, O)
	_check(scenario._reaction_for(3, O, [] as Array[int], {}) == &"", "m6c: a quiet move gets no reaction")
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
	_check(hud.caption_text() == "Goob", "playtest: drawn Goob's name shows above the board (got '%s')" % hud.caption_text())
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


## M6c playtest: he waits on you after WAITING_AFTER_SEC without a touch and
## during the fuse; a touch brings him back. His reactions start with the effect.
## Convincing's target keeps its old colour through the wind-up and only
## turns as it spins (Sean, M6c playtest: it showed the new colour first).
## A chain that hands you the win makes him angry, not "well played"
## (Sean, M6c playtest 2026-11-23).
func _test_chain_loss_angry() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	loop.board.drop(1, P) # a Goob fell into the destroyed cell: a chain
	loop.last_effect = {"kind": GoobDefinition.EffectType.DESTROY_ADJACENT, "target": Vector2i(1, 0), "cell": Vector2i(0, 0), "side": P, "fizzled": false, "fell": 1}
	_check(scenario._defeat_face() == &"angry", "chain loss: angry")
	loop.last_effect = {"kind": GoobDefinition.EffectType.DESTROY_ADJACENT, "target": Vector2i(1, 1), "cell": Vector2i(0, 0), "side": P, "fizzled": false, "fell": 0}
	_check(scenario._defeat_face() == &"well_played", "no chain (nothing fell): well played")
	loop.last_effect = {}
	_check(scenario._defeat_face() == &"well_played", "plain win: well played")
	var hud: ScenarioHud = scenario._hud
	hud.play_defeat(1.0, &"angry")
	_check(hud.portrait_face() == &"angry", "chain loss: the defeat starts angry, then cracks")
	await _free(scenario)


func _test_convincing_flip_colour() -> void:
	var scenario := await _make(5.0, true, 30.0, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var board := _board(scenario)
	board.drop(0, P)
	board.drop(1, O)
	view.sync_from_board(board)
	await process_frame
	var target := Vector2i(1, 0)
	var token: Sprite2D = view._tokens[target]
	view.play_flip(Vector2i(0, 0), target, P)
	var blue: Array[Texture2D] = TurnLoop.VANILLA.flip_frames(P)
	blue.append(TurnLoop.VANILLA.still(P))
	var frames: SpriteFrames = TurnLoop.VANILLA.sprite_frames(P)
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			blue.append(frames.get_frame_texture(anim, i))
	var early_blue := false
	for i in 10: # the wind-up and target blink come before the spin
		await process_frame
		early_blue = early_blue or blue.has(token.texture)
	_check(not early_blue, "convincing: the target keeps its colour until it flips")
	await create_timer(1.5).timeout
	_check(view.shows_goob(target, TurnLoop.VANILLA, P), "convincing: it ends in your colour")
	await _free(scenario)


func _test_m6c_waiting() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	await process_frame
	_check(hud.base_face() == &"idle", "waiting: idle at the start of your turn")
	scenario._idle_since_msec -= int(scenario.WAITING_AFTER_SEC * 1000.0) + 50
	await process_frame
	await process_frame
	_check(hud.portrait_face() == &"waiting", "waiting: waits after 8 s without a touch (got %s)" % hud.portrait_face())
	_touch(_col_pos(scenario, 3), true)
	_touch(_col_pos(scenario, 3), false)
	await process_frame
	await process_frame
	_check(hud.portrait_face() == &"idle", "waiting: a touch brings him back (got %s)" % hud.portrait_face())
	await _free(scenario)
	scenario = await _make(5.0, true, 10.3)
	hud = scenario._hud
	await create_timer(0.5).timeout
	_check(hud.portrait_face() == &"waiting", "waiting: waits while the fuse burns (got %s)" % hud.portrait_face())
	await _free(scenario)
	# Reaction during the effect: animated Convincing flip of his Goob → angry
	# before the effect has finished.
	scenario = await _make(5.0, true, 30.0, true)
	await _wait_input(scenario)
	hud = scenario._hud
	var board := _board(scenario)
	board.drop(2, O)
	_view(scenario).sync_from_board(board)
	_give(scenario, CONVINCING)
	_play_col(scenario, 3)
	var deadline := Time.get_ticks_msec() + 4000
	while hud.portrait_face() != &"angry" and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(hud.portrait_face() == &"angry", "reaction: angry when your effect hits him")
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN and scenario._opponent_timer.is_stopped(), "reaction: shown while the effect is still playing")
	await _free(scenario)


## M6c: the fuse burns only for the last 10 s, with worried hand Goobs.
func _test_m6c_fuse() -> void:
	var scenario := await _make(5.0, true, 10.4)
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
	var scenario := await _make(5.0, true, 30.0, true)
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
	var scenario := await _make(0.0, true, 30.0)
	var loop: TurnLoop = scenario._loop
	# As after Greedy: the player's hand is full when their next turn starts.
	while loop.player_deck.hand.size() < Deck.HAND_MAX + 1:
		loop.player_deck.hand.append(loop.player_deck.hand[0])
	_hand_view(scenario).rebuild(loop.player_deck.hand)
	scenario.try_drop(0, 0)
	await process_frame
	_check(loop.phase == TurnLoop.Phase.PLAYER_TURN, "hand full: player's turn again")
	_check(loop.last_draw_hand_full, "hand full: draw skipped")
	_check(scenario._toast._label.text == "Hand full", "hand full: toast")
	_check(_heard(scenario, &"hand_full"), "hand full: sound")
	_check(_hand_view(scenario).count() == Deck.HAND_MAX, "hand full: fan holds a full hand")
	# M6f: past 5 the hand Goobs drop one pixel step and stay tappable.
	var hand := _hand_view(scenario)
	var board_view: BoardView2D = scenario.get_node("%BoardView")
	_check(is_equal_approx(hand.goob_px(), board_view.board_px()) and hand.goob_px() < board_view.hand_px(), "hand full: 7 Goobs at board size (%.2f)" % hand.goob_px())
	var ui := scenario.get_viewport_rect().size.x / 720.0
	var gaps_ok := true
	for i in hand.count() - 1:
		var step := (hand.slot_center(i + 1).x - hand.slot_center(i).x) / ui
		gaps_ok = gaps_ok and step >= HandView.TOUCH_MIN - 0.5 and step >= HandView.GOOB_PX * hand.goob_px() / ui - 0.5
	_check(gaps_ok, "hand full: 7 Goobs, no overlap, each >= 96 px to tap")
	var five: Array[GoobDefinition] = []
	five.assign(loop.player_deck.hand.slice(0, 5))
	hand.rebuild(five)
	_check(is_equal_approx(hand.goob_px(), board_view.hand_px()), "hand: 5 Goobs at full hand size")
	hand.rebuild(loop.player_deck.hand)
	await process_frame
	_check(scenario.position.x != 0.0, "hand full: screen shakes")
	await create_timer(0.4).timeout
	_check(scenario.position.x == 0.0, "hand full: shake settles")
	await _free(scenario)


func _test_timeout_plays_selected() -> void:
	var scenario := await _make(5.0, true, 0.2)
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
	# Same with the first Goob selected: only that card leaves the fan and the
	# rest stay in step with the hand (Sean's bug, M6c playtest: tapping one
	# Goob played another after a timeout).
	scenario = await _make(5.0, true, 0.2)
	_select_hand(scenario, 0)
	await create_timer(0.35).timeout
	var fan := _hand_view(scenario)
	var hand: Array[GoobDefinition] = scenario._loop.player_deck.hand
	var in_step := fan.count() == hand.size()
	for i in mini(fan.count(), hand.size()):
		in_step = in_step and fan._cards[i].get_meta(&"goob", null) == hand[i]
	_check(in_step, "timeout on the first Goob keeps the fan in step (fan %d, hand %d)" % [fan.count(), hand.size()])
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
	var scenario := await _make(5.0, true, 30.0, true)
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
	await create_timer(0.05).timeout
	_check(_heard(scenario, &"rest"), "sound: rest on top")
	await create_timer(0.6).timeout
	_check(_heard(scenario, &"fall") and _heard(scenario, &"land"), "sound: fall + land")
	await _free(scenario)
	scenario = await _make(5.0, true, 0.2)
	_fill_column(scenario, 6)
	_fill_column(scenario, 5)
	_select_hand(scenario)
	_touch(_col_pos(scenario, 6), true)
	await create_timer(0.3).timeout
	_check(_heard(scenario, &"times_up"), "sound: Time's up!")
	_touch(_col_pos(scenario, 6), false)
	await _free(scenario)
	scenario = await _make(5.0, true, 0.2, true)
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
	var scenario := await _make(5.0, true, 30.0, true)
	var hud: ScenarioHud = scenario._hud
	_check(hud.is_banner_visible() and hud.banner_text() == "GAME START", "banner: Game start first (got '%s')" % hud.banner_text())
	_check(hud.portrait_face() == &"greeting", "banner: he waves hello during Game start (got %s)" % hud.portrait_face())
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_INK, "banner: neutral ink ribbon for Game start")
	await _wait_banner(hud, "Your turn")
	_check(hud.is_banner_visible() and hud.banner_text() == "Your turn", "banner: then blue Your turn")
	_check(hud.portrait_face() != &"greeting", "banner: the wave ends after Game start (got %s)" % hud.portrait_face())
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_BLUE, "banner: blue ribbon")
	_check(_heard(scenario, &"turn_whoosh"), "banner: soft whoosh")
	_check(not scenario._input_enabled, "banner: input waits for the banner + draw")
	await _wait_input(scenario)
	_check(not hud.is_banner_visible(), "banner: gone when input unlocks")
	await _free(scenario)
	scenario = await _make(5.0, false, 30.0, true)
	hud = scenario._hud
	await _wait_banner(hud, "Opponent's turn")
	_check(hud.is_banner_visible() and hud.banner_text() == "Opponent's turn", "banner: red Opponent's turn after Game start")
	_check(hud._ribbon.texture == ScenarioHud.RIBBON_RED, "banner: red ribbon")
	_check(_heard(scenario, &"turn_whoosh"), "banner: whoosh on the opponent's turn too")
	_check(hud.portrait_face() != &"thinking" and scenario._opponent_timer.is_stopped(), "think delay waits for the red banner (M6c playtest)")
	var deadline := Time.get_ticks_msec() + 3000
	while hud.is_banner_visible() and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	_check(hud.portrait_face() == &"thinking" and not scenario._opponent_timer.is_stopped(), "then he thinks (got %s)" % hud.portrait_face())
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
	var scenario := await _make(0.0, true, 30.0, true)
	await _wait_input(scenario)
	var view := _view(scenario)
	var hand := _hand_view(scenario)
	_check(view.animate and view.speed_scale == 1.0, "speed: Normal animates at 1×")
	settings.set_speed(1) # Fast
	_check(view.animate and view.speed_scale == 2.0 and hand.speed_scale == 2.0, "speed: Fast doubles the play animations")
	_check(is_equal_approx(settings.anim_sec(0.6), 0.3), "speed: Fast halves waits")
	settings.reset()
	_check(view.animate and view.speed_scale == 1.0, "speed: back to Normal applies live")
	await _free(scenario)


## Skip was removed (Sean, M6c playtest): a saved Skip loads as Normal, and
## Options offers Normal / Fast only.
func _test_skip_removed() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("play", "speed", 2)
	cfg.save(_settings().path)
	_settings().load_file()
	_check(_settings().speed == 0, "skip removed: a saved Skip loads as Normal")
	var panel_script: GDScript = load("res://scripts/ui/options_panel.gd")
	_check(panel_script.get_script_constant_map()["SPEEDS"].size() == 2, "skip removed: Options shows Normal / Fast")
	_settings().reset()


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


## M6e: a status shows as a pill in the gap (yours on the left); pressing it
## toasts its explanation.
func _test_status_pill_shows_and_toasts() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	loop.add_status(&"t", P, "Test", "Explain", -1)
	scenario._refresh_hud()
	await process_frame
	var pills: StatusPills = scenario._pills
	var buttons := pills.buttons()
	_check(buttons.size() == 1, "pills: one pill (got %d)" % buttons.size())
	if buttons.size() == 1:
		var pill := buttons[0]
		_check(pill.is_visible_in_tree() and StatusPills.label_of(pill) == "Test", "pills: shows its label")
		var rect := pill.get_global_rect()
		_check(rect.get_center().x < scenario.size.x * 0.5, "pills: yours on the left half")
		_check(rect.size.x >= 96.0, "pills: at least 96 px wide (got %.0f)" % rect.size.x)
		_check(rect.position.y >= scenario._hud.bottom() - 0.5 and rect.end.y <= scenario.get_node("%AimLane").get_global_rect().position.y + 0.5, "pills: in the gap above the aim lane (%s)" % rect)
		pill.pressed.emit()
		_check(scenario._toast._label.text == "Explain", "pills: press toasts the text")
	loop.remove_status(&"t", P)
	scenario._refresh_hud()
	await process_frame
	_check(pills.buttons().is_empty(), "pills: removed status clears its pill")
	await _free(scenario)


## M6e: the discard reveal is never sped up by Fast, and only discard_from
## takes the Goob out of the hand (the fan follows it).
func _test_discard_reveal_not_faster_on_fast() -> void:
	var scenario := await _make(5.0, true, 30.0, true)
	await _wait_input(scenario)
	_settings().set_speed(1) # Fast
	var loop: TurnLoop = scenario._loop
	var before := loop.player_deck.hand.size()
	var goob := loop.discard_from(P, 0)
	_check(goob != null and loop.player_deck.hand.size() == before - 1, "discard: discard_from takes it from the hand")
	var t0 := Time.get_ticks_msec()
	await scenario._show_discard(goob, P, 0)
	var took := Time.get_ticks_msec() - t0
	_check(took >= 1200, "discard: reveal not faster on Fast (%d ms)" % took)
	_check(loop.player_deck.hand.size() == before - 1, "discard: the reveal itself takes nothing more")
	_check(_hand_view(scenario).count() == loop.player_deck.hand.size(), "discard: the fan matches the hand")
	_settings().reset()
	await _free(scenario)


## M6e fix: a discard from the middle of a mixed hand takes that very card out
## of the fan, so the fan stays in hand order (taps play the right Goob).
func _test_discard_keeps_fan_in_order() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	var v: GoobDefinition = TurnLoop.VANILLA
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	var popular: GoobDefinition = load("res://resources/goobs/popular_goob.tres")
	var mixed: Array[GoobDefinition] = [v, fat, v, fat, popular]
	loop.player_deck.hand.assign(mixed)
	var hand := _hand_view(scenario)
	hand.rebuild(loop.player_deck.hand)
	loop.discard_from(P, 1)
	await scenario._play_effect(loop.effect_steps[-1])
	var fan := hand.goobs()
	var same := fan.size() == loop.player_deck.hand.size()
	for i in mini(fan.size(), loop.player_deck.hand.size()):
		same = same and fan[i] == loop.player_deck.hand[i]
	_check(same, "discard fan: fan matches the hand element by element")
	await _free(scenario)


## M6e fix: column input always wins, so no pill covers a column's hit area
## (column + aim lane), with simulated insets. Pills sit on the aim lane's
## top, at least 10 game px tall (over the HUD block's edge when the strip
## above the lane is shorter), always visible, clear of the Pause button.
func _test_pills_clear_of_columns(window: Vector2i) -> void:
	root.size = window
	SafeArea.simulate_insets = true
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	loop.add_status(&"a", P, "Mine", "x", -1)
	loop.add_status(&"b", P, "Also mine", "x", -1)
	loop.add_status(&"c", O, "His", "y", -1)
	scenario._refresh_hud()
	await process_frame
	await process_frame
	var tag := str(window)
	var buttons: Array[Button] = scenario._pills.buttons()
	var pause_rect: Rect2 = scenario._hud.pause_button().get_global_rect()
	var lane_top: float = scenario.get_node("%AimLane").get_global_rect().position.y
	_check(buttons.size() == 3, "%s: three pills" % tag)
	for pill in buttons:
		var rect := pill.get_global_rect()
		_check(pill.is_visible_in_tree(), "%s: pill visible" % tag)
		_check(rect.size.x >= 96.0, "%s: pill ≥ 96 px wide" % tag)
		_check(rect.size.y >= 10.0 * scenario._pills.stage.k - 0.5, "%s: pill ≥ 10 game px tall (%s)" % [tag, rect])
		_check(rect.end.y <= lane_top + 0.5, "%s: pill bottom on the aim lane's top (%s)" % [tag, rect])
		var clear := not rect.intersects(pause_rect)
		for column in BoardState.COLUMNS:
			if rect.intersects(scenario.column_hit_rect(column)):
				clear = false
		_check(clear, "%s: pill clear of column hit rects and Pause (%s)" % [tag, rect])
	if buttons.size() == 3:
		_check(buttons[0].get_global_rect().get_center().x < scenario.size.x * 0.5 and buttons[2].get_global_rect().get_center().x > scenario.size.x * 0.5, "%s: yours left, his right" % tag)
	SafeArea.simulate_insets = false
	await _free(scenario)
	root.size = PHONE


## M6e debug picker: a full hand drops its oldest Goob for the given one; the
## fan shows the new hand.
func _test_debug_give_full_hand_replaces_oldest() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	var v: GoobDefinition = TurnLoop.VANILLA
	var convincing: GoobDefinition = load("res://resources/goobs/convincing_goob.tres")
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	var full: Array[GoobDefinition] = [convincing]
	while full.size() < Deck.HAND_MAX:
		full.append(v)
	loop.player_deck.hand.assign(full)
	_hand_view(scenario).rebuild(loop.player_deck.hand)
	scenario.debug_give(fat, P)
	var hand := loop.player_deck.hand
	_check(hand.size() == Deck.HAND_MAX, "debug give: hand stays full (got %d)" % hand.size())
	_check(hand.size() > 0 and hand[-1] == fat, "debug give: the given Goob is last")
	_check(not hand.has(convincing), "debug give: the oldest Goob is gone")
	_check(_hand_view(scenario).count() == Deck.HAND_MAX, "debug give: the fan shows a full hand (got %d)" % _hand_view(scenario).count())
	await _free(scenario)


func _test_debug_give_opponent() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	var before := loop.opponent_deck.hand.size()
	var fan_before := _hand_view(scenario).count()
	scenario.debug_give(fat, O)
	_check(loop.opponent_deck.hand.size() == before + 1 and loop.opponent_deck.hand[-1] == fat, "debug give: the opponent's hand gains it")
	_check(_hand_view(scenario).count() == fan_before, "debug give: the player fan is untouched")
	await _free(scenario)


func _test_debug_status() -> void:
	var scenario := await _make(5.0)
	scenario.debug_add_status(P)
	await process_frame
	var buttons: Array[Button] = scenario._pills.buttons()
	_check(buttons.size() == 1 and StatusPills.label_of(buttons[0]) == "Test", "debug status: the Test pill appears")
	_check(scenario._loop.has_status(&"debug", P), "debug status: on the player's side")
	await _free(scenario)


## Discard random on the opponent's hand works at any time; on yours only while
## your input is on.
func _test_debug_discard_opponent() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	var before := loop.opponent_deck.hand.size()
	await scenario.debug_discard_random(O)
	_check(loop.opponent_deck.hand.size() == before - 1 and loop.opponent_deck.discard_pile.size() == 1, "debug discard: one opponent Goob discarded")
	var mine := loop.player_deck.hand.size()
	scenario._set_input_enabled(false)
	await scenario.debug_discard_random(P)
	_check(loop.player_deck.hand.size() == mine, "debug discard: yours ignored while input is locked")
	scenario._set_input_enabled(true)
	await scenario.debug_discard_random(P)
	_check(loop.player_deck.hand.size() == mine - 1 and _hand_view(scenario).count() == mine - 1, "debug discard: yours discarded while input is on (fan follows)")
	await _free(scenario)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)


## F4 opens the panel (tree paused) and closes it; its buttons are ≥ 96 px and
## act on the chosen side; "New game with these" forces the categories.
## M6f (Sean, 2026-11-24): desktop Esc closes the topmost menu; with nothing
## open it toggles pause.
func _test_escape_closes_menus() -> void:
	var scenario := await _make(5.0)
	var pause = scenario._pause # untyped: PauseMenu needs the autoloads
	_key(KEY_ESCAPE)
	await process_frame
	_check(pause.is_open() and paused, "esc: nothing open = pause")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not pause.is_open() and not paused, "esc: again = resume")
	pause.open()
	pause.button("Options").pressed.emit()
	_check(pause.options().is_open(), "esc: options open")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not pause.options().is_open() and pause.is_open(), "esc: options -> back to the pause menu")
	pause.button("Quit").pressed.emit()
	_check(pause.is_confirming(), "esc: quit confirm shown")
	_key(KEY_ESCAPE)
	await process_frame
	_check(pause.is_open() and not pause.is_confirming(), "esc: quit confirm -> cancel")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not pause.is_open() and not paused, "esc: pause menu -> resume")
	scenario._inspect.open(TurnLoop.VANILLA, P, 200.0)
	_key(KEY_ESCAPE)
	await process_frame
	_check(not scenario._inspect.is_open() and not pause.is_open(), "esc: closes inspect (and doesn't pause)")
	_key(KEY_F4)
	await process_frame
	_key(KEY_ESCAPE)
	await process_frame
	_check(not scenario._debug.is_open() and not paused and not pause.is_open(), "esc: closes the debug panel")
	await _free(scenario)
	_check(not paused, "esc: never left paused")


func _test_debug_panel_f4() -> void:
	var scenario := await _make(5.0)
	var panel: DebugPanel = scenario._debug
	_check(panel != null and not panel.is_open(), "debug panel: built (debug build), closed at start")
	_key(KEY_F4)
	await process_frame
	_check(panel.is_open() and paused, "debug panel: F4 opens it and pauses the tree")
	_check(panel.button("Close").get_global_rect().size.y >= 96.0, "debug panel: buttons ≥ 96 px")
	var loop: TurnLoop = scenario._loop
	var before := loop.opponent_deck.hand.size()
	panel.button("Opponent").pressed.emit()
	panel.button("Fat Goob").pressed.emit()
	_check(loop.opponent_deck.hand.size() == before + 1, "debug panel: a Goob button gives to the chosen side")
	panel.button("Add test status").pressed.emit()
	_check(loop.has_status(&"debug", O), "debug panel: test status on the chosen side")
	_key(KEY_F4)
	await process_frame
	_check(not panel.is_open() and not paused, "debug panel: F4 again closes it and unpauses")
	panel.open()
	panel.button("14 + 7").pressed.emit()
	panel.button("Move + Discard").pressed.emit()
	var forced := panel.forced()
	_check(forced.get("type", -1) == DeckBuilder.DeckType.LOADED, "debug panel: deck type forced")
	var main: Array = forced.get("main", [])
	_check(main.size() == 2 and main.has(GoobDefinition.Category.MOVE) and main.has(GoobDefinition.Category.DISCARD), "debug panel: main pair forced")
	panel.button("Auto deck").pressed.emit()
	panel.button("Auto main").pressed.emit()
	_check(panel.forced().is_empty(), "debug panel: Auto clears the forcing")
	panel.button("Close").pressed.emit()
	_check(not panel.is_open() and not paused, "debug panel: Close unpauses")
	await _free(scenario)
	_check(not paused, "debug panel: never left paused")


## Fix: after his play the chosen hand index is cleared, so in the window
## before his next move is chosen a debug discard isn't blocked by a stale one.
func _test_debug_no_stale_opponent_plan() -> void:
	var scenario := await _make(0.0)
	var loop: TurnLoop = scenario._loop
	_play_col(scenario, 3)
	await _wait_input(scenario)
	_check(_count(_board(scenario), O) == 1, "stale plan: the opponent replied")
	_check(not scenario._opponent_planned(), "stale plan: no plan after his play")
	loop.phase = TurnLoop.Phase.OPPONENT_TURN # the window before his next choice
	var one: Array[GoobDefinition] = [TurnLoop.VANILLA]
	loop.opponent_deck.hand.assign(one)
	await scenario.debug_discard_random(O)
	_check(loop.opponent_deck.hand.is_empty(), "stale plan: his only Goob is discarded")
	loop.phase = TurnLoop.Phase.PLAYER_TURN
	await _free(scenario)


# --- Debug auto-play (M6e) ----------------------------------------------------

## Waits (up to `ms`) until the player has `n` Goobs on the board.
func _wait_player_goobs(scenario: Control, n: int, ms := 3000) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while _count(_board(scenario), P) < n and Time.get_ticks_msec() < deadline:
		await process_frame


func _test_autoplay_plays_for_player() -> void:
	var scenario := await _make(0.3)
	var hud: ScenarioHud = scenario._hud
	_check(scenario._input_enabled and not scenario._turn_timer.is_stopped(), "autoplay: starts on the player's live turn")
	scenario.set_autoplay(true)
	_check(_flow().autoplay, "autoplay: the flag is on")
	_check(not scenario._input_enabled, "autoplay: input locked")
	_check(scenario._turn_timer.is_stopped(), "autoplay: the turn timer stops")
	_check(hud.timer_text() == ScenarioHud.NO_TIMER, "autoplay: the timer shows — (got %s)" % hud.timer_text())
	var timer_ran := false
	var deadline := Time.get_ticks_msec() + 3000
	while _count(_board(scenario), P) < 1 and Time.get_ticks_msec() < deadline:
		await process_frame
		if scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN and not scenario._turn_timer.is_stopped():
			timer_ran = true
	_check(_count(_board(scenario), P) == 1, "autoplay: a player Goob was played (got %d)" % _count(_board(scenario), P))
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "autoplay: then it's the opponent's turn")
	_check(not timer_ran, "autoplay: the player timer never started")
	_check(not scenario._fuse.visible, "autoplay: no fuse")
	scenario.set_autoplay(false)
	await _free(scenario)


func _test_autoplay_off_during_think() -> void:
	var scenario := await _make(0.5)
	var hud: ScenarioHud = scenario._hud
	scenario.set_autoplay(true)
	scenario.set_autoplay(false)
	_check(not _flow().autoplay, "autoplay off: the flag is off")
	_check(scenario._input_enabled, "autoplay off: input unlocked")
	_check(not scenario._turn_timer.is_stopped() and scenario._turn_timer.time_left > 29.9, "autoplay off: turn timer restarted at 30 s")
	await process_frame
	_check(hud.timer_text() == "30", "autoplay off: the timer shows 30 (got %s)" % hud.timer_text())
	await create_timer(2.0).timeout
	_check(_count(_board(scenario), P) == 0, "autoplay off: no player Goob dropped")
	_check(scenario._input_enabled, "autoplay off: input still enabled")
	await _free(scenario)


func _test_autoplay_cancels_drag() -> void:
	var scenario := await _make(0.3)
	var hand := _hand_view(scenario)
	scenario._last_tap_key = ""
	var start := hand.slot_center(0)
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_drag(_col_pos(scenario, 5))
	_check(hand.is_dragging() and _view(scenario).is_preview_visible(), "autoplay drag: dragging with the ghost up")
	scenario.set_autoplay(true)
	_check(not _view(scenario).is_preview_visible(), "autoplay drag: the aim ghost is hidden")
	_check(not hand.is_dragging(), "autoplay drag: the drag is cancelled")
	_touch(_col_pos(scenario, 5), false) # the finger lifts: ignored
	_check(_count(_board(scenario), P) == 0, "autoplay drag: releasing doesn't drop")
	await _wait_player_goobs(scenario, 1)
	_check(_count(_board(scenario), P) == 1, "autoplay drag: exactly one player Goob played (got %d)" % _count(_board(scenario), P))
	scenario.set_autoplay(false)
	await _free(scenario)


func _test_autoplay_draw_replay_keeps_decks() -> void:
	var rolled := {"player": _vanilla_deck(), "opponent": _vanilla_deck()}
	_flow().rolled_decks = rolled
	_flow().fade_sec = 0.0
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if column == 6 and row == 5:
				continue
			board.drop(column, _fill_owner(column, row))
	view.sync_from_board(board)
	scenario.set_autoplay(true)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.DRAW, "autoplay draw: it played the last cell, a draw")
	_check(scenario.get_node("%EndOverlay").visible, "autoplay draw: the Draw screen shows")
	var deadline := Time.get_ticks_msec() + 3000
	while (current_scene == null or current_scene.name != "CoinFlip") and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(current_scene != null and current_scene.name == "CoinFlip", "autoplay draw: Replay pressed by itself → coin flip")
	_check(is_same(_flow().rolled_decks, rolled), "autoplay draw: the rolled decks are kept")
	_check(_flow().autoplay, "autoplay draw: auto-play stays on")
	_flow().autoplay = false
	if current_scene != null:
		current_scene.free()
	current_scene = null
	_flow().rolled_decks = {}
	_flow().fade_sec = _flow().FADE_SEC
	await _free(scenario)


func _test_autoplay_off_at_win() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	for column in 3:
		board.drop(column, P)
		board.drop(column, O)
	_view(scenario).sync_from_board(board)
	scenario.set_autoplay(true)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "autoplay win: it takes the winning column")
	_check(not _flow().autoplay, "autoplay win: turns itself off at the end")
	_check(not scenario._hud.autoplay_button().visible, "autoplay win: the button hides with Pause")
	await _free(scenario)


func _test_autoplay_button_hidden_by_setting() -> void:
	var scenario := await _make(5.0)
	var hud: ScenarioHud = scenario._hud
	var button: Button = hud.autoplay_button()
	_check(button.visible, "autoplay button: shown by default in debug builds")
	_check(button.size.is_equal_approx(ScenarioHud.PAUSE_SIZE), "autoplay button: same size as Pause")
	var pause := hud.pause_button()
	_check(is_equal_approx(button.position.x, pause.position.x + ScenarioHud.PAUSE_SIZE.x + ScenarioHud.PAUSE_INSET), "autoplay button: right of Pause")
	button.pressed.emit()
	_check(_flow().autoplay and hud.is_autoplay_lit(), "autoplay button: pressing turns it on, lit")
	button.pressed.emit()
	_check(not _flow().autoplay and not hud.is_autoplay_lit(), "autoplay button: pressing again gives control back")
	_check(scenario._input_enabled, "autoplay button: input back on")
	_settings().set_autoplay_button(false)
	_check(not button.visible, "autoplay button: hidden when the option is off")
	_settings().set_autoplay_button(true)
	_check(button.visible, "autoplay button: back when the option is on")
	await _free(scenario)


## Fix round 1: quitting to the title (pause Quit, Back to title) turns it off.
func _test_autoplay_off_on_return_to_title() -> void:
	_flow().fade_sec = 0.0
	_flow().autoplay = true
	_flow().return_to_title()
	_check(not _flow().autoplay, "autoplay: return to title turns it off")
	await process_frame
	await process_frame
	if current_scene != null:
		current_scene.free()
	current_scene = null
	_flow().fade_sec = _flow().FADE_SEC


## Fix round 1: "View board" inside the 1 s doesn't lose the draw's auto Replay.
func _test_autoplay_replay_after_view_board() -> void:
	_flow().fade_sec = 0.0
	var scenario := await _make(0.0)
	var board := _board(scenario)
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if column == 6 and row == 5:
				continue
			board.drop(column, _fill_owner(column, row))
	_view(scenario).sync_from_board(board)
	scenario.set_autoplay(true)
	await process_frame
	scenario.set_reviewing(true)
	await create_timer(1.3).timeout
	_check(current_scene == null or current_scene.name != "CoinFlip", "autoplay review: no Replay while viewing the board")
	scenario.set_reviewing(false)
	var deadline := Time.get_ticks_msec() + 3000
	while (current_scene == null or current_scene.name != "CoinFlip") and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(current_scene != null and current_scene.name == "CoinFlip", "autoplay review: Replay after Show result")
	_flow().autoplay = false
	if current_scene != null:
		current_scene.free()
	current_scene = null
	_flow().fade_sec = _flow().FADE_SEC
	await _free(scenario)


## Fix round 1: the planned auto move doesn't play once the flag is off.
func _test_autoplay_move_needs_flag() -> void:
	var scenario := await _make(0.5)
	scenario.set_autoplay(true)
	_flow().autoplay = false # cleared without set_autoplay()
	await create_timer(1.5).timeout
	_check(_count(_board(scenario), P) == 0, "autoplay guard: no move once the flag is off")
	await _free(scenario)


# --- Final review fixes (M6e) -------------------------------------------------

## True when the fan shows exactly the player's hand, in order.
func _fan_in_step(scenario: Control) -> bool:
	var fan := _hand_view(scenario)
	var hand: Array[GoobDefinition] = scenario._loop.player_deck.hand
	var in_step := fan.count() == hand.size()
	for i in mini(fan.count(), hand.size()):
		in_step = in_step and fan._cards[i].get_meta(&"goob", null) == hand[i]
	return in_step


## A give during the timeout reveal would re-add the card the timeout already
## took out of the fan (wrong Goob played): refused with "Not now".
func _test_debug_give_refused_in_timeout_reveal() -> void:
	_flow().player_moves_first = true
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = false
	scenario.deck = _vanilla_deck()
	scenario.opponent_delay_sec = 5.0
	scenario.turn_seconds = 0.2
	scenario.timeout_reveal_sec = 0.4
	root.add_child(scenario)
	await process_frame
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	_select_hand(scenario)
	await create_timer(0.3).timeout
	_check(scenario._timed_out and _count(_board(scenario), P) == 0, "give in reveal: in the timeout reveal")
	var before: Array[GoobDefinition] = scenario._loop.player_deck.hand.duplicate()
	scenario.debug_give(fat, P)
	_check(scenario._loop.player_deck.hand == before, "give in reveal: hand unchanged")
	_check(scenario._toast._label.text == "Not now", "give in reveal: toasts Not now (got %s)" % scenario._toast._label.text)
	await create_timer(0.4).timeout
	_check(_count(_board(scenario), P) == 1, "give in reveal: the timeout Goob dropped")
	_check(_fan_in_step(scenario), "give in reveal: fan in step with the hand after the drop")
	await _free(scenario)


## A give during a drawn-Goob reveal would free the revealing card (softlock):
## refused with "Not now".
func _test_debug_give_refused_in_draw_reveal() -> void:
	var scenario := await _make(5.0, true, 30.0, true)
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN and not scenario._input_enabled, "give in draw: input locked at the turn start")
	var before: Array[GoobDefinition] = scenario._loop.player_deck.hand.duplicate()
	scenario.debug_give(fat, P)
	_check(scenario._loop.player_deck.hand == before, "give in draw: hand unchanged")
	_check(scenario._toast._label.text == "Not now", "give in draw: toasts Not now")
	await _wait_input(scenario)
	_check(scenario._input_enabled, "give in draw: the turn still starts (no softlock)")
	_check(_fan_in_step(scenario), "give in draw: fan in step with the hand")
	await _free(scenario)


## Your last hand Goob can't be discarded (a timeout on an empty hand would
## error); and nothing is discarded while your hand is moving.
func _test_debug_discard_player_guards() -> void:
	var scenario := await _make(5.0)
	var loop: TurnLoop = scenario._loop
	var one: Array[GoobDefinition] = [TurnLoop.VANILLA]
	loop.player_deck.hand.assign(one)
	_hand_view(scenario).rebuild(loop.player_deck.hand)
	await scenario.debug_discard_random(P)
	# Sean (2026-11-23): losing your last Goob is fine; this turn is skipped.
	_check(loop.player_deck.hand.is_empty() and loop.player_deck.discard_pile.size() == 1, "discard last: your last Goob is discarded")
	_check(scenario._toast._label.text == "Turn skipped", "discard last: toasts Turn skipped")
	_check(loop.phase == TurnLoop.Phase.OPPONENT_TURN and loop.last_skipped == [P], "discard last: the turn passes to the opponent")
	_check(not scenario._input_enabled and scenario._turn_timer.is_stopped(), "discard last: input locked, timer stopped")
	await _free(scenario)
	scenario = await _make(5.0, true, 0.2)
	scenario.timeout_reveal_sec = 0.4
	loop = scenario._loop
	await create_timer(0.3).timeout
	_check(scenario._timed_out, "discard guard: in the timeout reveal")
	var before := loop.player_deck.hand.size()
	await scenario.debug_discard_random(P)
	_check(loop.player_deck.hand.size() == before and loop.player_deck.discard_pile.is_empty(), "discard guard: nothing discarded in the reveal")
	await create_timer(0.5).timeout
	_check(_fan_in_step(scenario), "discard guard: fan in step after the timeout drop")
	await _free(scenario)


## Pills follow the statuses at each turn start, also on auto-play turns that
## never switch input on.
func _test_pills_refresh_on_autoplay_turn_start() -> void:
	var scenario := await _make(0.3, false)
	_flow().autoplay = true
	scenario._loop.add_status(&"t", P, "Test", "x", -1)
	var deadline := Time.get_ticks_msec() + 4000
	while scenario._autoplay_timer.is_stopped() and _count(_board(scenario), P) == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(_count(_board(scenario), O) == 1, "pills refresh: the opponent played first")
	_check(scenario._pills.buttons().size() == 1, "pills refresh: the pill shows on the auto-play turn (got %d)" % scenario._pills.buttons().size())
	scenario.set_autoplay(false)
	_flow().autoplay = false
	await _free(scenario)


## Auto-play with nothing to play turns itself off, so HUD and flag agree.
func _test_autoplay_no_move_turns_off() -> void:
	var scenario := await _make(5.0)
	_flow().autoplay = true
	scenario._hud.set_autoplay_lit(true)
	scenario._set_input_enabled(false)
	scenario._loop.player_deck.hand.clear()
	scenario._run_autoplay_turn()
	_check(not _flow().autoplay, "autoplay no move: the flag is off")
	_check(not scenario._hud.is_autoplay_lit(), "autoplay no move: the button is unlit")
	_check(scenario._input_enabled, "autoplay no move: your turn as usual")
	_flow().autoplay = false
	await _free(scenario)


## Sean (2026-11-23): auto-play's Goob flips up from behind the board like the
## opponent's.
func _test_autoplay_flips_up_from_behind() -> void:
	var scenario := await _make(0.3, true, 30.0, true) # short think: auto-play thinks like him
	var ready_by := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < ready_by and not scenario._input_enabled:
		await process_frame # GAME START, banner, first draw reveal
	_check(scenario._input_enabled, "auto-play rise: your turn is ready")
	var behind: Node = scenario._board_view._behind
	scenario.set_autoplay(true)
	var seen := false
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not seen:
		await process_frame
		seen = behind.get_child_count() > 0
	_check(seen, "auto-play: a Goob rises from behind the board")
	var theirs := 0
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if scenario._loop.board.get_owner(column, row) == O:
				theirs += 1
	_check(seen and theirs == 0, "auto-play: it is your Goob (he hasn't played yet)")
	_flow().autoplay = false
	await _free(scenario)


# --- M6e Move ----------------------------------------------------------------

## Each move setup: [played Goob, column, [[column, owner, GoobDefinition]...], sounds].
func _test_move_animations() -> void:
	var sinister: GoobDefinition = load("res://resources/goobs/sinister_goob.tres")
	var lopsided: GoobDefinition = load("res://resources/goobs/lopsided_goob.tres")
	var tipsy: GoobDefinition = load("res://resources/goobs/tipsy_goob.tres")
	var bouncy: GoobDefinition = load("res://resources/goobs/bouncy_goob.tres")
	var springy: GoobDefinition = load("res://resources/goobs/springy_goob.tres")
	var setups := [
		["push", sinister, 3, [[1, O, TurnLoop.VANILLA]], [&"roll"]],
		["push chain", sinister, 4, [[2, O, TurnLoop.VANILLA], [2, O, tipsy]], [&"roll"]],
		["bouncy", TurnLoop.VANILLA, 3, [[3, O, bouncy]], [&"bounce"]],
		["springy", lopsided, 3, [[1, O, springy]], [&"roll", &"bounce"]],
		["fat chain", FAT, 6, [[5, O, TurnLoop.VANILLA], [5, O, lopsided]], [&"crunch"]],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var board := _board(scenario)
		for put: Array in setup[3]:
			var row := board.drop(put[0], put[1])
			scenario._loop._cell_goobs[Vector2i(put[0], row)] = put[2]
		_view(scenario).sync_from_board(board)
		_give(scenario, setup[1])
		_play_col(scenario, setup[2])
		var deadline := Time.get_ticks_msec() + 10000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "move %s: play finishes, opponent's turn starts" % label)
		for sound: StringName in setup[4]:
			_check(scenario._sfx.history.has(sound), "move %s: sound %s" % [label, sound])
		_check(_view_matches(scenario), "move %s: animated view matches the board" % label)
		await _free(scenario)


## M6e Destroy: each destroy Goob plays its step through to the opponent's
## turn with the view matching the board. Setup: [label, played Goob, column,
## [[column, owner, Goob, armed_by]], sounds, player's destroyed pile].
func _test_destroy_animations() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	var V := TurnLoop.VANILLA
	var setups := [
		["volatile", g.call("volatile"), 3, [[0, O, V, E]], [&"crunch"], []],
		["crushing", g.call("crushing"), 2, [[2, O, V, E], [2, O, V, E]], [&"crunch"], []],
		["brawling", g.call("brawling"), 3, [[2, O, V, E]], [&"crunch"], []],
		["spiteful", V, 3, [[3, O, g.call("spiteful"), O]], [&"crunch"], []],
		["occult", g.call("occult"), 6, [[0, O, V, E]], [&"resurrect"], [FAT]],
		# His Smouldering fires at his turn start, after the red banner.
		["smouldering", V, 6, [[3, O, g.call("smouldering"), O], [2, P, V, E]], [&"crunch"], []],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var board := _board(scenario)
		var loop: TurnLoop = scenario._loop
		for put: Array in setup[3]:
			var row := board.drop(put[0], put[1])
			loop._cell_goobs[Vector2i(put[0], row)] = put[2]
			if put[3] != E:
				loop._mark(Vector2i(put[0], row), &"armed_by", put[3])
		for goob: GoobDefinition in setup[5]:
			loop.player_deck.destroyed_pile.append(goob)
		_view(scenario).sync_from_board(board)
		_give(scenario, setup[1])
		_play_col(scenario, setup[2])
		var deadline := Time.get_ticks_msec() + 15000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "destroy %s: play finishes, opponent's turn starts" % label)
		for sound: StringName in setup[4]:
			_check(scenario._sfx.history.has(sound), "destroy %s: sound %s" % [label, sound])
		_check(_view_matches(scenario), "destroy %s: animated view matches the board" % label)
		await _free(scenario)


## M6e Discard: each discard Goob plays out (cue, reveals, a Defiant's drop,
## Fickle's draw, the destroys, Thrifty's return), then the opponent's turn
## starts with the view on the board and the fan on the hand.
func _test_discard_animations() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	var V := TurnLoop.VANILLA
	var defiant: GoobDefinition = g.call("defiant")
	# label, your hand (index 0 is played), column, board Goobs [column, owner],
	# his hand ([] = as dealt), your discard pile, sounds
	var setups := [
		["distracting", [g.call("distracting"), V, V], 3, [], [], [], []],
		["distracting defiant", [g.call("distracting"), V], 3, [], [defiant], [], []],
		["fickle", [g.call("fickle"), V, V], 3, [], [], [], [&"draw_pop"]],
		["ruthless", [g.call("ruthless"), V, defiant], 3, [[0, O]], [], [], [&"crunch"]],
		["reckless", [g.call("reckless"), defiant, V, V], 3, [], [], [], []],
		["thrifty", [g.call("thrifty"), V], 3, [], [], [FAT], [&"resurrect"]],
		["desperate", [g.call("desperate"), V, V], 3, [[0, O]], [], [], [&"crunch"]],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var board := _board(scenario)
		var loop: TurnLoop = scenario._loop
		for put: Array in setup[3]:
			var row := board.drop(put[0], put[1])
			loop._cell_goobs[Vector2i(put[0], row)] = V
		if not setup[4].is_empty():
			loop.opponent_deck.hand.assign(setup[4])
		loop.player_deck.discard_pile.assign(setup[5])
		loop.player_deck.hand.assign(setup[1])
		_hand_view(scenario).rebuild(loop.player_deck.hand)
		_view(scenario).sync_from_board(board)
		_play_col(scenario, setup[2])
		var deadline := Time.get_ticks_msec() + 25000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "discard %s: play finishes, opponent's turn starts" % label)
		for sound: StringName in setup[6]:
			_check(scenario._sfx.history.has(sound), "discard %s: sound %s" % [label, sound])
		_check(_view_matches(scenario), "discard %s: animated view matches the board" % label)
		_check(_fan_in_step(scenario), "discard %s: fan matches the hand" % label)
		await _free(scenario)


## M6e Draw: Jinxing's toast on his turn draw, Plentiful's draws revealed in
## your fan during his turn, Generous's pill; each play finishes cleanly.
func _test_draw_animations() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	var V := TurnLoop.VANILLA
	# label, your hand (index 0 is played), your hand after his turn draw, status id
	var setups := [
		["jinxing", [g.call("jinxing"), V, V], 2, &""],
		["generous", [g.call("generous"), V, V], 2, &"generous"],
		["plentiful", [g.call("plentiful"), V, V], 3, &"plentiful"],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var loop: TurnLoop = scenario._loop
		var his := loop.opponent_deck.hand.size()
		loop.player_deck.hand.assign(setup[1])
		_hand_view(scenario).rebuild(loop.player_deck.hand)
		_play_col(scenario, 3)
		var deadline := Time.get_ticks_msec() + 25000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "draw %s: play finishes, opponent's turn starts" % label)
		_check(loop.player_deck.hand.size() == setup[2], "draw %s: your hand is %d (got %d)" % [label, setup[2], loop.player_deck.hand.size()])
		_check(_fan_in_step(scenario), "draw %s: fan matches the hand" % label)
		_check(_view_matches(scenario), "draw %s: animated view matches the board" % label)
		if label == "jinxing":
			_check(loop.opponent_deck.hand.size() == his and scenario._toast._label.text == scenario.MSG_OPPONENT_JINXED, "draw jinxing: no draw for him, toast says so")
		if setup[3] != &"":
			_check(loop.has_status(setup[3], BoardState.CellOwner.PLAYER), "draw %s: pill on your side" % label)
		await _free(scenario)


## M6e Tech: each tech Goob plays through the real scenario (animations,
## pills, the AI keeping out of a locked column) and leaves the view in step.
func _test_tech_animations() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	var V := TurnLoop.VANILLA
	var P := BoardState.CellOwner.PLAYER
	var O := BoardState.CellOwner.OPPONENT
	# label, played Goob, Goobs placed first [column, goob, owner], pill [id, side]
	var setups := [
		["steadfast", g.call("steadfast"), [], [&"steadfast", P]],
		["loyal", g.call("loyal"), [], [&"loyal", P]],
		["stalwart", g.call("stalwart"), [], []],
		["territorial", g.call("territorial"), [], [&"territorial", O]],
		["stifling", g.call("stifling"), [], []],
		["inspiring", g.call("inspiring"), [[4, g.call("fat"), P], [5, V, O]], []],
		["thieving", g.call("thieving"), [[5, g.call("bouncy"), O]], []],
		["hoarding", g.call("hoarding"), [], [&"hoarding", P]],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var loop: TurnLoop = scenario._loop
		for placed: Array in setup[2]:
			var row := loop.board.drop(placed[0], placed[2])
			loop._cell_goobs[Vector2i(placed[0], row)] = placed[1]
		_view(scenario).sync_from_board(loop.board)
		loop.player_deck.hand.assign([setup[1], V, V])
		_hand_view(scenario).rebuild(loop.player_deck.hand)
		_play_col(scenario, 3)
		var deadline := Time.get_ticks_msec() + 25000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "tech %s: play finishes, opponent's turn starts" % label)
		_check(_fan_in_step(scenario), "tech %s: fan matches the hand" % label)
		_check(_view_matches(scenario), "tech %s: animated view matches the board" % label)
		var pill: Array = setup[3]
		if not pill.is_empty():
			_check(loop.has_status(pill[0], pill[1]), "tech %s: pill shows" % label)
		match label:
			"territorial":
				_check(scenario._opponent_column != 3, "tech territorial: he keeps out of the locked column")
			"stifling":
				_check(loop.has_status(&"stifled", O), "tech stifling: his next Goob is stifled")
			"inspiring":
				_check(loop.last_effect.get("inspired", Vector2i(-1, -1)) == Vector2i(4, 0), "tech inspiring: the Fat fired again")
			"thieving":
				_check(loop.goob_at(3, 0).effect_type == GoobDefinition.EffectType.BOUNCY and scenario._toast._label.text == scenario.MSG_STOLE % "Bouncy Goob", "tech thieving: stole the Bouncy, toast says so")
		await _free(scenario)


## M6e Uniquely powerful: each one plays out, the animated view matches the
## board (Goobs that fell off are gone), the next turn starts.
func _test_unique_animations() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	var V := TurnLoop.VANILLA
	var P := BoardState.CellOwner.PLAYER
	var O := BoardState.CellOwner.OPPONENT
	# label, played Goob, Goobs placed first [column, goob, owner], last played {side: goob}
	var setups := [
		["seismic", g.call("seismic"), [[0, V, O], [6, V, O], [1, V, P]], {}],
		["sinking", g.call("sinking"), [[0, V, O], [0, V, P], [5, V, O]], {}],
		["rowdy", g.call("rowdy"), [[0, V, O], [5, V, O], [5, V, P]], {}],
		["nostalgic", g.call("nostalgic"), [[4, V, O]], {P: g.call("fat")}],
		["mocking", g.call("mocking"), [], {O: g.call("bouncy")}],
	]
	for setup in setups:
		var label: String = setup[0]
		var scenario := await _make(5.0, true, 30.0, true)
		await _wait_input(scenario)
		var loop: TurnLoop = scenario._loop
		for placed: Array in setup[2]:
			var row := loop.board.drop(placed[0], placed[2])
			loop._cell_goobs[Vector2i(placed[0], row)] = placed[1]
		loop._last_played = setup[3].duplicate()
		_view(scenario).sync_from_board(loop.board)
		loop.player_deck.hand.assign([setup[1], V, V])
		_hand_view(scenario).rebuild(loop.player_deck.hand)
		_play_col(scenario, 3)
		var deadline := Time.get_ticks_msec() + 25000
		while scenario._opponent_timer.is_stopped() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not scenario._opponent_timer.is_stopped(), "unique %s: play finishes, opponent's turn starts" % label)
		_check(_fan_in_step(scenario), "unique %s: fan matches the hand" % label)
		_check(_view_matches(scenario), "unique %s: animated view matches the board" % label)
		match label:
			"seismic":
				_check(loop.player_deck.destroyed_pile.size() + loop.opponent_deck.destroyed_pile.size() == 1, "unique seismic: the edge Goob fell off")
			"sinking":
				_check(loop.board.get_owner(0, 0) == P and loop.opponent_deck.destroyed_pile.size() == 2, "unique sinking: bottom row gone, the rest fell")
			"nostalgic":
				_check(loop.board.is_empty(4, 0) and scenario._toast._label.text == scenario.MSG_COPIED % "Fat Goob", "unique nostalgic: became Fat, toast says so")
			"mocking":
				_check(loop.goob_at(3, 0).effect_type == GoobDefinition.EffectType.BOUNCY, "unique mocking: became his Bouncy")
		await _free(scenario)
