extends SceneTree
## Dev tool (Sean, 2026-11-28 lag report): plays scenarios with auto-play and
## real think delays and prints, per opponent turn, how long his AI call takes
## (what used to freeze one frame) and the longest frame while he thinks.
##   godot --headless -s res://tests/time_frames.gd [-- turns]

var _worst_frame_us := 0
var _last_us := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var want := int(args[0]) if args.size() > 0 else 40
	var settings := root.get_node("Settings")
	settings.path = "user://capture_settings.cfg"
	settings.reset()
	settings.turn_timer = false
	var flow := root.get_node("GameFlow")
	var turns := 0
	var rows: Array[String] = []
	var worst_sync := 0
	var worst_gap := 0
	var game := 0
	while turns < want and game < 20:
		game += 1
		flow.player_moves_first = game % 2 == 0
		flow.rolled_decks = {}
		flow.autoplay = true
		var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
		scenario.animate_drops = false
		root.add_child(scenario)
		current_scene = scenario
		var was_opp := false
		var deadline := Time.get_ticks_msec() + 60000
		while scenario._loop.phase != TurnLoop.Phase.OVER and Time.get_ticks_msec() < deadline and turns < want:
			var opp: bool = scenario._loop.phase == TurnLoop.Phase.OPPONENT_TURN
			if opp and not was_opp:
				var deck: Deck = scenario._loop.opponent_deck
				var t0 := Time.get_ticks_usec()
				OpponentAI.choose_move(scenario._loop.board, deck.hand, deck.draw_pile.size(), RandomNumberGenerator.new(), scenario._loop.cell_goobs(), scenario._loop.destroyed_piles(), scenario._loop.sim_state())
				var sync_us := Time.get_ticks_usec() - t0
				_worst_frame_us = 0
				_last_us = Time.get_ticks_usec()
				worst_sync = maxi(worst_sync, sync_us)
				rows.append("sync %d" % sync_us)
			if not opp and was_opp:
				turns += 1
				worst_gap = maxi(worst_gap, _worst_frame_us)
				rows[-1] += " gap %d" % _worst_frame_us
			was_opp = opp
			await process_frame
			var now := Time.get_ticks_usec()
			_worst_frame_us = maxi(_worst_frame_us, now - _last_us)
			_last_us = now
		scenario.queue_free()
		await process_frame
	flow.autoplay = false
	print("opponent turns %d: worst AI call %.0f ms (old: one frozen frame), worst frame in play %.0f ms" % [turns, worst_sync / 1000.0, worst_gap / 1000.0])
	quit()
