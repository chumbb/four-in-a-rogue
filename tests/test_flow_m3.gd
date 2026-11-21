extends SceneTree
## Headless test for the start flow (M3, rebuilt in M6a): title Press Start,
## GameFlow fades, Strange Man pages, swipe coin flip.
## Run: godot --headless -s res://tests/test_flow_m3.gd

const TITLE := "res://scripts/app/title.gd"
const TITLE_SCENE := "res://scenes/app/title.tscn"
const STRANGE_MAN := "res://scenes/app/strange_man.tscn"
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
	var saved_size: Vector2i = root.size
	root.size = Vector2i(1080, 1920) # Sean's monitor: 4× pixel scale
	_flow().fade_sec = 0.0
	_test_click_is_press_start()
	await _test_title_click_starts_game()
	await _test_title_buttons_do_not_start()
	await _test_fade()
	await _test_strange_man_pages()
	await _test_strange_man_skip()
	await _test_coin_strength()
	await _test_coin_toss()
	_flow().player_moves_first = saved_first
	_flow().fade_sec = _flow().FADE_SEC
	root.size = saved_size
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## GameFlow is an autoload; its name is not a compile-time identifier in -s scripts.
func _flow() -> Node:
	return root.get_node("GameFlow")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mouse(button: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _touch(pressed: bool, pos := Vector2.ZERO) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = pos
	return e


func _add(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


## Frees whatever is current (the scene or the one it changed to).
func _clear(scene) -> void:
	if is_instance_valid(scene):
		scene.free()
	elif current_scene != null:
		current_scene.free()
	current_scene = null
	await process_frame


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
	for pos in [Vector2(360, 640), Vector2(40, 40)]:
		var title := _add(TITLE_SCENE)
		await _frames(2)
		root.push_input(_touch(true, pos), true) # viewport (720-base) coordinates
		root.push_input(_touch(false, pos), true)
		await _frames(5)
		# change_scene_to_file frees the old scene and makes StrangeMan current.
		var started: bool = not is_instance_valid(title) and current_scene != null \
				and current_scene.name == "StrangeMan"
		_check(started, "tap at %s starts the game from title" % str(pos))
		await _clear(title)


func _test_title_buttons_do_not_start() -> void:
	var title := _add(TITLE_SCENE)
	await _frames(3)
	var options: Button = title._options
	_check(options.get_global_rect().size.y >= 96.0 - 0.5, "Options button ≥ 96 px tall (got %s)" % options.get_global_rect().size)
	var on_button := options.get_global_rect().get_center()
	root.push_input(_touch(true, on_button), true)
	root.push_input(_touch(false, on_button), true)
	await _frames(5)
	_check(is_instance_valid(title) and current_scene == title, "tap on Options does not start")
	_check(title._quit.visible == OS.has_feature("pc"), "Quit only on desktop builds")
	await _clear(title)


func _test_fade() -> void:
	var flow := _flow()
	flow.fade_sec = 0.05
	var title := _add(TITLE_SCENE)
	await _frames(2)
	flow.go_to(flow.SceneKey.STRANGE_MAN)
	_check(flow.is_fading(), "go_to fades")
	_check(title.process_mode == Node.PROCESS_MODE_DISABLED, "old screen frozen under the fade")
	_check(current_scene == title, "scene not changed before the cover is opaque")
	var waited := 0
	while flow.is_fading() and waited < 120:
		await process_frame
		waited += 1
	_check(not flow.is_fading(), "fade finishes")
	_check(current_scene != null and current_scene.name == "StrangeMan", "fade ends on the new scene")
	await _clear(title)
	flow.fade_sec = 0.0
	_check(flow.FADE_SEC <= 0.35, "fades ~0.3 s")


func _test_strange_man_pages() -> void:
	var sm := _add(STRANGE_MAN)
	await _frames(2)
	var pages: Array[String] = sm.PAGES
	_check(pages.size() == 5, "5 pages")
	_check(" ".join(pages) == sm.OPENING_DIALOGUE, "pages = the locked text, one per sentence")
	_check(sm.page == 0 and sm.is_typing(), "page 1 types")
	_check(sm._text.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING, "typing wraps the full sentence (no mid-word jumps)")
	# Line breaks while typing match the finished page (long page 3, multi-line).
	sm._text.text = pages[2]
	sm._text.visible_characters = -1
	var full_lines: int = sm._text.get_line_count()
	sm._text.visible_characters = 30
	_check(full_lines > 1 and sm._text.get_line_count() == full_lines, "half-typed page keeps its final line layout (%d lines)" % full_lines)
	sm._text.text = pages[0]
	sm._text.visible_characters = int(sm._shown)
	_check(not sm._goobs.blue.visible and not sm._goobs.red.visible, "Goobs hidden on page 1")
	sm.advance()
	_check(sm.page == 0 and not sm.is_typing(), "first tap finishes typing")
	sm.advance()
	_check(sm.page == 1, "next tap turns the page")
	_check(sm._goobs.blue.visible and sm._goobs.red.visible, "Goobs pop in on 'This is a land of Goobs.'")
	for i in 3:
		sm.advance()
		sm.advance()
	_check(sm.page == 4, "reaches page 5")
	sm.advance()
	sm.advance()
	_check(sm._done, "tap after the last page finishes")
	await _clear(sm) # before the outro can change scene


func _test_strange_man_skip() -> void:
	var sm := _add(STRANGE_MAN)
	await _frames(2)
	var skip: Button = sm._skip
	_check(skip.get_global_rect().size.y >= 96.0 - 0.5, "Skip ≥ 96 px tall")
	skip.pressed.emit()
	_check(sm._done, "Skip finishes the intro")
	var waited := 0
	while is_instance_valid(sm) and waited < 120:
		await process_frame
		waited += 1
	_check(current_scene != null and current_scene.name == "CoinFlip", "Skip → forest fade-in → coin flip")
	await _clear(sm)


func _test_coin_strength() -> void:
	var cf: GDScript = load("res://scripts/ui/coin_flip.gd")
	var tap: float = cf.strength_for(Vector2(300, 600), Vector2(302, 598), false)
	var short: float = cf.strength_for(Vector2(300, 600), Vector2(300, 450), false)
	var long: float = cf.strength_for(Vector2(300, 900), Vector2(300, 300), false)
	var on_coin: float = cf.strength_for(Vector2(300, 600), Vector2(300, 450), true)
	var down: float = cf.strength_for(Vector2(300, 400), Vector2(300, 700), false)
	_check(is_equal_approx(tap, cf.TAP_STRENGTH), "tap = gentle toss")
	_check(is_equal_approx(down, cf.TAP_STRENGTH), "swipe down = gentle toss")
	_check(short > tap and long > short, "longer swipe = stronger toss")
	_check(on_coin > short, "starting on the coin = stronger toss")
	_check(long <= 1.0 and on_coin <= 1.0, "strength capped at 1")


func _test_coin_toss() -> void:
	var cf_script: GDScript = load("res://scripts/ui/coin_flip.gd")
	_check(cf_script.TOTAL_SEC <= 4.0, "release → scenario ~4 s (Sean 2026-11-20; got %s)" % cf_script.TOTAL_SEC)
	var outcomes := {}
	for seed in 12:
		for strength in [0.15, 1.0]:
			var cf := _add(COIN_FLIP)
			await _frames(2)
			_check(cf.find_children("*", "Button", true, false).is_empty(), "no buttons on the coin flip")
			cf.rng.seed = seed
			cf.toss(strength)
			var first: bool = cf.player_first
			outcomes[first] = true
			_check(_flow().player_moves_first == first, "GameFlow.player_moves_first = coin result")
			_check((cf.half_turns % 2 == 0) == first, "even half turns land blue (player)")
			var landed: Texture2D = cf.frame_at(1.0, cf.half_turns)
			_check(landed.resource_path.contains("blue" if first else "red"), "landed face = result colour")
			var turns: int = cf.half_turns
			cf.toss(0.5)
			_check(cf.half_turns == turns, "second toss ignored")
			cf.process_mode = Node.PROCESS_MODE_DISABLED
			await _clear(cf)
	_check(outcomes.size() == 2, "both colours can win")
	# Stronger toss = more spins and a higher arc.
	var gentle := _add(COIN_FLIP)
	await _frames(2)
	gentle.rng.seed = 1
	gentle.toss(0.15)
	var gentle_turns: int = gentle.half_turns
	var gentle_arc: float = gentle.arc_px
	gentle.process_mode = Node.PROCESS_MODE_DISABLED
	await _clear(gentle)
	var strong := _add(COIN_FLIP)
	await _frames(2)
	strong.rng.seed = 1
	strong.toss(1.0)
	_check(strong.half_turns > gentle_turns and strong.arc_px > gentle_arc, "strong toss spins more, arcs higher")
	strong.process_mode = Node.PROCESS_MODE_DISABLED
	await _clear(strong)
