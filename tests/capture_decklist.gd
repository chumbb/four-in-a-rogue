extends SceneTree
## Dev tool: screenshots of the pause menu and its Decklist window (not a test).
##   godot -s res://tests/capture_decklist.gd -- <out_dir> [width height [insets]]

func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join("%s_%dx%d.png" % [name, img.get_width(), img.get_height()]))
	print("saved ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(args[1]), int(args[2])) if args.size() > 2 else Vector2i(1080, 1920)
	var settings := root.get_node("Settings")
	settings.path = "user://capture_settings.cfg"
	settings.reset()
	await _frames(10)
	if args.size() > 3:
		SafeArea.simulate_insets = true
	root.get_node("GameFlow").player_moves_first = true
	root.get_node("GameFlow").debug_forced_categories = {"player": "Bottomless Pockets"}
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	root.add_child(scenario)
	current_scene = scenario
	await _frames(40)
	scenario._hud.pause_button().pressed.emit()
	await _frames(5)
	await _shot(dir, "pause_menu")
	scenario._pause.button("Decklist").pressed.emit()
	await _frames(5)
	await _shot(dir, "decklist")
	SafeArea.simulate_insets = false
	root.get_node("GameFlow").debug_forced_categories = {}
	quit()
