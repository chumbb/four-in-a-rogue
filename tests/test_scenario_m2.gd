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
	_check(board.is_empty(5, 0), "no drops after win")
	_check(view._tokens[Vector2i(0, 0)].scale.y > 1.5, "winning token highlighted")

	scenario._reset_board()
	_check(not scenario._game_over and view.input_enabled, "reset re-enables play")

	scenario.queue_free()
	await process_frame
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
