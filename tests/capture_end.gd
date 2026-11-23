extends SceneTree
## Dev tool: screenshots of the end screen for win / lose / draw (not a test).
##   godot -s res://tests/capture_end.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1080, 1920)
	root.get_node("Settings").path = "user://capture_settings.cfg"
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	scenario.animate_drops = false
	root.add_child(scenario)
	current_scene = scenario
	for kind in [&"win", &"lose", &"draw"]:
		await create_timer(0.3).timeout
		scenario._end_overlay.visible = true
		scenario._end_screen.set_result(kind)
		scenario._end_screen.play_intro(false)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("end_%s.png" % kind))
		print("saved ", kind)
	quit()
