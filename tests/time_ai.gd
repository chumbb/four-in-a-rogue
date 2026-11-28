extends SceneTree
## Dev tool: OpponentAI.choose_move time per move on the rolled rarity decks.
## godot --headless -s res://tests/time_ai.gd

func _initialize() -> void:
	var times: Array[int] = []
	var worst := {}
	for game in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + game
		var t := TurnLoop.new()
		t.start(game % 2 == 0, rng)
		var turns := 0
		while t.phase != TurnLoop.Phase.OVER and turns < 200:
			turns += 1
			var mirrored := t.current_side() == BoardState.CellOwner.PLAYER
			var board := t.board.mirrored() if mirrored else t.board
			var hand := t.current_deck().hand
			var t0 := Time.get_ticks_usec()
			var move := OpponentAI.choose_move(board, hand, t.current_deck().draw_pile.size(), rng, t.cell_goobs(), t.destroyed_piles(mirrored), t.sim_state(mirrored))
			var us := Time.get_ticks_usec() - t0
			times.append(us)
			if us > worst.get("us", 0):
				var ids := []
				for g in hand:
					ids.append(g.id)
				worst = {"us": us, "game": game, "turn": turns, "hand": ids, "filled": 42 - _empty(t.board)}
			if move["column"] < 0 or t.play(move["column"], move["hand_index"]) < 0:
				break
	times.sort()
	var n := times.size()
	print("moves %d  median %.1f ms  p90 %.1f ms  p99 %.1f ms  max %.1f ms" % [n, times[n / 2] / 1000.0, times[n * 9 / 10] / 1000.0, times[n * 99 / 100] / 1000.0, times[-1] / 1000.0])
	print("worst: ", worst)
	quit()


func _empty(b: BoardState) -> int:
	var n := 0
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if b.is_empty(c, r):
				n += 1
	return n
