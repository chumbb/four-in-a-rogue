extends SceneTree
## Headless test for the scenario scene: raycast picking, token colours, the
## player/opponent turn loop, full-column rejection, end overlay, draw replay.
## Run: godot --headless -s res://tests/test_scenario.gd

const SCENE := "res://scenes/scenario/scenario.tscn"
const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT
const E := BoardState.CellOwner.EMPTY

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
	root.size = Vector2i(1920, 1080) # headless root defaults to 64×64
	var saved_first: bool = _flow().player_moves_first

	await _test_picking_and_player_then_opponent()
	await _test_right_click_ignored()
	await _test_click_during_opponent_turn()
	await _test_full_column_on_player_turn()
	await _test_win_shows_end()
	await _test_draw_shows_replay()
	await _test_opponent_first()
	await _test_real_input()
	await _test_free_during_opponent_delay()

	_flow().player_moves_first = saved_first
	await process_frame
	await process_frame
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Helpers -----------------------------------------------------------------

## GameFlow is an autoload; its name is not a compile-time identifier in -s scripts.
func _flow() -> Node:
	return root.get_node("GameFlow")


func _make(delay: float, player_first := true) -> Control:
	_flow().player_moves_first = player_first
	var scenario: Control = load(SCENE).instantiate()
	scenario.opponent_delay_sec = delay
	root.add_child(scenario)
	await physics_frame
	await physics_frame
	return scenario


func _free(scenario: Control) -> void:
	if is_instance_valid(scenario):
		scenario.queue_free()
	await process_frame
	await process_frame


func _view(scenario: Control) -> Node3D:
	return scenario.get_node("%BoardView3D")


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


func _glows(view: Node3D, cell: Vector2i) -> bool:
	var mat := view._tokens[cell].material_override as StandardMaterial3D
	return mat.emission_enabled


# --- Tests -------------------------------------------------------------------

func _test_picking_and_player_then_opponent() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var cam: Camera3D = view.get_node("Camera3D")

	# Raycast picking: every column centre must resolve to its own index.
	for column in BoardState.COLUMNS:
		var screen := cam.unproject_position(view.grid_to_world(column, 2))
		var picked: int = view._pick_column(screen)
		_check(picked == column, "pick column %d got %d (screen %s)" % [column, picked, screen])
	_check(view._pick_column(Vector2(-500, -500)) == -1, "off-board pick returns -1")

	# _test_player_then_opponent
	view.column_clicked.emit(3, MOUSE_BUTTON_LEFT)
	await process_frame
	await process_frame
	var board := _board(scenario)
	_check(board.get_owner(3, 0) == P, "LMB drops player at (3,0)")
	_check(_count(board, O) == 1, "opponent replied once (got %d)" % _count(board, O))
	_check(_count(board, P) == 1, "one player token")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "back to player turn")
	_check(view._tokens.size() == 2, "view shows 2 tokens (got %d)" % view._tokens.size())
	_check(view.input_enabled, "input re-enabled for player")

	# Token colours.
	var p_col: Color = view._tokens[Vector2i(3, 0)].material_override.albedo_color
	_check(p_col.b > p_col.r, "player token is blue (got %s)" % p_col)
	for cell in view._tokens:
		if board.get_owner(cell.x, cell.y) == O:
			var o_col: Color = view._tokens[cell].material_override.albedo_color
			_check(o_col.r > o_col.b, "opponent token is red (got %s)" % o_col)
	await _free(scenario)


func _test_right_click_ignored() -> void:
	var scenario := await _make(0.0)
	var board := _board(scenario)
	var before := board.to_debug_string()
	_view(scenario).column_clicked.emit(0, MOUSE_BUTTON_RIGHT)
	await process_frame
	_check(board.to_debug_string() == before, "RMB leaves board unchanged")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "RMB keeps player turn")
	await _free(scenario)


func _test_click_during_opponent_turn() -> void:
	var scenario := await _make(5.0)
	var view := _view(scenario)
	var board := _board(scenario)
	view.column_clicked.emit(0, MOUSE_BUTTON_LEFT)
	view.column_clicked.emit(1, MOUSE_BUTTON_LEFT)
	_check(board.get_owner(0, 0) == P, "first click drops player")
	_check(board.is_empty(1, 0), "click during opponent turn ignored")
	_check(_count(board, P) == 1, "only one player token")
	_check(_count(board, O) == 0, "opponent still waiting on delay")
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "phase is opponent turn")
	_check(not view.input_enabled, "input disabled during opponent turn")
	_check(scenario._toast.modulate.a < 0.1, "no toast for out-of-turn click")
	_check(scenario.try_drop(2) == -1, "try_drop refused during opponent turn")
	await _free(scenario)


