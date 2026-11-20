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
	_test_convincing_flips_enemy()
	_test_fat_destroys_and_drops()
	_test_popular_extra_vanilla()
	_test_plentiful_draws_two()
	_test_effect_before_win_check()
	_test_scoring_cells()

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
	t.start(true, null, _vanilla())
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "player first: phase")
	_check(t.current_side() == P, "player first: side")
	_check(_board_empty(t.board), "player first: empty board")
	_check(t.result == TurnLoop.Result.NONE, "player first: result NONE")


func _test_start_opponent_first() -> void:
	var t := TurnLoop.new()
	t.start(false, null, _vanilla())
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "opp first: phase")
	_check(t.current_side() == O, "opp first: side")
	_check(_board_empty(t.board), "opp first: empty board")
	_check(t.result == TurnLoop.Result.NONE, "opp first: result NONE")


func _test_alternates() -> void:
	var t := TurnLoop.new()
	t.start(true, null, _vanilla())
	_check(t.play(0) == 0, "alternates: first lands row 0")
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "alternates: now opponent")
	_check(t.board.get_owner(0, 0) == P, "alternates: (0,0) = P")
	_check(t.play(0) == 1, "alternates: second lands row 1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "alternates: back to player")
	_check(t.board.get_owner(0, 1) == O, "alternates: (0,1) = O")


func _test_full_column_keeps_turn() -> void:
	var t := TurnLoop.new()
	t.start(true, null, _vanilla())
	for r in BoardState.ROWS:
		t.board.drop(0, _fill_owner(0, r))
	var before := t.board.to_debug_string()
	_check(not t.can_play(0), "full column: can_play false")
	_check(t.play(0) == -1, "full column: play returns -1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "full column: turn kept")
	_check(t.board.to_debug_string() == before, "full column: board unchanged")


func _test_invalid_column() -> void:
	var t := TurnLoop.new()
	t.start(true, null, _vanilla())
	_check(t.play(7) == -1, "invalid: 7")
	_check(t.play(-1) == -1, "invalid: -1")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "invalid: turn kept")
	_check(_board_empty(t.board), "invalid: board unchanged")


func _test_player_win() -> void:
	var t := TurnLoop.new()
	t.start(true, null, _vanilla())
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
	t.start(false, null, _vanilla())
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
	t.start(true, null, _vanilla())
	_fill_all_but_last(t.board)
	_check(t.board.get_outcome() == BoardState.Outcome.NONE, "draw: no four before last play")
	_check(t.play(6) == 5, "draw: last cell lands row 5")
	_check(t.result == TurnLoop.Result.DRAW, "draw: result DRAW")
	_check(t.phase == TurnLoop.Phase.OVER, "draw: phase OVER")


func _test_last_cell_win_beats_full_board() -> void:
	var t := TurnLoop.new()
	t.start(true, null, _vanilla())
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
	t.start(true, null, _vanilla())
	for c in 3:
		t.play(c)
		t.play(6)
	t.play(3)
	_check(t.phase == TurnLoop.Phase.OVER, "restart: finished first")
	t.start(true, null, _vanilla())
	_check(_board_empty(t.board), "restart: empty board")
	_check(t.result == TurnLoop.Result.NONE, "restart: NONE")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "restart: PLAYER_TURN")


func _count_id(goobs: Array[GoobDefinition], id: String) -> int:
	var n := 0
	for g in goobs:
		if g.id == id:
			n += 1
	return n


## 21 Vanilla Goobs: a deck with no effects, for tests that only check turns.
func _vanilla() -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	for i in 21:
		goobs.append(TurnLoop.VANILLA)
	return goobs


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
	t.start(true, _seeded(1), _vanilla())
	_check(t.player_deck.hand.size() == 3, "start: player 2 + turn draw = 3")
	_check(t.player_deck.draw_pile.size() == 18, "start: player pile 18")
	_check(t.opponent_deck.hand.size() == 2, "start: opponent 2 (not its turn)")
	_check(t.opponent_deck.draw_pile.size() == 19, "start: opponent pile 19")
	_check(t.last_draw.size() == 1 and t.last_draw[0] == t.player_deck.hand[2], "start: last_draw is the turn draw")
	_check(not t.last_draw_hand_full, "start: not hand full")
	t.play(0)
	_check(t.player_deck.hand.size() == 2, "turn: player plays 1")
	_check(t.opponent_deck.hand.size() == 3, "turn: opponent drew 1")
	_check(t.last_draw.size() == 1 and t.last_draw[0] == t.opponent_deck.hand[2], "turn: last_draw is opponent's")


