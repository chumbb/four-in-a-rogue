extends SceneTree
## Headless Telemetry + play-data bookkeeping tests (M6g).
## Run: godot --headless -s res://tests/test_telemetry.gd
## Exits 0 on pass, 1 on any failure. Never sends anything: the editor binary
## counts as "not exported", and the forced cases use a fake sender.

const QUEUE_PATH := "user://test_telemetry_queue.jsonl"

var _failures := 0
var _checks := 0
var _batches: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	settings.path = "user://test_telemetry_settings.cfg"
	settings.reset()
	var t: Node = root.get_node("Telemetry")
	t.queue_path = QUEUE_PATH
	t.queue.clear()

	_test_off_in_editor(t)
	_test_batches(t)
	_test_failed_send_is_kept(t)
	_test_cap(t)
	_test_diagnostics_off(t, settings)
	_test_perf(t)
	_test_uuid(t)
	_test_deck_held_turns()
	_test_turn_loop_turns()

	settings.reset()
	DirAccess.remove_absolute(QUEUE_PATH)
	DirAccess.remove_absolute("user://test_telemetry_settings.cfg")
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", msg)


func _fake_send(batch: Array) -> void:
	_batches.append(batch)


func _reset(t: Node) -> void:
	t.queue.clear()
	t.set("_sending", 0)
	_batches.clear()
	t.force_enabled = true
	t.sender = _fake_send


func _test_off_in_editor(t: Node) -> void:
	t.force_enabled = false
	t.queue.clear()
	_check(not t.posthog_enabled(), "editor runs never send")
	_check(not t.sentry_allowed(), "Sentry never starts from the editor")
	t.track(&"goob_played", {"goob": "vanilla"})
	_check(t.queue.is_empty(), "nothing queued while off")


func _test_batches(t: Node) -> void:
	_reset(t)
	for i in 25:
		t.track(&"goob_played", {"n": i})
	_check(_batches.size() == 1 and _batches[0].size() == 20, "20 events make one batch")
	var first: Dictionary = _batches[0][0]
	_check(first["event"] == "goob_played" and first["properties"]["n"] == 0, "oldest first, props kept")
	_check(first["properties"]["distinct_id"] == t.install_id and not t.install_id.is_empty(), "install id on every event")
	_check(first["properties"]["$process_person_profile"] == false, "anonymous events")
	_check(str(first["timestamp"]).ends_with("Z"), "UTC timestamp")
	t.sent(true)
	_check(t.queue.size() == 5, "sent batch leaves the queue (%d left)" % t.queue.size())
	t.flush()
	_check(_batches.size() == 2 and _batches[1].size() == 5, "flush sends the rest")
	t.sent(true)
	_check(t.queue.is_empty(), "queue empty after both sends")


func _test_failed_send_is_kept(t: Node) -> void:
	_reset(t)
	for i in 3:
		t.track(&"screen", {"n": i})
	t.flush()
	t.sent(false)
	_check(t.queue.size() == 3, "a failed send keeps its events")
	_check(FileAccess.file_exists(QUEUE_PATH), "and saves them to disk")
	t.queue.clear()
	t.call("_load_queue")
	_check(t.queue.size() == 3 and t.queue[2]["properties"]["n"] == 2, "the next launch loads them back in order")
	t.queue.clear()
	t.save_queue()
	_check(not FileAccess.file_exists(QUEUE_PATH), "an empty queue leaves no file")


func _test_cap(t: Node) -> void:
	_reset(t)
	t.sender = func(_batch: Array) -> void: pass # offline: never completes
	for i in t.QUEUE_CAP + 100:
		t.track(&"screen", {"n": i})
	_check(t.queue.size() == t.QUEUE_CAP, "queue capped at %d (%d)" % [t.QUEUE_CAP, t.queue.size()])
	_check(t.queue[t.queue.size() - 1]["properties"]["n"] == t.QUEUE_CAP + 99, "newest kept, oldest dropped")
	_reset(t)


func _test_diagnostics_off(t: Node, settings: Node) -> void:
	_reset(t)
	t.force_enabled = false
	t.sender = _fake_send
	settings.set_diagnostics(false)
	_check(not t.posthog_enabled(), "Send diagnostics Off = no events")
	t.track(&"screen")
	_check(t.queue.is_empty(), "nothing queued with diagnostics Off")
	settings.set_diagnostics(true)
	_check(settings.diagnostics, "toggle back On")


func _test_perf(t: Node) -> void:
	t.perf_begin()
	_check(t.perf_end().is_empty(), "no frames = empty sample")
	t.perf_begin()
	t.set("_frame_sec", PackedFloat32Array([1.0 / 60.0, 1.0 / 60.0, 1.0 / 20.0]))
	var perf: Dictionary = t.perf_end()
	_check(perf["frames"] == 3 and perf["slow_frames"] == 1, "one hitch counted")
	_check(perf["worst_frame_ms"] == 50.0, "worst frame 50 ms (%s)" % perf["worst_frame_ms"])


func _test_uuid(t: Node) -> void:
	var id: String = t.new_uuid()
	_check(id.length() == 36 and id[14] == "4" and id.count("-") == 4, "UUID v4 shape: %s" % id)
	_check(t.new_uuid() != id, "UUIDs differ")


func _test_deck_held_turns() -> void:
	var vanilla: GoobDefinition = TurnLoop.VANILLA
	var goobs: Array[GoobDefinition] = []
	for i in 6:
		goobs.append(vanilla)
	var deck := Deck.shuffled(goobs, RandomNumberGenerator.new())
	deck.draw(2) # starting hand, before turn 1
	deck.turns = 1
	_check(deck.held_turns(0) == 0 and deck.held_turns(1) == 0, "starting hand counts as drawn on turn 1")
	deck.turns = 3
	deck.draw(1)
	_check(deck.held_turns(0) == 2 and deck.held_turns(2) == 0, "held 2 turns vs drawn this turn")
	deck.take(0)
	_check(deck.hand_drawn_at.size() == deck.hand.size() and deck.held_turns(1) == 0, "take keeps the lists in step")
	deck.add(vanilla)
	_check(deck.held_turns(deck.hand.size() - 1) == 0, "add = drawn this turn")
	deck.hand = [vanilla] # an AI simulation's hand
	_check(deck.held_turns(0) == -1, "unknown when out of step")


func _test_turn_loop_turns() -> void:
	var loop := TurnLoop.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	loop.start(true, rng)
	_check(loop.player_deck.turns == 1 and loop.opponent_deck.turns == 0, "first turn counted for the first side")
	_check(loop.player_deck.held_turns(loop.player_deck.hand.size() - 1) == 0, "the turn draw is held 0")
	loop.play(3, 0)
	_check(loop.opponent_deck.turns == 1, "the opponent's turn counted")
	_check(loop.player_deck.hand_drawn_at.size() == loop.player_deck.hand.size(), "hand and drawn turns stay in step")
