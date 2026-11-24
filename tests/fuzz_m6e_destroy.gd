extends SceneTree
## Headless fuzz for the M6e destroy Goobs: AI vs AI games with decks full of
## destroy Goobs plus the move Goobs they chain with (Lopsided, Bouncy,
## Slippery, Springy) and Popular. Checks every play keeps the board gap-free
## with a definition per Goob, leaves no doomed Goob behind, keeps the armed
## state on Spiteful / Smouldering only, and every game ends.
## Run: godot --headless -s res://tests/fuzz_m6e_destroy.gd

const GAMES := 300

var _failures := 0


func _initialize() -> void:
	var deck: Array[GoobDefinition] = []
	for goob in GoobRoster.specials(GoobDefinition.Category.DESTROY):
		deck.append(goob)
		deck.append(goob)
	for id in ["lopsided", "bouncy", "slippery", "springy", "popular"]:
		deck.append(load("res://resources/goobs/%s_goob.tres" % id))
	deck.append(TurnLoop.VANILLA)
	deck.append(TurnLoop.VANILLA)
	var started := Time.get_ticks_msec()
	var plays := 0
	var turn_starts := 0
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
			if not t.turn_start_steps.is_empty():
				turn_starts += 1
			_check_board(t, game)
		if t.phase != TurnLoop.Phase.OVER:
			_fail("game %d did not end (%d turns)" % [game, turns])
	print("%d games, %d plays, %d turn starts with effects, %d ms, %d failures" % [GAMES, plays, turn_starts, Time.get_ticks_msec() - started, _failures])
	quit(1 if _failures > 0 else 0)


func _check_board(t: TurnLoop, game: int) -> void:
	for c in BoardState.COLUMNS:
		var gap := false
		for r in BoardState.ROWS:
			var goob := t.goob_at(c, r)
			if t.board.is_empty(c, r):
				gap = true
				if goob != null:
					_fail("game %d: stale definition at (%d,%d)" % [game, c, r])
				continue
			if gap:
				_fail("game %d: floating Goob at (%d,%d)" % [game, c, r])
			if goob == null:
				_fail("game %d: no definition at (%d,%d)" % [game, c, r])
				continue
			if goob.has_meta(&"doomed"):
				_fail("game %d: doomed Goob left at (%d,%d)" % [game, c, r])
			var kind := goob.effect_type
			if goob.has_meta(&"armed_by") and kind != GoobDefinition.EffectType.DESTROY_LANDER and kind != GoobDefinition.EffectType.DESTROY_LATER:
				_fail("game %d: armed %s at (%d,%d)" % [game, goob.id, c, r])
	for side in [BoardState.CellOwner.PLAYER, BoardState.CellOwner.OPPONENT]:
		for goob in t.deck_of(side).destroyed_pile:
			if goob.has_meta(&"base"):
				_fail("game %d: a marked copy in the destroyed pile" % game)


func _fail(msg: String) -> void:
	_failures += 1
	if _failures < 20:
		printerr("FAIL: ", msg)