func _test_play_uses_hand_goob() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(2), _vanilla())
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
	t.start(false, _seeded(4), _vanilla())
	t.player_deck.draw(2) # player hand 4
	t.player_deck.hand.append(t.player_deck.hand[0]) # 5 (as after Plentiful)
	var pile := t.player_deck.draw_pile.size()
	t.play(0) # opponent plays; player's turn begins with a full hand
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "cap turn: player's turn")
	_check(t.last_draw_hand_full and t.last_draw.is_empty(), "cap turn: hand full flagged, nothing drawn")
	_check(t.player_deck.hand.size() == 5 and t.player_deck.draw_pile.size() == pile, "cap turn: hand and pile unchanged")


func _test_empty_deck_no_draw() -> void:
	var t := TurnLoop.new()
	t.start(false, _seeded(5), _vanilla())
	t.player_deck.draw_pile.clear()
	t.play(0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "empty deck: player still plays")
	_check(t.last_draw.is_empty() and not t.last_draw_hand_full, "empty deck: no draw, not 'hand full'")
	_check(t.player_deck.hand.size() == 2, "empty deck: hand unchanged")
	_check(not t.player_deck.draw_blocked_by_hand(1), "empty deck: not blocked by hand")


func _test_side_out_of_goobs_skipped() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(6), _vanilla())
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
	t.start(true, _seeded(8), _vanilla())
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
	t.start(true, _seeded(9), _vanilla())
	t.play(0)
	t.play(0)
	t.start(true, _seeded(10), _vanilla())
	_check(t.player_deck.hand.size() == 3 and t.player_deck.draw_pile.size() == 18, "restart: fresh player deck")
	_check(t.opponent_deck.hand.size() == 2 and t.opponent_deck.draw_pile.size() == 19, "restart: fresh opponent deck")
	_check(t.goob_at(0, 0) == null, "restart: cell Goobs cleared")


# --- M5 effects ----------------------------------------------------------------

const CONVINCING := preload("res://resources/goobs/convincing_goob.tres")
const FAT := preload("res://resources/goobs/fat_goob.tres")
const POPULAR := preload("res://resources/goobs/popular_goob.tres")
const PLENTIFUL := preload("res://resources/goobs/plentiful_goob.tres")


## Player to move, all-Vanilla decks, `special` as hand Goob 0.
func _with_special(special: GoobDefinition) -> TurnLoop:
	var t := TurnLoop.new()
	t.start(true, _seeded(20), _vanilla())
	t.player_deck.hand[0] = special
	return t


func _test_convincing_flips_enemy() -> void:
	var t := _with_special(CONVINCING)
	t.board.drop(0, O) # (0,0) enemy, adjacent to (1,0)
	t.board.drop(2, P) # (2,0) own, adjacent
	t.board.drop(4, O) # (4,0) enemy, not adjacent
	t.play(1, 0)
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.FLIP_ADJACENT, "convincing: effect kind")
	_check(not t.last_effect["fizzled"], "convincing: had a target")
	_check(t.last_effect["target"] == Vector2i(0, 0), "convincing: only the adjacent enemy is a target")
	_check(t.board.get_owner(0, 0) == P, "convincing: enemy flipped to player")
	_check(t.board.get_owner(4, 0) == O, "convincing: far enemy untouched")
	# Diagonals count (8-way).
	t = _with_special(CONVINCING)
	t.board.drop(3, P)
	t.board.drop(3, P)
	t.board.drop(2, O) # (2,0)
	t.board.drop(1, O) # (1,0)
	t.board.drop(1, O) # (1,1)
	t.play(2, 0) # lands (2,1): enemies (1,0) (1,1) (2,0); own (3,0) (3,1)
	var target: Vector2i = t.last_effect["target"]
	_check(target in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)], "convincing: target is an adjacent enemy (got %s)" % target)
	_check(t.board.get_owner(target.x, target.y) == P, "convincing: target flipped")
	# No enemy nearby: fizzle.
	t = _with_special(CONVINCING)
	t.board.drop(2, P)
	t.play(1, 0)
	_check(t.last_effect["fizzled"], "convincing: no adjacent enemy fizzles")
	_check(t.board.get_owner(2, 0) == P and t.board.get_owner(1, 0) == P, "convincing: fizzle changes nothing")


