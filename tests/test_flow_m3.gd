extends SceneTree
## Headless test for M3 start flow: click starts from title, coin flip locks its
## choice and has no Continue button.
## Run: godot --headless -s res://tests/test_flow_m3.gd

const TITLE := "res://scripts/app/title.gd"
const COIN_FLIP := "res://scenes/ui/coin_flip.tscn"
const TITLE_SCENE := "res://scenes/app/title.tscn"

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
	var saved_first: bool = _flow().player_moves_first
	_test_click_is_press_start()
	await _test_title_click_starts_game()
	await _test_no_continue_button()
	await _test_flip_locks_choice()
	_flow().player_moves_first = saved_first
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## GameFlow is an autoload; its name is not a compile-time identifier in -s scripts.
func _flow() -> Node:
	return root.get_node("GameFlow")


func _mouse(button: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _touch(pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	return e


func _test_click_is_press_start() -> void:
	var title: GDScript = load(TITLE)
	_check(title.is_press_start(_touch(true)), "touch press starts")
	_check(not title.is_press_start(_touch(false)), "touch release does not start")
	# A desktop click reaches the title as an emulated touch; the raw click must
	# not count too, or Press Start fires twice.
	_check(not title.is_press_start(_mouse(MOUSE_BUTTON_LEFT, true)), "raw mouse press ignored")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	_check(title.is_press_start(enter), "Enter starts")


## Real tap through the viewport (push_input), not a direct call to is_press_start.
func _test_title_click_starts_game() -> void:
	var saved_size: Vector2i = root.size
	root.size = Vector2i(720, 1280)
	for pos in [Vector2(360, 640), Vector2(40, 40)]:
		var title: Control = load(TITLE_SCENE).instantiate()
		root.add_child(title)
		current_scene = title
		await process_frame
		await process_frame
		for pressed in [true, false]:
			var ev := _touch(pressed)
			ev.position = pos
			root.push_input(ev)
		for i in 5:
			await process_frame
		# change_scene_to_file frees the old scene and makes StrangeMan current.
		var started: bool = not is_instance_valid(title) and current_scene != null \
				and current_scene.name == "StrangeMan"
		_check(started, "tap at %s starts the game from title" % str(pos))
		if is_instance_valid(title):
			title.free()
		elif current_scene != null:
			current_scene.free()
		current_scene = null
		await process_frame
	root.size = saved_size


func _test_no_continue_button() -> void:
	var cf: Control = load(COIN_FLIP).instantiate()
	root.add_child(cf)
	await process_frame
	_check(cf.get_node_or_null("%ContinueButton") == null, "no ContinueButton")
	cf.free()


func _test_flip_locks_choice() -> void:
	var cf: Control = load(COIN_FLIP).instantiate()
	root.add_child(cf)
	await process_frame
	cf._on_flip_pressed()
	var hold: Timer = cf._hold_timer
	_check(not hold.is_stopped() and hold.time_left > 0.0, "hold timer is running after flip")
	_check(is_equal_approx(hold.wait_time, cf.RESULT_HOLD_SEC), "hold timer wait_time is RESULT_HOLD_SEC")
	_check(cf.RESULT_HOLD_SEC <= 3.0, "coin flip lasts no longer than 3 s (Sean, 2026-11-11)")
	_check(cf.get_node("%FlipButton").disabled, "flip disabled")
	_check(cf.get_node("%HeadsButton").disabled, "heads disabled")
	_check(cf.get_node("%TailsButton").disabled, "tails disabled")
	var first = _flow().player_moves_first
	_check(first is bool, "player_moves_first is bool")
	var text: String = cf.get_node("%ResultLabel").text
	_check(text.contains("You moves first") == first, "result text matches player_moves_first")
	cf.free() # before the hold timer can fire a scene change
