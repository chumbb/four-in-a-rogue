extends SceneTree
## Dev tool (not a test): real-time run of the start flow with fades, saving
## frames along the way. Run windowed:
##   godot -s res://tests/capture_e2e.gd -- <out_dir>

var _dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("e2e_%s.png" % name))
	print("saved ", name, " scene=", current_scene.name if current_scene else "-")


func _tap(pos: Vector2, up := Vector2.INF) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = pos
	root.push_input(e, true)
	var r := InputEventScreenTouch.new()
	r.position = pos if up == Vector2.INF else up
	root.push_input(r, true)


func _run() -> void:
	_dir = OS.get_cmdline_user_args()[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(540, 960)
	change_scene_to_file("res://scenes/app/boot.tscn")
	await _wait(1.2)
	await _shot("1_title")
	_tap(Vector2(360, 640))
	await _wait(0.3)
	await _shot("2_black")
	await _wait(1.0)
	_tap(Vector2(360, 640)) # finish typing
	_tap(Vector2(360, 640)) # page 2
	await _wait(1.0)
	await _shot("3_strange_man")
	var skip: Button = current_scene._skip
	skip.pressed.emit()
	await _wait(0.6)
	await _shot("4_forest_in")
	await _wait(2.2)
	await _shot("5_coin")
	_tap(Vector2(360, 900), Vector2(360, 300)) # swipe up
	await _wait(0.3)
	await _shot("6_toss")
	await _wait(1.8)
	await _shot("7_banner")
	await _wait(1.2)
	await _shot("8_board_fade")
	await _wait(1.2)
	await _shot("9_scenario")
	quit()
