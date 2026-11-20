extends SceneTree
## Headless TurnLoop tests.
## Run: godot --headless -s res://tests/test_turn_loop.gd
## Exits 0 on pass, 1 on any failure.

const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT
const E := BoardState.CellOwner.EMPTY

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_start_player_first()
	_test_start_opponent_first()
	_test_alternates()
	_test_full_column_keeps_turn()
	_test_invalid_column()
	_test_player_win()
	_test_opponent_win()
	_test_full_board_draw()
	_test_last_cell_win_beats_full_board()
	_test_restart_resets()
	_test_starter_deck()
	_test_shuffle_deterministic()
	_test_start_hands_and_turn_draw()
	_test_play_uses_hand_goob()
	_test_hand_cap_skips_draw()
	_test_empty_deck_no_draw()
	_test_side_out_of_goobs_skipped()
	_test_stalemate_draw()
	_test_restart_reshuffles()

	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


## No-four fill pattern; a full board in this pattern has no four.
func _fill_owner(column: int, row: int) -> BoardState.CellOwner:
	return P if ((row / 2) + column) % 2 == 0 else O


func _board_empty(b: BoardState) -> bool:
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if not b.is_empty(c, r):
				return false
	return true


## Fills every cell except (6, 5), bottom to top per column.
func _fill_all_but_last(b: BoardState) -> void:
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if c == 6 and r == 5:
				continue
			b.drop(c, _fill_owner(c, r))


func _test_start_player_first() -> void:
	var t := TurnLoop.new()
	t.start(true)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "player first: phase")
	_check(t.current_side() == P, "player first: side")
	_check(_board_empty(t.board), "player first: empty board")
	_check(t.result == TurnLoop.Result.NONE, "player first: result NONE")


func _test_start_opponent_first() -> void:
	var t := TurnLoop.new()
	t.start(false)
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "opp first: phase")
	_check(t.current_side() == O, "opp first: side")
	_check(_board_empty(t.board), "opp first: empty board")
	_check(t.result == TurnLoop.Result.NONE, "opp first: result NONE")


