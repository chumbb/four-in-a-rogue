extends SceneTree
## Dev tool: screenshot of the Art pass D2 type art in the scenario (board
## tokens of every type, a hand of all five, the aim preview). Run windowed:
##   godot -s res://tests/capture_d2.gd -- <out_dir>

const IDS := ["vanilla", "convincing", "fat", "popular", "plentiful"]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
	var deadline := Time.get_ticks_msec() + 5000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(60)
	var goobs: Array[GoobDefinition] = []
	for id in IDS:
		goobs.append(load("res://resources/goobs/%s_goob.tres" % id))
	var loop: TurnLoop = scenario._loop
	for i in IDS.size():
		for side in [BoardState.CellOwner.PLAYER, BoardState.CellOwner.OPPONENT]:
			var row := loop.board.drop(i + 1, side)
			loop._cell_goobs[Vector2i(i + 1, row)] = goobs[i]
	scenario._board_view.sync_from_board(loop.board)
	loop.player_deck.hand = goobs.duplicate()
	scenario._hand.rebuild(goobs)
	scenario._select(2)
	scenario._show_aim(0)
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("d2_scenario.png"))
	print("saved")
	quit()
