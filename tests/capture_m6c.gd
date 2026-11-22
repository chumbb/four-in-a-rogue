extends SceneTree
## Dev tool: screenshots of the M6c moments (not a test): low-time fuse with
## worried hand Goobs, aim float flip, opponent thinking, player win lead-in,
## exploded portrait. Run windowed:
##   godot -s res://tests/capture_m6c.gd -- <out_dir>
## Uses a scratch settings file, so the player's options are untouched.

const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT


func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join("%s.png" % name))
	print("saved ", name)


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
	await _frames(10)
	root.get_node("GameFlow").player_moves_first = true
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	scenario.turn_seconds = 14.0
	root.add_child(scenario)
	current_scene = scenario
	await create_timer(1.3).timeout
	await _shot(dir, "draw_caption")
	var deadline := Time.get_ticks_msec() + 5000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame
	var board: BoardState = scenario._loop.board
	for c in 3:
		board.drop(c, P)
	board.drop(5, O)
	board.drop(6, O)
	scenario.get_node("%BoardView").sync_from_board(board)
	await create_timer(6.5).timeout
	await _shot(dir, "fuse_worried")
	scenario._selected = 0
	scenario.get_node("%PlayerHand").select(0)
	scenario._show_aim(4)
	await _frames(5)
	await _shot(dir, "hand_flip_midway")
	await _frames(30)
	await _shot(dir, "aim_float")
	scenario._hide_aim()
	scenario.try_drop(3, 0)
	await create_timer(2.2).timeout
	await _shot(dir, "win_lead_in")
	await create_timer(6.0).timeout
	await _shot(dir, "win_end")
	await create_timer(1.5).timeout
	await _shot(dir, "end_overlay")
	scenario.get_node("%ViewButton").pressed.emit()
	await _frames(5)
	await _shot(dir, "review")
	quit()
