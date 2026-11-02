extends SceneTree
## Headless test for M3 start flow: click starts from title, coin flip locks its
## choice and has no Continue button.
## Run: godot --headless -s res://tests/test_flow_m3.gd

const TITLE := "res://scripts/app/title.gd"
const COIN_FLIP := "res://scenes/ui/coin_flip.tscn"

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


func _test_click_is_press_start() -> void:
	var title: GDScript = load(TITLE)
	_check(title.is_press_start(_mouse(MOUSE_BUTTON_LEFT, true)), "left press starts")
	_check(not title.is_press_start(_mouse(MOUSE_BUTTON_LEFT, false)), "left release does not start")
	_check(not title.is_press_start(_mouse(MOUSE_BUTTON_RIGHT, true)), "right press does not start")


func _test_no_continue_button() -> void:
	var cf: Control = load(COIN_FLIP).instantiate()
	root.add_child(cf)
	await process_frame
	_check(cf.get_node_or_null("Center/ContinueButton") == null, "no ContinueButton")
	cf.free()


func _test_flip_locks_choice() -> void:
	var cf: Control = load(COIN_FLIP).instantiate()
	root.add_child(cf)
	await process_frame
	cf._on_flip_pressed()
	_check(cf.get_node("Center/FlipButton").disabled, "flip disabled")
	_check(cf.get_node("Center/ChoiceRow/HeadsButton").disabled, "heads disabled")
	_check(cf.get_node("Center/ChoiceRow/TailsButton").disabled, "tails disabled")
	var first = _flow().player_moves_first
	_check(first is bool, "player_moves_first is bool")
	var text: String = cf.get_node("Center/ResultLabel").text
	_check(text.contains("You moves first") == first, "result text matches player_moves_first")
	cf.free() # before the hold timer can fire a scene change
