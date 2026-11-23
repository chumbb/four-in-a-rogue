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
	_test_m6e_multipliers_and_names()
	_test_deck_builder_shape()
	_test_deck_builder_main_pools()
	_test_deck_builder_no_dupes_when_enough()
	_test_start_rolls_per_side()
	_test_fat_fills_destroyed_pile()
	_test_discard()
	_test_effect_steps()
	_test_status_ticks()
	_test_discard_step()
	_test_roll_downhill()
	_test_roll_stops_equal()
	_test_roll_border()
	_test_roll_middle()
	_test_roll_floor_stays()
	_test_roll_empty_cell()
	_test_skip_turn_mid_turn()
	_test_turn_start_skip_empty_hand()
	_test_both_skip_is_stalemate()

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


func _test_m6e_multipliers_and_names() -> void:
	var specials := {CONVINCING: GoobDefinition.Category.UNIQUE, FAT: GoobDefinition.Category.DESTROY, POPULAR: GoobDefinition.Category.UNIQUE, PLENTIFUL: GoobDefinition.Category.DRAW}
	for g: GoobDefinition in specials:
		_check(g.multiplier == 2.0, "m6e: %s is x2" % g.id)
		_check(g.category == specials[g], "m6e: %s category" % g.id)
	var v := TurnLoop.VANILLA
	_check(v.multiplier == 1.0, "m6e: Vanilla x1")
	_check(v.display_name == "Goob", "m6e: Vanilla is shown as Goob")
	_check(v.category == GoobDefinition.Category.NONE, "m6e: Vanilla has no category")
	_check(POPULAR.effect_description == "Drop a Goob into a random column.", "m6e: Popular card text")


func _count_category(goobs: Array[GoobDefinition], category: GoobDefinition.Category) -> int:
	var n := 0
	for g in goobs:
		if g.category == category:
			n += 1
	return n


func _test_deck_builder_shape() -> void:
	var roster := GoobRoster.all()
	var ok := true
	for s in range(1, 201):
		var goobs := DeckBuilder.roll(_seeded(s))
		var top := _count_category(goobs, GoobDefinition.Category.UNIQUE) + _count_category(goobs, GoobDefinition.Category.TECH)
		var specials_ok := true
		for g in goobs:
			specials_ok = specials_ok and roster.has(g)
		ok = ok and goobs.size() == 21 and _count_category(goobs, GoobDefinition.Category.NONE) >= 11 and top >= 1 and top <= 2 and specials_ok
	_check(ok, "deck builder: 21 Goobs, >= 11 plain, 1-2 UNIQUE/TECH, all from the roster (seeds 1..200)")
	var has_top := true
	for s in range(1, 201):
		var goobs := DeckBuilder.roll(_seeded(s), {"top": GoobDefinition.Category.UNIQUE})
		var n := _count_category(goobs, GoobDefinition.Category.UNIQUE)
		has_top = has_top and n >= 1 and n <= 2
	_check(has_top, "deck builder: forced UNIQUE gives 1-2 UNIQUE Goobs")


func _test_deck_builder_main_pools() -> void:
	var D := GoobDefinition.Category.DESTROY
	var X := GoobDefinition.Category.DISCARD
	var ok := true
	var saw_draw := false
	for s in range(1, 201):
		var goobs := DeckBuilder.roll(_seeded(s), {"main": [D, X], "top": GoobDefinition.Category.UNIQUE})
		var top := _count_category(goobs, GoobDefinition.Category.UNIQUE)
		var draws := _count_category(goobs, GoobDefinition.Category.DRAW)
		var fat := _count_category(goobs, D)
		var plain := _count_category(goobs, GoobDefinition.Category.NONE)
		saw_draw = saw_draw or draws > 0
		# 10 specials: top + DESTROY pool + DISCARD pool (plain, no Goobs yet) + DRAW.
		var discard_slots := 10 - top - fat - draws
		ok = ok and draws <= 3 and discard_slots >= 0 and plain == 11 + discard_slots
		ok = ok and top + fat + draws + discard_slots == 10
	_check(ok, "deck builder: main pools + top = 10 slots, DRAW <= 3, empty DISCARD slots plain (seeds 1..200)")
	_check(saw_draw, "deck builder: DRAW Goobs do appear in pools")


