extends SceneTree
## Dev tool: screenshots of the flow screens (not a test). Run windowed:
##   godot -s res://tests/capture_flow.gd -- <out_dir>

func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join("%s_%dx%d.png" % [name, img.get_width(), img.get_height()]))
	print("saved ", name, " ", img.get_size())


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(args[1]), int(args[2])) if args.size() > 2 else Vector2i(540, 960)
	for i in 10:
		await process_frame
	if args.size() > 3:
		SafeArea.simulate_insets = true
	var flow := root.get_node("GameFlow")
	flow.fade_sec = 0.0
	for key in [["title", "res://scenes/app/title.tscn"], ["strange_man", "res://scenes/app/strange_man.tscn"], ["coin", "res://scenes/ui/coin_flip.tscn"]]:
		var scene: Node = load(key[1]).instantiate()
		root.add_child(scene)
		current_scene = scene
		for i in 110:
			await process_frame
		if key[0] == "strange_man":
			scene.advance() # finish typing page 1
			scene.advance() # page 2: Goobs pop in
			for i in 60:
				await process_frame
			scene.advance()
			for i in 5:
				await process_frame
		await _shot(dir, key[0])
		if key[0] == "coin":
			for i in 20:
				await process_frame
			await _shot(dir, "coin_b")
			scene.toss(1.0)
			for i in 18:
				await process_frame
			await _shot(dir, "coin_air")
			for i in 50:
				await process_frame
			await _shot(dir, "coin_result")
			scene.process_mode = Node.PROCESS_MODE_DISABLED
		scene.queue_free()
		await process_frame
	quit()