func _test_alternates() -> void:
	var t := TurnLoop.new()
	t.start(true)
	_check(t.play(0) == 0, "alternates: first lands row 0")
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "alternates: now opponent")
	_check(t.board.get_owner(0, 0) == P, "alternates: (0,0) = P")
	_check(t.play(0) == 1, "alternates: second lands row 1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "alternates: back to player")
	_check(t.board.get_owner(0, 1) == O, "alternates: (0,1) = O")


func _test_full_column_keeps_turn() -> void:
	var t := TurnLoop.new()
	t.start(true)
	for r in BoardState.ROWS:
		t.board.drop(0, _fill_owner(0, r))
	var before := t.board.to_debug_string()
	_check(not t.can_play(0), "full column: can_play false")
	_check(t.play(0) == -1, "full column: play returns -1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "full column: turn kept")
	_check(t.board.to_debug_string() == before, "full column: board unchanged")


func _test_invalid_column() -> void:
	var t := TurnLoop.new()
	t.start(true)
	_check(t.play(7) == -1, "invalid: 7")
	_check(t.play(-1) == -1, "invalid: -1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "invalid: turn kept")
	_check(_board_empty(t.board), "invalid: board unchanged")


func _test_player_win() -> void:
	var t := TurnLoop.new()
	t.start(true)
	for c in 3:
		t.play(c)  # player
		t.play(6)  # opponent
	t.play(3)
	_check(t.result == TurnLoop.Result.PLAYER_WIN, "player win: result")
	_check(t.phase == TurnLoop.Phase.OVER, "player win: phase OVER")
	_check(t.current_side() == E, "player win: side EMPTY")
	_check(t.play(5) == -1, "player win: play rejected")
	_check(t.board.is_empty(5, 0), "player win: no drop after end")


func _test_opponent_win() -> void:
	var t := TurnLoop.new()
	t.start(false)
	for c in 3:
		t.play(c)  # opponent
		t.play(6)  # player
	t.play(3)
	_check(t.result == TurnLoop.Result.OPPONENT_WIN, "opp win: result")
	_check(t.phase == TurnLoop.Phase.OVER, "opp win: phase OVER")
	_check(t.current_side() == E, "opp win: side EMPTY")
	_check(t.play(5) == -1, "opp win: play rejected")


func _test_full_board_draw() -> void:
	var t := TurnLoop.new()
	t.start(true)
	_fill_all_but_last(t.board)
	_check(t.board.get_outcome() == BoardState.Outcome.NONE, "draw: no four before last play")
	_check(t.play(6) == 5, "draw: last cell lands row 5")
	_check(t.result == TurnLoop.Result.DRAW, "draw: result DRAW")
	_check(t.phase == TurnLoop.Phase.OVER, "draw: phase OVER")


func _test_last_cell_win_beats_full_board() -> void:
	var t := TurnLoop.new()
	t.start(true)
	_fill_all_but_last(t.board)
	t.board.set_owner(2, 1, O)
	t.board.set_owner(4, 3, P)
	t.board.set_owner(5, 4, P)
	_check(t.board.get_outcome() == BoardState.Outcome.NONE, "last-cell win: no four before play")
	t.play(6)
	_check(t.result == TurnLoop.Result.PLAYER_WIN, "last-cell win: PLAYER_WIN")
	_check(t.result != TurnLoop.Result.DRAW, "last-cell win: not DRAW")
	_check(t.phase == TurnLoop.Phase.OVER, "last-cell win: phase OVER")


func _test_restart_resets() -> void:
	var t := TurnLoop.new()
	t.start(true)
	for c in 3:
		t.play(c)
		t.play(6)
	t.play(3)
	_check(t.phase == TurnLoop.Phase.OVER, "restart: finished first")
	t.start(true)
	_check(_board_empty(t.board), "restart: empty board")
	_check(t.result == TurnLoop.Result.NONE, "restart: NONE")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "restart: PLAYER_TURN")


func _count_id(goobs: Array[GoobDefinition], id: String) -> int:
	var n := 0
	for g in goobs:
		if g.id == id:
			n += 1
	return n


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_starter_deck() -> void:
	var goobs := StarterDeck.build()
	_check(goobs.size() == 21, "starter: 21 Goobs")
	_check(_count_id(goobs, "vanilla") == 17, "starter: 17 Vanilla")
	for id in ["convincing", "fat", "popular", "plentiful"]:
		_check(_count_id(goobs, id) == 1, "starter: 1 %s" % id)


func _test_shuffle_deterministic() -> void:
	var a := Deck.shuffled(StarterDeck.build(), _seeded(7))
	var b := Deck.shuffled(StarterDeck.build(), _seeded(7))
	_check(a.draw_pile.size() == 21 and a.hand.is_empty(), "shuffle: 21 in pile, empty hand")
	_check(a.draw_pile == b.draw_pile, "shuffle: same seed, same order")
	_check(_count_id(a.draw_pile, "vanilla") == 17, "shuffle: composition kept")


func _test_start_hands_and_turn_draw() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(1))
	_check(t.player_deck.hand.size() == 4, "start: player 3 + turn draw = 4")
	_check(t.player_deck.draw_pile.size() == 17, "start: player pile 17")
	_check(t.opponent_deck.hand.size() == 3, "start: opponent 3 (not its turn)")
	_check(t.opponent_deck.draw_pile.size() == 18, "start: opponent pile 18")
	_check(t.last_draw.size() == 1 and t.last_draw[0] == t.player_deck.hand[3], "start: last_draw is the turn draw")
	_check(not t.last_draw_hand_full, "start: not hand full")
	t.play(0)
	_check(t.player_deck.hand.size() == 3, "turn: player plays 1")
	_check(t.opponent_deck.hand.size() == 4, "turn: opponent drew 1")
	_check(t.last_draw.size() == 1 and t.last_draw[0] == t.opponent_deck.hand[3], "turn: last_draw is opponent's")


func _test_play_uses_hand_goob() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(2))
	var chosen := t.player_deck.hand[2]
	var others := t.player_deck.hand.duplicate()
	others.remove_at(2)
	_check(t.play(3, 2) == 0, "hand play: lands")
	_check(t.goob_at(3, 0) == chosen, "hand play: cell remembers the Goob")
	_check(t.goob_at(4, 0) == null, "hand play: empty cell has no Goob")
	_check(t.player_deck.hand == others, "hand play: chosen Goob left the hand")
	var before := t.opponent_deck.hand.size()
	_check(t.play(1, 9) == -1, "hand play: bad index rejected")
	_check(t.play(1, -1) == -1, "hand play: negative index rejected")
	_check(t.opponent_deck.hand.size() == before and t.board.is_empty(1, 0), "hand play: rejection changes nothing")
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "hand play: turn kept on rejection")


