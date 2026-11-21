extends SceneTree
## Dev tool: screenshots of the M6b screens (not a test): scenario HUD, turn
## banner, pause menu, quit confirm, Options (pause and title). Run windowed:
##   godot -s res://tests/capture_m6b.gd -- <out_dir> [width height [insets]]
## Uses a scratch settings file, so the player's options are untouched.

func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join("%s_%dx%d.png" % [name, img.get_width(), img.get_height()]))
	print("saved ", name, " ", img.get_size())


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
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	root.add_child(scenario)
	current_scene = scenario
	await _frames(12)
	await _shot(dir, "banner")
	var deadline := Time.get_ticks_msec() + 4000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(70)
	await _shot(dir, "hud")
	scenario._hud.pause_button().pressed.emit()
	await _frames(5)
	await _shot(dir, "pause")
	scenario._pause.button("Options").pressed.emit()
	await _frames(5)
	await _shot(dir, "pause_options")
	scenario._pause.options()._back.pressed.emit()
	scenario._pause.button("Quit").pressed.emit()
	await _frames(5)
	await _shot(dir, "quit_confirm")
	scenario._pause.button("ConfirmCancel").pressed.emit()
	scenario._pause.button("Resume").pressed.emit()
	scenario._loop.phase = TurnLoop.Phase.OPPONENT_TURN
	scenario._hud.show_turn_banner(false, 2.0)
	await _frames(40)
	await _shot(dir, "banner_red")
	scenario.queue_free()
	await _frames(3)
	var title: Control = load("res://scenes/app/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await _frames(10)
	title._options.pressed.emit()
	await _frames(5)
	await _shot(dir, "title_options")
	SafeArea.simulate_insets = false
	quit()
