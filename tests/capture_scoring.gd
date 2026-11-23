extends SceneTree
## Dev tool: screenshots of the scoring sequence (flip to back, multiplier
## floats into the gap, total) and a toast in the gap. Run windowed:
##   godot -s res://tests/capture_scoring.gd -- <out_dir>

const P := BoardState.CellOwner.PLAYER


func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("%s.png" % name))
	print("saved ", name)


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1080, 1920)
	var settings := root.get_node("Settings")
	settings.path = "user://capture_settings.cfg"
	settings.reset()
	root.get_node("GameFlow").player_moves_first = true
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	root.add_child(scenario)
	current_scene = scenario
	var deadline := Time.get_ticks_msec() + 8000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame
	scenario._reject_placement("Column full")
	await create_timer(0.2).timeout
	await _shot(dir, "toast_gap")
	var board: BoardState = scenario._loop.board
	for c in 3:
		board.drop(c, P)
	scenario.get_node("%BoardView").sync_from_board(board)
	await create_timer(1.5).timeout
	scenario.try_drop(3, 0)
	var t0 := Time.get_ticks_msec()
	for i in 12:
		await create_timer(0.35).timeout
		await _shot(dir, "score_%02d_%dms" % [i, Time.get_ticks_msec() - t0])
	quit()