func _test_hand_cap_skips_draw() -> void:
	var d := Deck.shuffled(StarterDeck.build(), _seeded(3))
	d.draw(Deck.HAND_MAX)
	var top: GoobDefinition = d.draw_pile.back()
	_check(d.hand.size() == 5, "cap: hand 5")
	_check(d.draw_blocked_by_hand(1), "cap: draw 1 blocked by hand")
	_check(d.draw(1).is_empty(), "cap: draw skipped")
	_check(d.hand.size() == 5 and d.draw_pile.size() == 16, "cap: nothing moved")
	_check(d.draw_pile.back() == top, "cap: Goob stays on top")
	d.take(0)
	_check(d.draw_blocked_by_hand(2), "cap: draw 2 with 1 room is blocked")
	_check(d.draw(2).size() == 1, "cap: draw 2 with 1 room draws 1")
	# Through TurnLoop: a full hand at turn start flags the skip.
	var t := TurnLoop.new()
	t.start(false, _seeded(4))
	t.player_deck.draw(1) # player hand 4
	t.player_deck.hand.append(t.player_deck.hand[0]) # 5 (as after Plentiful)
	var pile := t.player_deck.draw_pile.size()
	t.play(0) # opponent plays; player's turn begins with a full hand
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "cap turn: player's turn")
	_check(t.last_draw_hand_full and t.last_draw.is_empty(), "cap turn: hand full flagged, nothing drawn")
	_check(t.player_deck.hand.size() == 5 and t.player_deck.draw_pile.size() == pile, "cap turn: hand and pile unchanged")


func _test_empty_deck_no_draw() -> void:
	var t := TurnLoop.new()
	t.start(false, _seeded(5))
	t.player_deck.draw_pile.clear()
	t.play(0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "empty deck: player still plays")
	_check(t.last_draw.is_empty() and not t.last_draw_hand_full, "empty deck: no draw, not 'hand full'")
	_check(t.player_deck.hand.size() == 3, "empty deck: hand unchanged")
	_check(not t.player_deck.draw_blocked_by_hand(1), "empty deck: not blocked by hand")


func _test_side_out_of_goobs_skipped() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(6))
	t.opponent_deck.hand.clear()
	t.opponent_deck.draw_pile.clear()
	t.play(0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "out of Goobs: opponent skipped, player again")
	_check(t.last_draw.size() == 1, "out of Goobs: player draws for the new turn")
	t.play(1)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "out of Goobs: still player")
	t.play(2)
	t.play(3)
	_check(t.result == TurnLoop.Result.PLAYER_WIN, "out of Goobs: a four still ends it")


func _test_stalemate_draw() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(8))
	t.opponent_deck.hand.clear()
	t.opponent_deck.draw_pile.clear()
	t.player_deck.draw_pile.clear()
	t.player_deck.hand.resize(1)
	t.play(0)
	_check(t.result == TurnLoop.Result.DRAW, "stalemate: both out, no four = draw")
	_check(t.phase == TurnLoop.Phase.OVER, "stalemate: over")
	_check(not t.board.is_board_full(), "stalemate: board not full")


func _test_restart_reshuffles() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(9))
	t.play(0)
	t.play(0)
	t.start(true, _seeded(10))
	_check(t.player_deck.hand.size() == 4 and t.player_deck.draw_pile.size() == 17, "restart: fresh player deck")
	_check(t.opponent_deck.hand.size() == 3 and t.opponent_deck.draw_pile.size() == 18, "restart: fresh opponent deck")
	_check(t.goob_at(0, 0) == null, "restart: cell Goobs cleared")
