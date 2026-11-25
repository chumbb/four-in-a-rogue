extends SceneTree
## Dev tool (M6g, not a test): plays whole scenarios with rolled decks (you =
## random legal plays, the opponent = the real AI, no animations) and writes
## every Telemetry event they produce to a JSONL file, without sending
## anything. Feed it to the stats tool to check the report end to end:
##   godot --headless -s res://tests/telemetry_dump.gd -- <out.jsonl> [games]
##   python tools/telemetry/goob_stats.py --file <out.jsonl> --min-pair 2

const SCENE := "res://scenes/scenario/scenario.tscn"
const GAME_MSEC := 60000

var _out: FileAccess
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = FileAccess.open(args[0], FileAccess.WRITE)
	var games := int(args[1]) if args.size() > 1 else 20
	_rng.randomize()
	var settings := root.get_node("Settings")
	settings.path = "user://telemetry_dump_settings.cfg"
	settings.reset()
	var flow := root.get_node("GameFlow")
	flow.fade_sec = 0.0
	var t := root.get_node("Telemetry")
	t.queue_path = "user://telemetry_dump_queue.jsonl"
	t.queue.clear()
	t.force_enabled = true
	t.sender = func(batch: Array) -> void:
		for entry in batch:
			_out.store_line(JSON.stringify(entry))
		t.sent.call_deferred(true)
	var ends := 0
	for i in games:
		flow.rolled_decks = {}
		flow.player_moves_first = _rng.randi() % 2 == 0
		ends += await _play_game()
	t.flush()
	for i in 200:
		if t.queue.is_empty():
			break
		await process_frame
		t.flush()
	_out.close()
	settings.reset()
	DirAccess.remove_absolute("user://telemetry_dump_settings.cfg")
	print("%d games, %d scenario_end events written to %s" % [games, ends, args[0]])
	quit()


func _play_game() -> int:
	var scenario: Control = load(SCENE).instantiate()
	scenario.animate_drops = false
	scenario.opponent_delay_sec = 0.0
	scenario.timeout_reveal_sec = 0.0
	root.add_child(scenario)
	var loop: TurnLoop = scenario._loop
	var start := Time.get_ticks_msec()
	while loop.result == TurnLoop.Result.NONE and Time.get_ticks_msec() - start < GAME_MSEC:
		await process_frame
		if loop.phase != TurnLoop.Phase.PLAYER_TURN or not scenario._input_enabled:
			continue
		var hand := loop.player_deck.hand
		if hand.is_empty():
			continue
		var legal: Array[int] = []
		for c in BoardState.COLUMNS:
			if loop.can_play(c):
				legal.append(c)
		if not legal.is_empty():
			scenario.try_drop(legal[_rng.randi_range(0, legal.size() - 1)], _rng.randi_range(0, hand.size() - 1))
	for i in 10:
		await process_frame
	var ended := 1 if scenario._stats_sent else 0
	scenario.queue_free()
	await process_frame
	return ended