func _test_full_column_on_player_turn() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	for i in BoardState.ROWS:
		board.drop(3, P if i % 2 == 0 else O)
	view.sync_from_board(board)
	var before := board.to_debug_string()
	view.column_clicked.emit(3, MOUSE_BUTTON_LEFT)
	_check(board.to_debug_string() == before, "full column leaves board unchanged")
	_check(scenario._toast._label.text == Toast.MSG_COLUMN_FULL, "toast says Column full")
	_check(scenario._toast.modulate.a > 0.9, "toast visible")
	_check(scenario._sfx_error.playing, "error sound playing")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "still player turn")
	_check(scenario.try_drop(3) == -1, "try_drop on full column returns -1")
	await process_frame
	await process_frame
	_check(absf(view._pivot.position.x) > 0.001, "board shakes after full column")
	await _free(scenario)


func _test_win_shows_end() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	var end_button: Button = scenario.get_node("%EndButton")
	_check(not end_button.visible, "end button hidden during play")
	for c in [0, 1, 2]:
		board.drop(c, P)
	for c in [6, 6, 5]:
		board.drop(c, O)
	view.sync_from_board(board)
	view.column_clicked.emit(3, MOUSE_BUTTON_LEFT)
	await process_frame
	_check(scenario._loop.result == TurnLoop.Result.PLAYER_WIN, "player wins")
	_check(scenario._result_label.text == "Win", "result label Win (got %s)" % scenario._result_label.text)
	_check(end_button.visible, "end button visible")
	_check(end_button.text == "Back to title", "end button says Back to title")
	_check(not view.input_enabled, "input disabled after win")
	_check(_glows(view, Vector2i(0, 0)) and _glows(view, Vector2i(3, 0)), "winning line highlighted")
	_check(_count(board, O) == 3, "opponent did not move after win")
	view.column_clicked.emit(4, MOUSE_BUTTON_LEFT)
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
	view.column_clicked.emit(6, MOUSE_BUTTON_LEFT)
	await process_frame
	var end_button: Button = scenario.get_node("%EndButton")
	_check(scenario._loop.result == TurnLoop.Result.DRAW, "full board is a draw")
	_check(scenario._result_label.text == "Draw", "result label Draw (got %s)" % scenario._result_label.text)
	_check(end_button.visible, "end button visible on draw")
	_check(end_button.text == "Replay", "end button says Replay")
	_check(not view.input_enabled, "input disabled after draw")
	await _free(scenario)


func _test_opponent_first() -> void:
	var scenario := await _make(0.0, false)
	await process_frame
	await process_frame
	var board := _board(scenario)
	_check(_count(board, O) == 1, "opponent opens (got %d O)" % _count(board, O))
	_check(_count(board, P) == 0, "no player tokens yet")
	_check(scenario._loop.phase == TurnLoop.Phase.PLAYER_TURN, "player turn after opener")
	_check(_view(scenario).input_enabled, "input enabled after opener")
	await _free(scenario)


## Drives the real path: root viewport → SubViewportContainer → SubViewport →
## BoardView3D._unhandled_input → raycast → column_clicked → try_drop.
func _test_real_input() -> void:
	var scenario := await _make(0.0)
	var view := _view(scenario)
	var board := _board(scenario)
	var container: SubViewportContainer = scenario.get_node("BoardViewportContainer")
	var sub: SubViewport = container.get_node("SubViewport")
	var cam: Camera3D = view.get_node("Camera3D")
	var to_root := func(column: int) -> Vector2:
		var p := cam.unproject_position(view.grid_to_world(column, 2))
		var rect := container.get_global_rect()
		return rect.position + p * rect.size / Vector2(sub.size)

	_push_motion(to_root.call(2))
	await process_frame
	_check(view._hovered_column == 2, "real motion hovers column 2 (got %d)" % view._hovered_column)
	_check(view._hover_disc.visible, "hover disc visible")

	_push_click(to_root.call(2), MOUSE_BUTTON_LEFT)
	await process_frame
	_check(board.get_owner(2, 0) == P, "real LMB drops player")
	_check(_count(board, O) == 1, "opponent replied to real click")

	var clicks: Array = []
	var record := func(c: int, b: int) -> void: clicks.append(b)
	view.column_clicked.connect(record)
	_push_click(to_root.call(2), MOUSE_BUTTON_WHEEL_UP)
	_push_click(to_root.call(2), MOUSE_BUTTON_MIDDLE)
	await process_frame
	view.column_clicked.disconnect(record)
	_check(clicks.is_empty(), "wheel/middle do not emit column_clicked (got %s)" % str(clicks))

	# Leave the board for the sidebar → hover clears.
	_push_motion(Vector2(1400, 500))
	await process_frame
	_check(view._hovered_column == -1, "hover cleared after leaving board (got %d)" % view._hovered_column)
	_check(not view._hover_disc.visible, "hover disc hidden after leaving board")
	await _free(scenario)


func _test_free_during_opponent_delay() -> void:
	var scenario := await _make(0.2)
	_view(scenario).column_clicked.emit(0, MOUSE_BUTTON_LEFT)
	_check(scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN, "opponent move pending")
	scenario.queue_free()
	await create_timer(0.3).timeout
	_check(not is_instance_valid(scenario), "scenario freed during opponent delay")
	_check(true, "reached end after pending opponent move outlived scene")


func _push_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _push_click(pos: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev)