func _test_fat_destroys_and_drops() -> void:
	var t := _with_special(FAT)
	t.board.drop(0, O) # (0,0) adjacent to (1,0)
	t.board.drop(0, P) # (0,1) adjacent (diagonal)
	t.board.drop(0, O) # (0,2) not adjacent
	t.play(1, 0) # lands (1,0)
	var target: Vector2i = t.last_effect["target"]
	_check(not t.last_effect["fizzled"], "fat: had a target")
	_check(target in [Vector2i(0, 0), Vector2i(0, 1)], "fat: target adjacent (got %s)" % target)
	_check(t.board.lowest_empty_row(0) == 2, "fat: column 0 lost one Goob, no gap")
	_check(t.board.get_owner(0, 1) == O, "fat: Goob from (0,2) fell to (0,1)")
	_check(t.goob_at(1, 0) == FAT, "fat: Fat stays where it landed")
	# Own Goobs are fair game; definitions move down with the Goobs.
	t = _with_special(FAT)
	t.play(5, 1) # player Vanilla at (5,0)
	t.play(5, 0) # opponent Vanilla at (5,1)
	t.play(4, 0) # Fat at (4,0): neighbours (5,0) P and (5,1) O only
	target = t.last_effect["target"]
	_check(target in [Vector2i(5, 0), Vector2i(5, 1)], "fat: destroys own or enemy neighbour")
	_check(t.board.lowest_empty_row(5) == 1, "fat: column 5 down to one Goob")
	_check(t.goob_at(5, 0) == TurnLoop.VANILLA and t.goob_at(5, 1) == null, "fat: definitions follow the fall")
	# Nothing adjacent: fizzle.
	t = _with_special(FAT)
	t.play(3, 0)
	_check(t.last_effect["fizzled"], "fat: nothing adjacent fizzles")
	_check(t.board.get_owner(3, 0) == P, "fat: fizzle keeps the Fat Goob")


func _test_popular_extra_vanilla() -> void:
	var t := _with_special(POPULAR)
	t.play(3, 0)
	var extra: Vector2i = t.last_effect["extra"]
	_check(not t.last_effect["fizzled"], "popular: dropped")
	_check(t.board.get_owner(extra.x, extra.y) == P, "popular: extra Goob is the player's")
	_check(t.goob_at(extra.x, extra.y) == TurnLoop.VANILLA, "popular: extra Goob is a Vanilla")
	_check(extra.y == t.board.lowest_empty_row(extra.x) - 1, "popular: extra Goob obeys gravity")
	var count := 0
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if t.board.get_owner(c, r) == P:
				count += 1
	_check(count == 2, "popular: two player Goobs on the board")
	# Board full after it lands: fizzle (and a full board with no four is a draw).
	t = _with_special(POPULAR)
	_fill_all_but_last(t.board)
	t.play(6, 0)
	_check(t.last_effect["fizzled"], "popular: full board fizzles")
	_check(t.result == TurnLoop.Result.DRAW, "popular: full board, no four = draw")