func _test_deck_builder_no_dupes_when_enough() -> void:
	var roster: Array[GoobDefinition] = []
	for i in 6:
		var g := GoobDefinition.new()
		g.id = "stub_destroy_%d" % i
		g.category = GoobDefinition.Category.DESTROY
		roster.append(g)
	var ok := true
	for s in range(1, 201):
		var goobs := DeckBuilder.roll_from(_seeded(s), roster, {"main": [GoobDefinition.Category.DESTROY, GoobDefinition.Category.MOVE]})
		var seen := {}
		for g in goobs:
			if g.category == GoobDefinition.Category.DESTROY:
				ok = ok and not seen.has(g.id)
				seen[g.id] = true
	_check(ok, "deck builder: no repeated type inside a pool when the roster has enough")


func _composition(goobs: Array[GoobDefinition]) -> Dictionary:
	var counts := {}
	for g in goobs:
		counts[g.id] = int(counts.get(g.id, 0)) + 1
	return counts


func _test_start_rolls_per_side() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(3))
	_check(t.player_goobs.size() == 21 and t.opponent_goobs.size() == 21, "rolls: 21 Goobs per side")
	_check(t.player_deck.draw_pile.size() + t.player_deck.hand.size() == 21, "rolls: player deck holds 21")
	var differs := false
	for s in range(1, 21):
		t.start(true, _seeded(s))
		differs = differs or _composition(t.player_goobs) != _composition(t.opponent_goobs)
	_check(differs, "rolls: the two sides roll their own decks")
	t.start(true, _seeded(3))
	var mine := t.player_goobs
	var his := t.opponent_goobs
	var t2 := TurnLoop.new()
	t2.start(true, _seeded(9), mine, his)
	_check(_composition(t2.player_goobs) == _composition(mine) and _composition(t2.opponent_goobs) == _composition(his), "rolls: passing both lists reproduces the compositions")
	_check(t2.player_deck.hand.size() + t2.player_deck.draw_pile.size() == 21, "rolls: replay deck holds 21")


func _test_fat_fills_destroyed_pile() -> void:
	var t := _with_special(FAT)
	t.play(5, 1) # player Vanilla (5,0)
	t.play(4, 0) # opponent Vanilla (4,0)
	t.play(3, 0) # Fat at (3,0): only neighbour is the opponent's (4,0)
	_check(t.opponent_deck.destroyed_pile == [TurnLoop.VANILLA], "destroyed pile: opponent Vanilla")
	_check(t.player_deck.destroyed_pile.is_empty(), "destroyed pile: player's stays empty")
	_check(t.board.get_owner(4, 0) == O or t.board.get_owner(4, 0) == BoardState.CellOwner.EMPTY, "destroyed pile: cell cleared")


func _test_discard() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(21), _vanilla())
	var d := t.player_deck
	var first := d.hand[0]
	var size := d.hand.size()
	_check(d.discard(0) == first, "discard: returns the Goob")
	_check(d.discard_pile == [first] and d.hand.size() == size - 1, "discard: hand to pile")
	_check(d.discard(9) == null and d.discard_pile.size() == 1 and d.hand.size() == size - 1, "discard: out of range changes nothing")
	var g := t.discard_from(BoardState.CellOwner.PLAYER, 0)
	_check(g != null and d.discard_pile.size() == 2, "discard_from: moves to the side's pile")


func _test_effect_steps() -> void:
	var t := _with_special(FAT)
	t.board.drop(0, O)
	t.play(1, 0)
	_check(t.effect_steps.size() == 1 and t.last_effect == t.effect_steps[0], "steps: fat gives one step, last_effect is step 0")
	var v := TurnLoop.new()
	v.start(true, _seeded(22), _vanilla())
	v.play(3, 0)
	_check(v.effect_steps.size() == 1 and v.effect_steps[0]["kind"] == GoobDefinition.EffectType.NONE, "steps: vanilla gives one NONE step")
	v.play(3, 0)
	_check(v.effect_steps.size() == 1, "steps: reset each play")


