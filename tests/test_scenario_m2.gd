extends SceneTree
## Headless smoke test for the M2 scenario scene: raycast picking, drops,
## view sync, full-column rejection, win stop, reset.
## Run: godot --headless -s res://tests/test_scenario_m2.gd

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
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	root.add_child(scenario)
	await physics_frame
	await physics_frame

	var view: Node3D = scenario.get_node("%BoardView3D")
	var cam: Camera3D = view.get_node("Camera3D")

	# Raycast picking: every column centre must resolve to its own index.
	for column in BoardState.COLUMNS:
		var screen := cam.unproject_position(view.grid_to_world(column, 2))
		var picked: int = view._pick_column(screen)
		_check(picked == column, "pick column %d got %d (screen %s)" % [column, picked, screen])
	_check(view._pick_column(Vector2(-500, -500)) == -1, "off-board pick returns -1")

	# Click signal → drop. Synthesize the signal the view would emit.
	view.column_clicked.emit(3, MOUSE_BUTTON_LEFT)
	view.column_clicked.emit(3, MOUSE_BUTTON_RIGHT)
	var board: BoardState = scenario._board
	_check(board.get_owner(3, 0) == BoardState.CellOwner.PLAYER, "LMB drops player")
	_check(board.get_owner(3, 1) == BoardState.CellOwner.OPPONENT, "RMB drops opponent")
	_check(view._tokens.size() == 2, "view shows 2 tokens")

	# Fill column 3 then overfill → rejected, toast visible, board unchanged.
	for i in 4:
		view.column_clicked.emit(3, MOUSE_BUTTON_LEFT if i % 2 else MOUSE_BUTTON_RIGHT)
	_check(board.column_full(3), "column 3 full")
	var before := board.to_debug_string()
	_check(scenario.try_drop(3, BoardState.CellOwner.PLAYER) == -1, "overfill returns -1")
	_check(board.to_debug_string() == before, "overfill leaves board unchanged")
	_check(scenario._toast.modulate.a > 0.9, "toast visible after overfill")
	_check(scenario._toast._label.text == Toast.MSG_COLUMN_FULL, "toast says Column full")
	_check(scenario._sfx_error.playing, "error sound playing")

	# Win: red across row 0 of columns 0,1,2 + 4 is NOT four (col 3 bottom is red, so 0..3 is).
	scenario._reset_board()
	_check(view._tokens.is_empty(), "reset clears tokens")
	for c in [0, 1, 2]:
		view.column_clicked.emit(c, MOUSE_BUTTON_LEFT)
	_check(not scenario._game_over, "three is not game over")
	view.column_clicked.emit(3, MOUSE_BUTTON_LEFT)
	_check(scenario._game_over, "four ends test game")
	_check(not view.input_enabled, "view input disabled after win")
	_check("Red" in scenario._result_label.text, "result names red")
	view.column_clicked.emit(5, MOUSE_BUTTON_LEFT)
	_check(board.is_empty(5, 0), "no drops after win (click)")
	_check(scenario.try_drop(5, BoardState.CellOwner.OPPONENT) == -1, "try_drop refused after win")
	_check(board.is_empty(5, 0), "no drops after win (try_drop)")
	_check(view._tokens[Vector2i(0, 0)].scale.y > 1.5, "winning token highlighted")

	scenario._reset_board()
	_check(not scenario._game_over and view.input_enabled, "reset re-enables play")

	# Invalid column is a caller bug: refused, no "Column full" feedback.
	scenario._toast.modulate.a = 0.0
	_check(scenario.try_drop(9, BoardState.CellOwner.PLAYER) == -1, "invalid column refused")
	_check(scenario._toast.modulate.a == 0.0, "invalid column shows no toast")

	await _test_real_input(scenario, view, board)

	scenario.queue_free()
	await process_frame
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## Drives the real path: root viewport → SubViewportContainer → SubViewport →
## BoardView3D._unhandled_input → raycast → column_clicked → try_drop.
func _test_real_input(scenario: Control, view: Node3D, board: BoardState) -> void:
	scenario._reset_board()
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
	_check(view._hover_bar.visible, "hover bar visible")

	_push_click(to_root.call(2), MOUSE_BUTTON_LEFT)
	_push_click(to_root.call(2), MOUSE_BUTTON_RIGHT)
	await process_frame
	_check(board.get_owner(2, 0) == BoardState.CellOwner.PLAYER, "real LMB drops player")
	_check(board.get_owner(2, 1) == BoardState.CellOwner.OPPONENT, "real RMB drops opponent")

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
	_check(not view._hover_bar.visible, "hover bar hidden after leaving board")


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
