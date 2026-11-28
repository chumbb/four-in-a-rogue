extends SceneTree
## AI vs AI games on the rarity starting decks (Sean, 2026-11-27): rolled the
## way a real scenario rolls them (DeckBuilder.roll_pair). Fails on a refused
## legal move or a game that doesn't end; prints wins per decklist (a rough
## look only; the balance sim is M7.5).
## godot --headless -s res://tests/fuzz_decklists.gd

const GAMES := 200

var _failures := 0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var tally := {} ## name -> [wins, games]
	var draws := 0
	for game in GAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + game
		var t := TurnLoop.new()
		t.start(game % 2 == 0, rng)
		var turns := 0
		while t.phase != TurnLoop.Phase.OVER and turns < 200:
			turns += 1
			var side := t.current_side()
			var mirrored := side == BoardState.CellOwner.PLAYER
			var board := t.board.mirrored() if mirrored else t.board
			var hand := t.current_deck().hand
			var move := OpponentAI.choose_move(board, hand, t.current_deck().draw_pile.size(), rng, t.cell_goobs(), t.destroyed_piles(mirrored), t.sim_state(mirrored))
			if move["column"] < 0:
				break
			if t.play(move["column"], move["hand_index"]) < 0:
				_fail("game %d: legal AI move refused" % game)
				break
		if t.phase != TurnLoop.Phase.OVER:
			_fail("game %d did not end (%d turns)" % [game, turns])
			continue
		var names := {BoardState.CellOwner.PLAYER: t.player_deck_name, BoardState.CellOwner.OPPONENT: t.opponent_deck_name}
		var winner := BoardState.CellOwner.EMPTY
		if t.result == TurnLoop.Result.PLAYER_WIN:
			winner = BoardState.CellOwner.PLAYER
		elif t.result == TurnLoop.Result.OPPONENT_WIN:
			winner = BoardState.CellOwner.OPPONENT
		else:
			draws += 1
		for s in names:
			var row: Array = tally.get(names[s], [0, 0])
			row[1] += 1
			if s == winner:
				row[0] += 1
			tally[names[s]] = row
	for deck_name in tally:
		print("  %-20s %3d wins / %3d games" % [deck_name, tally[deck_name][0], tally[deck_name][1]])
	print("%d games, %d draws, %d ms, %d failures" % [GAMES, draws, Time.get_ticks_msec() - started, _failures])
	quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