func _test_status_ticks() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(23), _vanilla())
	t.add_status(&"t", P, "Test", "x", 2)
	t.add_status(&"f", P, "Forever", "y", -1)
	_check(t.has_status(&"t", P) and not t.has_status(&"t", O), "status: has_status per side")
	t.play(0, 0)
	_check(t.has_status(&"t", P) and t.statuses[0]["turns_left"] == 1, "status: one left after first turn start")
	t.play(1, 0)
	_check(not t.has_status(&"t", P), "status: gone after two turn starts")
	for i in 10:
		t.play(i % 7, 0)
	_check(t.has_status(&"f", P), "status: -1 survives 10 plays")
	t.remove_status(&"f", P)
	_check(not t.has_status(&"f", P), "status: remove_status")
	t.add_status(&"f", P, "Forever", "y", -1)
	t.start(true, _seeded(23), _vanilla())
	_check(t.statuses.is_empty(), "status: start() clears")


func _test_discard_step() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(24), _vanilla())
	var g := t.discard_from(P, 0)
	_check(t.effect_steps.size() == 1 and t.effect_steps[0]["discarded"] == g and t.effect_steps[0]["kind"] == GoobDefinition.EffectType.NONE, "discard step: appended")
	t.discard_from(P, 99)
	_check(t.effect_steps.size() == 1, "discard step: none when nothing discarded")
	t.discard_from(P, 1)
	_check(t.effect_steps[0]["index"] == 0 and t.effect_steps[1]["index"] == 1, "discard step: records the hand index")


func _roll_stack(t: TurnLoop, column: int, count: int, owner: BoardState.CellOwner = P) -> void:
	for i in count:
		t.board.drop(column, owner)
		t._cell_goobs[Vector2i(column, i)] = TurnLoop.VANILLA


func _test_roll_downhill() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(30), _vanilla())
	_roll_stack(t, 0, 3)
	_roll_stack(t, 1, 1)
	_roll_stack(t, 3, 1) # a Goob beside (2,0) stops the floor roll
	var path := t.roll_goob(Vector2i(0, 2), 1)
	_check(path.size() == 2 and path[0] == Vector2i(1, 1) and path[1] == Vector2i(2, 0), "roll downhill: path ends at (2,0)")
	_check(t.board.get_owner(2, 0) == P and t.goob_at(2, 0) == TurnLoop.VANILLA, "roll downhill: landed Goob kept")
	_check(t.board.get_owner(0, 2) == BoardState.CellOwner.EMPTY and t.board.get_owner(0, 1) == P, "roll downhill: column 0 height 2")


func _test_roll_stops_equal() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(31), _vanilla())
	_roll_stack(t, 0, 2)
	_roll_stack(t, 1, 2)
	_check(t.roll_goob(Vector2i(0, 1), 1).is_empty(), "roll equal: no move")
	_check(t.board.get_owner(0, 1) == P, "roll equal: Goob stays")


func _test_roll_border() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(32), _vanilla())
	_roll_stack(t, 0, 1)
	_check(t.roll_goob(Vector2i(0, 0), -1).is_empty(), "roll border: left of column 0")
	_roll_stack(t, 6, 1)
	_check(t.roll_goob(Vector2i(6, 0), 1).is_empty(), "roll border: right of column 6")


func _test_roll_middle() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(33), _vanilla())
	_roll_stack(t, 0, 3)
	_roll_stack(t, 2, 1) # stops the floor roll at (1,0)
	t.board.set_owner(0, 1, O)
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	t._cell_goobs[Vector2i(0, 1)] = fat
	var path := t.roll_goob(Vector2i(0, 1), 1)
	_check(path.size() == 1 and path[0] == Vector2i(1, 0), "roll middle: path")
	_check(t.board.get_owner(1, 0) == O and t.goob_at(1, 0) == fat, "roll middle: owner and definition kept")
	_check(t.board.get_owner(0, 1) == P and t.goob_at(0, 1) == TurnLoop.VANILLA, "roll middle: top Goob fell to row 1")
	_check(t.board.get_owner(0, 2) == BoardState.CellOwner.EMPTY and t.goob_at(0, 2) == null, "roll middle: column 0 height 2")


