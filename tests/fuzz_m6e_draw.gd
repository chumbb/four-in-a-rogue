extends SceneTree
## Headless fuzz for the M6e draw Goobs: AI vs AI games with decks full of
## draw Goobs (Greedy, Jinxing, Generous, Plentiful) plus the discard / destroy
## Goobs that draw, discard or move Goobs between piles. Checks every play keeps the board gap-free with a
## definition per Goob, every side keeps all 21 of its Goobs (hand + deck +
## discard pile + destroyed pile + board), the hand cap holds, no marked copy
## reaches a pile, and every game ends.
## Run: godot --headless -s res://tests/fuzz_m6e_draw.gd

const GAMES := 100
const DECK_SIZE := 21

var _failures := 0


func _initialize() -> void:
	var deck: Array[GoobDefinition] = []
	for goob in GoobRoster.specials(GoobDefinition.Category.DRAW):
		deck.append(goob)
		deck.append(goob)
	for id in ["fickle", "fickle", "reckless", "reckless", "distracting", "distracting", "defiant", "fat", "volatile", "occult"]:
		deck.append(load("res://resources/goobs/%s_goob.tres" % id))
	for i in 3:
		deck.append(TurnLoop.VANILLA)
	if deck.size() != DECK_SIZE:
		_fail("deck has %d Goobs" % deck.size())
	var started := Time.get_ticks_msec()
	var plays := 0
	var echoes := 0
	var jinxed := 0
	for game in GAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = game
		var t := TurnLoop.new()
		t.start(game % 2 == 0, rng, deck)
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
			plays += 1
			for step in t.effect_steps + t.turn_draw_steps:
				if step["kind"] == GoobDefinition.EffectType.DRAW_ECHO and step.has("drawn"):
					echoes += step["drawn"].size()
			if t.last_jinx_lost > 0:
				jinxed += 1
			_check(t, game)
		if t.phase != TurnLoop.Phase.OVER:
			_fail("game %d did not end (%d turns)" % [game, turns])
	print("%d games, %d plays, %d Plentiful draws, %d jinxed draws, %d ms, %d failures" % [GAMES, plays, echoes, jinxed, Time.get_ticks_msec() - started, _failures])
	quit(1 if _failures > 0 else 0)


func _check(t: TurnLoop, game: int) -> void:
	var on_board := {BoardState.CellOwner.PLAYER: 0, BoardState.CellOwner.OPPONENT: 0}
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
			on_board[t.board.get_owner(c, r)] += 1
	for side: BoardState.CellOwner in on_board:
		var deck := t.deck_of(side)
		if deck.hand.size() > Deck.HAND_MAX:
			_fail("game %d: hand of %d" % [game, deck.hand.size()])
		var total: int = deck.hand.size() + deck.draw_pile.size() + deck.discard_pile.size() + deck.destroyed_pile.size() + on_board[side]
		if total != DECK_SIZE:
			_fail("game %d: side %d has %d Goobs" % [game, side, total])
		for pile in [deck.discard_pile, deck.destroyed_pile]:
			for goob: GoobDefinition in pile:
				if goob.has_meta(&"base"):
					_fail("game %d: a marked copy in a pile" % game)


func _fail(msg: String) -> void:
	_failures += 1
	if _failures < 20:
		printerr("FAIL: ", msg)
