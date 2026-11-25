extends SceneTree
## M6d smoke (not part of the regular suites): plays whole games in real time
## with the starter deck, animations on and the real AI, and fails on a
## softlock (no Goob landed for 20 s) or a stuck end screen. The player drags a
## random hand Goob into a winning column, else one that blocks the
## opponent's four, else a random legal column; "timeout" games never touch
## the screen so every player turn times out (2 s timer) and rolls.
## Run (headless is fine; takes a few minutes):
##   godot --headless -s res://tests/soak_m6d.gd

const SCENE := "res://scenes/scenario/scenario.tscn"
const STALL_MSEC := 20000
const GAME_MSEC := 240000
## [speed, mode] per game.
const GAMES := [
	[0, "tap"], [0, "tap"], [0, "tap"], [1, "tap"], [1, "tap"], [1, "tap"],
	[1, "timeout"], [0, "timeout"],
]

var _checks := 0
var _failures := 0
var _rng := RandomNumberGenerator.new()


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rng.randomize()
	var settings := root.get_node("Settings")
	var flow := root.get_node("GameFlow")
	settings.path = "user://test_settings.cfg"
	settings.reset()
	flow.fade_sec = 0.0
	root.size = Vector2i(1080, 1920)
	var results := {}
	for i in GAMES.size():
		var speed: int = GAMES[i][0]
		var mode: String = GAMES[i][1]
		settings.set_speed(speed)
		var label := "game %d (%s, %s)" % [i + 1, ["Normal", "Fast"][speed], mode]
		var result: int = await _play_game(label, mode)
		results[result] = results.get(result, 0) + 1
	settings.reset()
	settings.save_file()
	flow.fade_sec = flow.FADE_SEC
	print("\nresults (1 player win, 2 opponent win, 3 draw): ", results)
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _play_game(label: String, mode: String) -> int:
	var scenario: Control = load(SCENE).instantiate()
	if mode == "timeout":
		scenario.turn_seconds = 2.0
	root.add_child(scenario)
	current_scene = scenario
	var loop: TurnLoop = scenario._loop
	var start := Time.get_ticks_msec()
	var last_progress := start
	var last_count := -1
	var turns := 0
	while loop.result == TurnLoop.Result.NONE:
		var now := Time.get_ticks_msec()
		var count := _goobs_on_board(loop.board)
		if count != last_count:
			last_count = count
			last_progress = now
		if now - last_progress > STALL_MSEC or now - start > GAME_MSEC:
			_check(false, "%s: softlock (%d Goobs on the board, input %s)" % [label, count, scenario._input_enabled])
			scenario.queue_free()
			await process_frame
			return -1
		if mode == "tap" and scenario._input_enabled and not loop.player_deck.hand.is_empty():
			_play_random(scenario, loop)
			turns += 1
			await create_timer(0.3).timeout
		await process_frame
	# The end screen must come up with its button, and the button must leave.
	var deadline := Time.get_ticks_msec() + 20000
	var button: Button = scenario._end_screen.primary_button()
	while not button.is_visible_in_tree() and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(1.5).timeout # let the end-screen intro finish
	_check(button.is_visible_in_tree(), "%s: end button shows" % label)
	var result := loop.result
	scenario._end_screen.primary_pressed.emit()
	await process_frame
	await process_frame
	var expected := "CoinFlip" if result == TurnLoop.Result.DRAW else "Title"
	var landed: String = current_scene.name if current_scene else "-"
	_check(landed == expected, "%s: end button goes to %s (got %s)" % [label, expected, landed])
	print("%s: result %d after %d player taps, %.1f s" % [label, result, turns, (Time.get_ticks_msec() - start) / 1000.0])
	if current_scene:
		current_scene.free()
	current_scene = null
	if is_instance_valid(scenario):
		scenario.free()
	await process_frame
	return result


func _goobs_on_board(board: BoardState) -> int:
	var n := 0
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if board.get_owner(column, row) != BoardState.CellOwner.EMPTY:
				n += 1
	return n


## Drags a random hand Goob onto a winning, blocking or random legal column.
func _play_random(scenario: Control, loop: TurnLoop) -> void:
	var legal: Array[int] = []
	for column in BoardState.COLUMNS:
		if not loop.column_blocked(column): # full or Territorial-locked
			legal.append(column)
	if legal.is_empty():
		return
	var index := _rng.randi_range(0, loop.player_deck.hand.size() - 1)
	var column: int = legal[_rng.randi_range(0, legal.size() - 1)]
	var block := -1
	for c in legal:
		if _wins(loop.board, c, BoardState.CellOwner.PLAYER):
			block = -1
			column = c
			break
		if block == -1 and _wins(loop.board, c, BoardState.CellOwner.OPPONENT):
			block = c
	if block != -1:
		column = block
	scenario._last_tap_key = ""
	var hand: HandView = scenario.get_node("%PlayerHand")
	var start := hand.slot_center(index)
	var rect: Rect2 = scenario.column_hit_rect(column)
	var pos := Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.3)
	# Drag-only play (M6f): pick the Goob up, drag it over the column, let go.
	_touch(start, true)
	_drag(start + Vector2(0, -40))
	_drag(pos)
	_touch(pos, false)


func _wins(board: BoardState, column: int, side: BoardState.CellOwner) -> bool:
	var test := board.copy()
	test.drop(column, side)
	return test.find_winner() == side


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = pos
	root.push_input(ev, true)