func _test_plentiful_draws_two() -> void:
	var t := _with_special(PLENTIFUL)
	var hand := t.player_deck.hand.size() # 3 after the turn draw
	var pile := t.player_deck.draw_pile.size()
	t.play(0, 0)
	var drawn: Array[GoobDefinition] = t.last_effect["drawn"]
	_check(drawn.size() == 2, "plentiful: draws 2")
	_check(t.player_deck.hand.size() == hand - 1 + 2, "plentiful: hand -1 played +2 drawn")
	_check(t.player_deck.draw_pile.size() == pile - 2, "plentiful: pile -2")
	_check(not t.last_effect["hand_full"] and not t.last_effect["fizzled"], "plentiful: not full, not fizzled")
	# Hand cap: room for 1 → draws 1 and flags hand full.
	t = _with_special(PLENTIFUL)
	t.player_deck.hand.append(TurnLoop.VANILLA)
	t.player_deck.hand.append(TurnLoop.VANILLA) # 5
	t.play(0, 0) # 4 after playing
	drawn = t.last_effect["drawn"]
	_check(drawn.size() == 1 and t.last_effect["hand_full"], "plentiful: hand cap draws 1, flags full")
	_check(t.player_deck.hand.size() == 5, "plentiful: hand capped at 5")
	# Deck short: draws what remains; an empty deck fizzles.
	t = _with_special(PLENTIFUL)
	t.player_deck.draw_pile.resize(1)
	t.play(0, 0)
	_check((t.last_effect["drawn"] as Array).size() == 1, "plentiful: short deck draws what remains")
	t = _with_special(PLENTIFUL)
	t.player_deck.draw_pile.clear()
	t.play(0, 0)
	_check(t.last_effect["fizzled"], "plentiful: empty deck fizzles")


func _test_effect_before_win_check() -> void:
	# Convincing flips the enemy in the gap: the win check sees the new four.
	var t := _with_special(CONVINCING)
	t.board.drop(0, P)
	t.board.drop(1, P)
	t.board.drop(2, O)
	t.play(3, 0) # (3,0): its only neighbour is (2,0)
	_check(t.last_effect["target"] == Vector2i(2, 0), "order: flip target")
	_check(t.result == TurnLoop.Result.PLAYER_WIN, "order: flip into four wins")
	# Fat lands making four, then destroys one of them: no win.
	t = _with_special(FAT)
	t.board.drop(0, P)
	t.board.drop(1, P)
	t.board.drop(2, P)
	t.play(3, 0) # its only neighbour is (2,0)
	_check(t.last_effect["target"] == Vector2i(2, 0), "order: Fat's only target")
	_check(t.result == TurnLoop.Result.NONE, "order: four broken by the effect before the win check")
	# Popular's extra Vanilla completes a four: row 0 has P at 0-2, every other
	# column is full, so the Vanilla must land at (3,0).
	t = _with_special(POPULAR)
	for c in 3:
		t.board.drop(c, P)
	for c in range(4, BoardState.COLUMNS):
		for r in BoardState.ROWS:
			t.board.drop(c, O if (r + c) % 3 else P)
	for c in 3:
		for r in range(1, BoardState.ROWS - 1):
			t.board.drop(c, O if (r + c) % 2 else P)
	# Columns 0-2 have one open cell each at the top; Popular takes (0,5).
	t.board.drop(1, O)
	t.board.drop(2, O)
	t.play(0, 0)
	_check(t.last_effect["extra"] == Vector2i(3, 0), "order: extra Vanilla into the only open column")
	_check(t.result == TurnLoop.Result.PLAYER_WIN, "order: extra Vanilla's four wins")


func _test_scoring_cells() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(30), _vanilla())
	for c in 5:
		t.board.drop(c, P)
	var cells := t.scoring_cells(P)
	_check(cells.size() == 5, "scoring: five in a row reveals 5 Goobs (got %d)" % cells.size())
	_check(cells[0] == Vector2i(0, 0) and cells[4] == Vector2i(4, 0), "scoring: lowest column first")
	# Crossing lines: row 0 (columns 0-3) and column 3 (rows 0-3) share (3,0).
	t.board.reset()
	for c in 4:
		t.board.drop(c, P)
	for r in 3:
		t.board.drop(3, P)
	cells = t.scoring_cells(P)
	_check(cells.size() == 7, "scoring: crossing lines count each Goob once (got %d)" % cells.size())
	_check(cells.slice(3) == ([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)] as Array[Vector2i]), "scoring: bottom to top within a column")
	_check(t.scoring_cells(O).is_empty(), "scoring: no line, no cells")
