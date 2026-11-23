extends SceneTree
## Headless fuzz for the M6e move Goobs: AI vs AI games with decks full of
## move Goobs (plus Fat for destroy chains). Checks every play keeps the board
## gap-free with a definition per Goob, and every game ends.
## Run: godot --headless -s res://tests/fuzz_m6e_move.gd

const GAMES := 300

var _failures := 0


func _initialize() -> void:
	var deck: Array[GoobDefinition] = []
	for goob in GoobRoster.specials(GoobDefinition.Category.MOVE):
		deck.append(goob)
		deck.append(goob)
	deck.append(load("res://resources/goobs/fat_goob.tres"))
	deck.append(load("res://resources/goobs/fat_goob.tres"))
	deck.append(TurnLoop.VANILLA)
	var started := Time.get_ticks_msec()
	var plays := 0
	for game in GAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = game
		var t := TurnLoop.new()
		t.start(game % 2 == 0, rng, deck)
		var turns := 0
		while t.phase != TurnLoop.Phase.OVER and turns < 200:
			turns += 1
			var side := t.current_side()
			var board := t.board if side == BoardState.CellOwner.OPPONENT else t.board.mirrored()
			var hand := t.current_deck().hand
			var move := OpponentAI.choose_move(board, hand, t.current_deck().draw_pile.size(), rng, t.cell_goobs())
			if move["column"] < 0:
				break
			if t.play(move["column"], move["hand_index"]) < 0:
				_fail("game %d: legal AI move refused" % game)
				break
			plays += 1
			_check_board(t, game)
		if t.phase != TurnLoop.Phase.OVER:
			_fail("game %d did not end (%d turns)" % [game, turns])
	print("%d games, %d plays, %d ms, %d failures" % [GAMES, plays, Time.get_ticks_msec() - started, _failures])
	quit(1 if _failures > 0 else 0)


func _check_board(t: TurnLoop, game: int) -> void:
	for c in BoardState.COLUMNS:
		var gap := false
		for r in BoardState.ROWS:
			var empty := t.board.is_empty(c, r)
			if empty:
				gap = true
				if t.goob_at(c, r) != null:
					_fail("game %d: stale definition at (%d,%d)" % [game, c, r])
			else:
				if gap:
					_fail("game %d: floating Goob at (%d,%d)" % [game, c, r])
				if t.goob_at(c, r) == null:
					_fail("game %d: no definition at (%d,%d)" % [game, c, r])


func _fail(msg: String) -> void:
	_failures += 1
	if _failures < 20:
		printerr("FAIL: ", msg)