func _test_roll_floor_stays() -> void:
	# Sean (2026-11-23): a Goob on the floor rolls all the way to the side.
	var t := TurnLoop.new()
	t.start(true, _seeded(34), _vanilla())
	_roll_stack(t, 2, 1)
	var path := t.roll_goob(Vector2i(2, 0), 1)
	_check(path.size() == 4 and path[3] == Vector2i(6, 0), "roll floor: rolls to the border (got %s)" % [path])
	_check(t.board.get_owner(6, 0) == P and t.board.get_owner(2, 0) == E, "roll floor: now at (6,0)")
	# Over flat tops too: a level row of Goobs carries it to the next Goob or the edge.
	var u := TurnLoop.new()
	u.start(true, _seeded(36), _vanilla())
	_roll_stack(u, 0, 2)
	for column in range(1, 7):
		_roll_stack(u, column, 1)
	var flat := u.roll_goob(Vector2i(0, 1), 1)
	_check(flat.size() == 6 and flat[5] == Vector2i(6, 1), "roll flat top: rolls along row 1 to the border (got %s)" % [flat])


## Final review: an empty cell has nothing to roll.
func _test_roll_empty_cell() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(35), _vanilla())
	_roll_stack(t, 0, 1)
	var path := t.roll_goob(Vector2i(0, 3), 1)
	_check(path.is_empty(), "roll empty: no path (got %d)" % path.size())
	var count := 0
	for column in BoardState.COLUMNS:
		for row in BoardState.ROWS:
			if t.board.get_owner(column, row) != BoardState.CellOwner.EMPTY:
				count += 1
	_check(count == 1, "roll empty: board unchanged (got %d Goobs)" % count)


## Sean (2026-11-23): losing your last Goob is fine (you draw next turn); with
## no Goob in hand after the draw, the turn is skipped.
class NoDrawLoop extends TurnLoop:
	var no_draw: Array = []
	func _turn_draw_count(side: BoardState.CellOwner) -> int:
		return 0 if no_draw.has(side) else TURN_DRAW


func _test_skip_turn_mid_turn() -> void:
	var t := TurnLoop.new()
	t.start(true, _seeded(40), _vanilla())
	while not t.player_deck.hand.is_empty():
		t.discard_from(P, 0)
	t.skip_turn()
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN, "skip mid-turn: opponent's turn")
	_check(t.last_skipped == [P] and t.was_skipped_last(P), "skip mid-turn: player recorded")
	t.play(0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN and t.player_deck.hand.size() == 1 and t.last_skipped.is_empty(), "skip mid-turn: next turn draws 1")
	_check(not t.was_skipped_last(P), "skip mid-turn: cleared once the player has a turn")


func _test_turn_start_skip_empty_hand() -> void:
	var t := NoDrawLoop.new()
	t.start(true, _seeded(41), _vanilla())
	t.opponent_deck.hand.clear()
	t.no_draw = [O]
	t.play(0)
	_check(t.last_skipped == [O], "skip at turn start: opponent skipped")
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN and t.result == TurnLoop.Result.NONE, "skip at turn start: back to the player")


func _test_both_skip_is_stalemate() -> void:
	# Sean (2026-11-23): back-to-back skips are NOT a draw; turn order goes on,
	# and the same side is never skipped twice in a row.
	var t := NoDrawLoop.new()
	t.start(true, _seeded(42), _vanilla())
	t.opponent_deck.hand.clear()
	var only: Array[GoobDefinition] = [TurnLoop.VANILLA]
	t.player_deck.hand.assign(only)
	t.no_draw = [P, O]
	t.play(0)
	_check(t.last_skipped == [O, P], "both skip: opponent then player skipped")
	_check(t.result == TurnLoop.Result.NONE, "both skip: not a draw")
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN and t.opponent_deck.hand.size() == 1, "both skip: opponent's turn again, and he draws despite the block (skipped last turn)")
	t.play(0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN and t.player_deck.hand.size() == 1 and t.last_skipped.is_empty(), "both skip: player draws despite the block (never skipped twice in a row)")
	_check(t.result == TurnLoop.Result.NONE, "both skip: game still running")
