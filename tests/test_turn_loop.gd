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
	_test_greedy_draws_two()
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
	_test_move_roster()
	_test_sinister_push()
	_test_dexterous_push()
	_test_push_raised_row()
	_test_push_chain_tipsy()
	_test_lopsided()
	_test_fat_chain_lopsided()
	_test_bouncy()
	_test_bouncy_full_rolls_from_top()
	_test_bouncy_rolled_dir()
	_test_slippery()
	_test_blustery()
	_test_springy()
	_test_fidgety()
	_test_play_outcomes_moves()
	_test_stacked_lopsided()
	_test_popular_on_bouncy()
	_test_fall_onto_bouncy()
	_test_outcome_weights()
	_test_threat_on_bouncy()
	_test_chain_loop_stops()
	_test_destroy_roster()
	_test_volatile()
	_test_crushing()
	_test_brawling()
	_test_spiteful()
	_test_spiteful_effect_fires()
	_test_spiteful_fall_and_roll()
	_test_spiteful_threat()
	_test_occult()
	_test_smouldering()
	_test_spiteful_two_gaps()
	_test_occult_simulated()
	_test_discard_roster()
	_test_distracting()
	_test_defiant()
	_test_fickle()
	_test_ruthless()
	_test_ruthless_defiant()
	_test_reckless()
	_test_thrifty()
	_test_desperate()
	_test_discard_simulated()
	_test_draw_roster()
	_test_jinxing()
	_test_jinxing_adds_up_and_forced_draw()
	_test_jinxing_skips_empty_hand()
	_test_generous()
	_test_plentiful()
	_test_plentiful_no_loop()
	_test_tech_roster()
	_test_steadfast()
	_test_loyal()
	_test_stalwart()
	_test_territorial()
	_test_inspiring()
	_test_stifling()
	_test_thieving()
	_test_hoarding()
	_test_tech_simulated()
	_test_unique_roster()
	_test_seismic()
	_test_sinking()
	_test_rowdy()
	_test_nostalgic()
	_test_m6f_looks()
	_test_mocking()
	_test_unique_simulated()

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
	for id in ["convincing", "fat", "popular", "greedy"]:
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
	_check(d.hand.size() == Deck.HAND_MAX, "cap: hand full")
	_check(d.draw_blocked_by_hand(1), "cap: draw 1 blocked by hand")
	_check(d.draw(1).is_empty(), "cap: draw skipped")
	_check(d.hand.size() == Deck.HAND_MAX and d.draw_pile.size() == 21 - Deck.HAND_MAX, "cap: nothing moved")
	_check(d.draw_pile.back() == top, "cap: Goob stays on top")
	d.take(0)
	_check(d.draw_blocked_by_hand(2), "cap: draw 2 with 1 room is blocked")
	_check(d.draw(2).size() == 1, "cap: draw 2 with 1 room draws 1")
	# Through TurnLoop: a full hand at turn start flags the skip.
	var t := TurnLoop.new()
	t.start(false, _seeded(4), _vanilla())
	t.player_deck.draw(2) # player hand 4
	while t.player_deck.hand.size() < Deck.HAND_MAX:
		t.player_deck.hand.append(t.player_deck.hand[0]) # full (as after Greedy)
	var pile := t.player_deck.draw_pile.size()
	t.play(0) # opponent plays; player's turn begins with a full hand
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN, "cap turn: player's turn")
	_check(t.last_draw_hand_full and t.last_draw.is_empty(), "cap turn: hand full flagged, nothing drawn")
	_check(t.player_deck.hand.size() == Deck.HAND_MAX and t.player_deck.draw_pile.size() == pile, "cap turn: hand and pile unchanged")


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
const GREEDY := preload("res://resources/goobs/greedy_goob.tres")


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


func _test_greedy_draws_two() -> void:
	var t := _with_special(GREEDY)
	var hand := t.player_deck.hand.size() # 3 after the turn draw
	var pile := t.player_deck.draw_pile.size()
	t.play(0, 0)
	var drawn: Array[GoobDefinition] = t.last_effect["drawn"]
	_check(drawn.size() == 2, "greedy: draws 2")
	_check(t.player_deck.hand.size() == hand - 1 + 2, "greedy: hand -1 played +2 drawn")
	_check(t.player_deck.draw_pile.size() == pile - 2, "greedy: pile -2")
	_check(not t.last_effect["hand_full"] and not t.last_effect["fizzled"], "greedy: not full, not fizzled")
	# Hand cap: room for 1 → draws 1 and flags hand full.
	t = _with_special(GREEDY)
	while t.player_deck.hand.size() < Deck.HAND_MAX:
		t.player_deck.hand.append(TurnLoop.VANILLA) # full
	t.play(0, 0) # one room after playing
	drawn = t.last_effect["drawn"]
	_check(drawn.size() == 1 and t.last_effect["hand_full"], "greedy: hand cap draws 1, flags full")
	_check(t.player_deck.hand.size() == Deck.HAND_MAX, "greedy: hand capped")
	# Deck short: draws what remains; an empty deck fizzles.
	t = _with_special(GREEDY)
	t.player_deck.draw_pile.resize(1)
	t.play(0, 0)
	_check((t.last_effect["drawn"] as Array).size() == 1, "greedy: short deck draws what remains")
	t = _with_special(GREEDY)
	t.player_deck.draw_pile.clear()
	t.play(0, 0)
	_check(t.last_effect["fizzled"], "greedy: empty deck fizzles")


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
	var specials := {CONVINCING: GoobDefinition.Category.UNIQUE, FAT: GoobDefinition.Category.DESTROY, POPULAR: GoobDefinition.Category.UNIQUE, GREEDY: GoobDefinition.Category.DRAW}
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


func _count_family(goobs: Array[GoobDefinition], family: GoobDefinition.Category) -> int:
	var n := 0
	for g in goobs:
		if g.category != GoobDefinition.Category.NONE and g.ring_family() == family:
			n += 1
	return n


func _count_legendary(goobs: Array[GoobDefinition]) -> int:
	var n := 0
	for g in goobs:
		if g.is_legendary():
			n += 1
	return n


## M6f (Sean, 2026-11-24): CLASSIC 10 specials (top 1-2), LOADED 14 (top 2-3);
## pools by family ring; DRAW 0-1 per main pool; <= 2 legendaries.
func _test_deck_builder_shape() -> void:
	var roster := GoobRoster.all()
	var T := GoobDefinition.Category.TECH
	for type: DeckBuilder.DeckType in [DeckBuilder.DeckType.CLASSIC, DeckBuilder.DeckType.LOADED]:
		var specials: int = DeckBuilder.SPECIALS[type]
		var top_range: Vector2i = DeckBuilder.TOP_RANGE[type]
		var ok := true
		var saw_draw := false
		var saw_legendary := false
		for s in range(1, 201):
			var goobs := DeckBuilder.roll(_seeded(s), {"type": type})
			var top := _count_family(goobs, T)
			var draws := _count_family(goobs, GoobDefinition.Category.DRAW)
			var legendary := _count_legendary(goobs)
			saw_draw = saw_draw or draws > 0
			saw_legendary = saw_legendary or legendary > 0
			var from_roster := true
			for g in goobs:
				from_roster = from_roster and roster.has(g)
			ok = ok and goobs.size() == 21 and _count_category(goobs, GoobDefinition.Category.NONE) == 21 - specials
			ok = ok and top >= top_range.x and top <= top_range.y and draws <= 2 and legendary <= DeckBuilder.LEGENDARY_MAX and from_roster
		_check(ok, "deck builder %d: 21 Goobs, %d specials, top %d-%d, DRAW <= 2, legendaries <= 2 (seeds 1..200)" % [type, specials, top_range.x, top_range.y])
		_check(saw_draw and saw_legendary, "deck builder %d: DRAW Goobs and legendaries do appear" % type)
	var types := {}
	for s in range(1, 101):
		var goobs := DeckBuilder.roll(_seeded(s))
		types[21 - _count_category(goobs, GoobDefinition.Category.NONE)] = true
	_check(types.has(10) and types.has(14) and types.size() == 2, "deck builder: unforced rolls give both deck types")


func _test_deck_builder_main_pools() -> void:
	var D := GoobDefinition.Category.DESTROY
	var X := GoobDefinition.Category.DISCARD
	var M := GoobDefinition.Category.MOVE
	var ok := true
	var families_ok := true
	for type: DeckBuilder.DeckType in [DeckBuilder.DeckType.CLASSIC, DeckBuilder.DeckType.LOADED]:
		for s in range(1, 201):
			var goobs := DeckBuilder.roll(_seeded(s), {"main": [D, X], "type": type})
			var top := _count_family(goobs, GoobDefinition.Category.TECH)
			var draws := _count_family(goobs, GoobDefinition.Category.DRAW)
			var destroys := _count_family(goobs, D)
			var discards := _count_family(goobs, X)
			ok = ok and destroys >= 3 and discards >= 3 and top + destroys + discards + draws == DeckBuilder.SPECIALS[type]
			# Legendaries roll with their ring: no Move family here at all.
			families_ok = families_ok and _count_family(goobs, M) == 0
	_check(ok, "deck builder: top + DESTROY + DISCARD + DRAW pools fill the specials (seeds 1..200, both types)")
	_check(families_ok, "deck builder: Seismic / Rowdy only roll with Move")
	var sinking := false
	for s in range(1, 401):
		for g in DeckBuilder.roll(_seeded(s), {"main": [M, X], "type": DeckBuilder.DeckType.LOADED}):
			sinking = sinking or g.id == "sinking"
	_check(not sinking, "deck builder: Sinking only rolls with Destroy")


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
	for seed in range(1, 41):
		var u := TurnLoop.new()
		u.start(true, _seeded(seed))
		_check(_count_category(u.player_goobs, GoobDefinition.Category.NONE) == _count_category(u.opponent_goobs, GoobDefinition.Category.NONE), "rolls: both sides use the same deck type (seed %d)" % seed)
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
	func _turn_draw_count(side: BoardState.CellOwner, _jinxed := true) -> int:
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


# --- M6e Move (Sean, 2026-11-23; vault Special Goobs "M6e Move rules") -------

const SINISTER := preload("res://resources/goobs/sinister_goob.tres")
const DEXTEROUS := preload("res://resources/goobs/dexterous_goob.tres")
const LOPSIDED := preload("res://resources/goobs/lopsided_goob.tres")
const TIPSY := preload("res://resources/goobs/tipsy_goob.tres")
const BOUNCY := preload("res://resources/goobs/bouncy_goob.tres")
const SLIPPERY := preload("res://resources/goobs/slippery_goob.tres")
const BLUSTERY := preload("res://resources/goobs/blustery_goob.tres")
const SPRINGY := preload("res://resources/goobs/springy_goob.tres")
const FIDGETY := preload("res://resources/goobs/fidgety_goob.tres")


## Drops `goob` for `owner` into `column` straight onto the board (no effect).
func _place(t: TurnLoop, column: int, goob: GoobDefinition = TurnLoop.VANILLA, owner: BoardState.CellOwner = O) -> Vector2i:
	var row := t.board.drop(column, owner)
	t._cell_goobs[Vector2i(column, row)] = goob
	return Vector2i(column, row)


func _test_move_roster() -> void:
	var moves := GoobRoster.specials(GoobDefinition.Category.MOVE)
	_check(moves.size() == 9, "move: nine move Goobs in the roster (got %d)" % moves.size())
	for goob in moves:
		_check(goob.multiplier == 2.0 and goob.art_id == "vanilla" and goob.display_name.ends_with(" Goob"), "move: %s is x2, Vanilla art, named" % goob.id)
		_check(goob.effect_description != "", "move: %s has card text" % goob.id)


func _test_sinister_push() -> void:
	var t := _with_special(SINISTER)
	_place(t, 0, TurnLoop.VANILLA, P) # stays at the edge
	_place(t, 2, FAT)
	_place(t, 2, POPULAR) # sits on Fat
	_place(t, 3, CONVINCING)
	t.play(6, 0) # Sinister at (6,0)
	_check(not t.last_effect["fizzled"], "sinister: pushed")
	_check(t.goob_at(0, 0) == TurnLoop.VANILLA and t.board.get_owner(0, 0) == P, "sinister: edge Goob stays")
	_check(t.goob_at(1, 0) == FAT, "sinister: Fat rolled to (1,0)")
	_check(t.goob_at(2, 0) == CONVINCING, "sinister: Convincing rolled into Fat's old cell")
	_check(t.goob_at(2, 1) == POPULAR, "sinister: the Goob on Fat stays held up")
	_check(t.board.is_empty(3, 0), "sinister: (3,0) empty")
	_check(t.goob_at(6, 0) == SINISTER, "sinister: the pusher stays")
	_check(t.last_effect["motions"].size() >= 2, "sinister: motions recorded")
	# At the left edge there is nothing to push: fizzle.
	t = _with_special(SINISTER)
	_place(t, 3)
	t.play(0, 0)
	_check(t.last_effect["fizzled"], "sinister: nothing on its left fizzles")
	_check(t.goob_at(3, 0) == TurnLoop.VANILLA, "sinister: right side untouched")


func _test_dexterous_push() -> void:
	var t := _with_special(DEXTEROUS)
	_place(t, 3)
	_place(t, 0, FAT) # left side: untouched
	t.play(1, 0) # Dexterous at (1,0)
	_check(t.goob_at(6, 0) == TurnLoop.VANILLA and t.board.is_empty(3, 0), "dexterous: Goob rolled right to the edge")
	_check(t.goob_at(0, 0) == FAT, "dexterous: left side stays")


func _test_push_raised_row() -> void:
	var t := _with_special(SINISTER)
	_place(t, 0) # (0,0)
	_place(t, 1) # (1,0)
	_place(t, 1, FAT) # (1,1): in the pushed row
	_place(t, 1, POPULAR) # (1,2): falls after the push
	_place(t, 3) # (3,0)
	t.play(3, 0) # Sinister at (3,1)
	_check(t.goob_at(0, 1) == FAT, "push raised: (1,1) rolled to (0,1)")
	_check(t.goob_at(1, 1) == POPULAR and t.board.is_empty(1, 2), "push raised: the Goob above fell")


func _test_push_chain_tipsy() -> void:
	var t := _with_special(SINISTER)
	_place(t, 2) # (2,0)
	_place(t, 2, TIPSY) # (2,1)
	t.play(4, 0) # Sinister at (4,0)
	_check(t.goob_at(0, 0) == TurnLoop.VANILLA, "push chain: Goob pushed to the edge")
	_check(t.goob_at(3, 0) == TIPSY, "push chain: Tipsy fell, then rolled right to Sinister")
	_check(t.board.is_empty(2, 0) and t.board.is_empty(2, 1), "push chain: column 2 empty")


func _test_lopsided() -> void:
	var t := _with_special(LOPSIDED)
	_place(t, 3)
	t.play(3, 0) # lands (3,1), rolls left down to the floor and on to the edge
	_check(t.goob_at(0, 0) == LOPSIDED and t.board.get_owner(0, 0) == P, "lopsided: rolled left to (0,0)")
	_check(t.board.is_empty(3, 1), "lopsided: left its landing cell")
	t = _with_special(TIPSY)
	t.play(2, 0)
	_check(t.goob_at(6, 0) == TIPSY, "tipsy: rolled right to (6,0)")
	t = _with_special(LOPSIDED)
	t.play(0, 0)
	_check(t.last_effect["fizzled"] and t.goob_at(0, 0) == LOPSIDED, "lopsided: at the left edge it fizzles")


func _test_fat_chain_lopsided() -> void:
	var t := _with_special(FAT)
	_place(t, 5) # (5,0): Fat's target
	_place(t, 5, LOPSIDED) # (5,1): falls, then rolls left
	t._scripted = true
	t._script = [0] # Fat at (6,0): neighbour 0 = (5,0)
	t.play(6, 0)
	_check(t.last_effect["target"] == Vector2i(5, 0), "fat chain: destroyed (5,0)")
	_check(t.goob_at(0, 0) == LOPSIDED, "fat chain: Lopsided fell and rolled to (0,0)")
	var chain := false
	for step in t.effect_steps:
		chain = chain or step.get("chain", false)
	_check(chain, "fat chain: a chain step")


func _test_bouncy() -> void:
	var t := _with_special(TurnLoop.VANILLA)
	_place(t, 3, BOUNCY)
	t.play(3, 0) # lands on Bouncy, bounces to a random side
	var left := t.board.get_owner(2, 0) == P
	var right := t.board.get_owner(4, 0) == P
	_check(left != right, "bouncy: bounced to (2,0) or (4,0)")
	_check(t.board.is_empty(3, 1), "bouncy: nothing stays on Bouncy")
	_check(t.effect_steps[0]["kind"] == GoobDefinition.EffectType.BOUNCY and t.effect_steps[0].get("instant", false), "bouncy: an instant Bouncy step first")
	# Regardless of height: onto a taller column.
	t = _with_special(TurnLoop.VANILLA)
	_place(t, 3, BOUNCY)
	for c in [2, 4]:
		for i in 3:
			_place(t, c)
	t.play(3, 0)
	_check(t.board.get_owner(2, 3) == P or t.board.get_owner(4, 3) == P, "bouncy: lands on top of a taller column")
	# The played Goob's effect fires where it ends up.
	t = _with_special(FAT)
	_place(t, 3, BOUNCY)
	t.play(3, 0)
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.DESTROY_ADJACENT and t.last_effect["cell"] != Vector2i(3, 1), "bouncy: Fat's effect at its final cell")
	# Effect drops don't bounce: Popular's extra Goob lands on Bouncy and stays.
	t = _with_special(POPULAR)
	for c in BoardState.COLUMNS:
		if c == 3:
			continue
		for i in (BoardState.ROWS - 1 if c == 5 else BoardState.ROWS):
			_place(t, c)
	_place(t, 3, BOUNCY)
	t.play(5, 0) # fills column 5; the extra Goob can only go to column 3
	_check(t.board.get_owner(3, 1) == P, "bouncy: effect drop not bounced")


func _test_bouncy_full_rolls_from_top() -> void:
	var t := _with_special(TurnLoop.VANILLA)
	for c in [0, 1, 2, 4]:
		for i in BoardState.ROWS:
			_place(t, c)
	_place(t, 3, BOUNCY)
	t.play(3, 0)
	# Either way it rolls over the full columns and ends in column 5.
	_check(t.board.get_owner(5, 0) == P, "bouncy full: rolled from the top into (5,0)")
	_check(t.board.is_empty(3, 1) and t.board.is_empty(6, 0), "bouncy full: nowhere else")


func _test_bouncy_rolled_dir() -> void:
	var t := _with_special(TurnLoop.VANILLA)
	_place(t, 3, BOUNCY)
	t.play(3, 0, 1) # a timeout roll going right
	_check(t.board.get_owner(4, 0) == P, "bouncy: a rolling Goob bounces on its way")
	t = _with_special(TurnLoop.VANILLA)
	_place(t, 6, BOUNCY)
	t.play(6, 0, 1)
	_check(t.board.get_owner(5, 0) == P, "bouncy: no column that way, bounces back")
	# A Goob rolling onto a Bouncy bounces on; the bounce ends the roll.
	t = _with_special(LOPSIDED)
	_place(t, 2, BOUNCY)
	_place(t, 3)
	t.play(3, 0) # (3,1) rolls left onto Bouncy at (2,0), bounces left to (1,0)
	_check(t.goob_at(1, 0) == LOPSIDED and t.board.is_empty(0, 0), "bouncy: rolling Goob bounced left and stopped")


func _test_slippery() -> void:
	var t := _with_special(TurnLoop.VANILLA)
	_place(t, 3, SLIPPERY)
	t.play(3, 0)
	_check((t.board.get_owner(0, 0) == P) != (t.board.get_owner(6, 0) == P), "slippery: played Goob rolled to an edge")
	t = _with_special(FAT)
	_place(t, 3, SLIPPERY)
	t.play(3, 0)
	_check(t.last_effect["cell"].y == 0 and t.last_effect["cell"].x != 3, "slippery: the effect fires after the roll")
	# Can't move either way: it stays.
	t = _with_special(TurnLoop.VANILLA)
	_place(t, 3, SLIPPERY)
	for c in [2, 4]:
		_place(t, c)
		_place(t, c)
	t.play(3, 0)
	_check(t.board.get_owner(3, 1) == P and t.effect_steps[0]["kind"] == GoobDefinition.EffectType.NONE, "slippery: boxed in, stays, no move step")
	# Rolling Goobs passing over it just follow the roll rule (played only).
	t = _with_special(LOPSIDED)
	_place(t, 1)
	_place(t, 2, SLIPPERY)
	_place(t, 3)
	_place(t, 3)
	t.play(3, 0) # (3,2) rolls left over Slippery and on down to (0,0)
	_check(t.goob_at(0, 0) == LOPSIDED, "slippery: a rolling Goob keeps to the roll rule")


func _test_blustery() -> void:
	var t := _with_special(BLUSTERY)
	_place(t, 0)
	_place(t, 0)
	_place(t, 0, FAT) # (0,2): the highest Goob
	t.play(6, 0)
	_check(t.goob_at(5, 0) == FAT, "blustery: the highest Goob rolled right to Blustery")
	_check(t.board.is_empty(0, 2), "blustery: column 0 down to two")
	# Blustery can be the highest itself.
	t = _with_special(BLUSTERY)
	t.play(3, 0)
	_check(t.goob_at(0, 0) == BLUSTERY or t.goob_at(6, 0) == BLUSTERY, "blustery: rolled itself")
	# Nothing in the highest row can move: fizzle.
	t = _with_special(BLUSTERY)
	for c in BoardState.COLUMNS:
		if c != 3:
			_place(t, c)
	t.play(3, 0)
	_check(t.last_effect["fizzled"], "blustery: a full flat row fizzles")


func _test_springy() -> void:
	var t := _with_special(LOPSIDED)
	_place(t, 2, SPRINGY)
	_place(t, 2) # Springy's column is higher than the Lopsided
	t.play(4, 0) # rolls left from (4,0), hits Springy at (2,0)
	_check(t.goob_at(2, 2) == LOPSIDED, "springy: a higher column = bounced on top of it")
	_check(t.board.is_empty(3, 0) and t.board.is_empty(1, 0), "springy: the bounce ends the roll")
	# Level with it: bounces back and rolls on the other way (Sean, 2026-11-24).
	t = _with_special(LOPSIDED)
	_place(t, 2, SPRINGY)
	t.play(4, 0)
	_check(t.goob_at(6, 0) == LOPSIDED and t.board.is_empty(2, 1), "springy level: bounced back to the right edge")
	# Lower: it would roll onto the Springy, but bounces back instead.
	t = _with_special(LOPSIDED)
	_place(t, 3)
	_place(t, 2, SPRINGY)
	t.player_deck.hand[0] = LOPSIDED
	t.play(3, 0) # Lopsided at (3,1); column 2 is lower, topped by the Springy
	_check(t.board.is_empty(2, 1) and t.goob_at(6, 0) == LOPSIDED, "springy lower: bounces back instead of rolling onto it")
	# Springy's column full: rolls from the top into the first open column.
	t = _with_special(LOPSIDED)
	_place(t, 2, SPRINGY)
	for i in BoardState.ROWS - 1:
		_place(t, 2)
	t.play(4, 0)
	_check(t.goob_at(1, 0) == LOPSIDED, "springy full: rolled from the top into column 1")


func _test_fidgety() -> void:
	var t := _with_special(FIDGETY)
	_place(t, 5)
	t.play(3, 0)
	_check(t.last_effect["rolled"] == Vector2i(5, 0), "fidgety: picked the other Goob in its row")
	_check(t.goob_at(4, 0) == TurnLoop.VANILLA or t.goob_at(6, 0) == TurnLoop.VANILLA, "fidgety: it rolled")
	_check(t.goob_at(3, 0) == FIDGETY, "fidgety: never rolls itself")
	t = _with_special(FIDGETY)
	t.play(3, 0)
	_check(t.last_effect["fizzled"], "fidgety: alone in its row fizzles")


func _test_play_outcomes_moves() -> void:
	var b := BoardState.new()
	var goobs := {}
	b.drop(3, O)
	goobs[Vector2i(3, 0)] = SLIPPERY
	var outcomes := TurnLoop.play_outcomes(b, goobs, TurnLoop.VANILLA, 3, O)
	_check(outcomes.size() == 2, "outcomes: Slippery gives two (got %d)" % outcomes.size())
	var ends := []
	for o in outcomes:
		ends.append(o.get_owner(0, 0) == O)
	_check(ends.has(true) and ends.has(false), "outcomes: one rolls left, one right")
	_check(b.get_owner(3, 1) == E and goobs.size() == 1, "outcomes: input untouched")
	_check(TurnLoop.play_outcomes(b, {}, TurnLoop.VANILLA, 3, O).size() == 1, "outcomes: a plain board gives one")
	var fat_board := BoardState.new()
	fat_board.drop(0, P)
	fat_board.drop(2, P)
	_check(TurnLoop.play_outcomes(fat_board, {}, FAT, 1, O).size() == 2, "outcomes: Fat with two neighbours gives two")
	var hand: Array[GoobDefinition] = [TurnLoop.VANILLA]
	var move := OpponentAI.choose_move(b, hand, 0, _seeded(5), goobs)
	_check(move["column"] >= 0, "outcomes: AI chooses with board Goobs")


## Code review fixes (M6e Move) ------------------------------------------------

func _test_stacked_lopsided() -> void:
	var t := TurnLoop.new()
	_place(t, 1) # stops a floor roll at column 2
	_place(t, 3)
	_place(t, 3, LOPSIDED)
	_place(t, 3, LOPSIDED)
	t.destroy_at(Vector2i(3, 0))
	t._roll_fallen([Vector2i(3, 0), Vector2i(3, 1)] as Array[Vector2i])
	_check(t.goob_at(2, 0) == LOPSIDED, "stacked Lopsided: the lower one rolls to (2,0)")
	_check(t.goob_at(3, 0) == LOPSIDED, "stacked Lopsided: the upper one falls into the hole first, then is blocked")
	_check(t.board.is_empty(3, 1) and t.board.is_empty(2, 1), "stacked Lopsided: nothing left floating or rolled from row 1")


func _test_popular_on_bouncy() -> void:
	var t := TurnLoop.new()
	for c in 5:
		for r in BoardState.ROWS:
			_place(t, c)
	_place(t, 5, BOUNCY)
	t._scripted = true
	t._script = [0, 1] # Popular's column 5, then bounce right
	t.effect_steps = []
	t._resolve_effect(POPULAR, Vector2i(6, 0), O)
	_check(t.board.get_owner(6, 0) == O and t.goob_at(6, 0) == TurnLoop.VANILLA, "Popular on Bouncy: the extra Goob bounces to column 6")
	_check(t.board.is_empty(5, 1), "Popular on Bouncy: it leaves the Bouncy")
	_check(t.effect_steps.size() == 2 and t.effect_steps[1].get("instant", false), "Popular on Bouncy: an instant move step follows Popular's")


func _test_fall_onto_bouncy() -> void:
	var t := TurnLoop.new()
	_place(t, 2, BOUNCY)
	_place(t, 2)
	_place(t, 2, TurnLoop.VANILLA, P)
	t._scripted = true
	t._script = [1] # bounce right
	t.effect_steps = []
	t.destroy_at(Vector2i(2, 1))
	t._roll_fallen([Vector2i(2, 1)] as Array[Vector2i])
	_check(t.board.get_owner(3, 0) == P and t.board.is_empty(2, 1), "fall onto Bouncy: the fallen Goob bounces on")
	_check(t.effect_steps.size() == 1 and t.effect_steps[0]["kind"] == GoobDefinition.EffectType.BOUNCY and t.effect_steps[0].get("chain", false), "fall onto Bouncy: shown as a Bouncy chain step")
	# A Goob that falls together with the Bouncy under it stays put.
	var u := TurnLoop.new()
	_place(u, 2)
	_place(u, 2, BOUNCY)
	_place(u, 2, TurnLoop.VANILLA, P)
	u.destroy_at(Vector2i(2, 0))
	u._roll_fallen([Vector2i(2, 0), Vector2i(2, 1)] as Array[Vector2i])
	_check(u.board.get_owner(2, 1) == P and u.goob_at(2, 0) == BOUNCY, "fall with Bouncy: riding it down is not landing on it")


func _test_outcome_weights() -> void:
	# Blustery: (1,1) can roll both ways, (5,1) only left (Sean's tie = random).
	var b := BoardState.new()
	var goobs := {}
	for c: int in [1, 5, 6]:
		for r in 2:
			b.drop(c, O)
			goobs[Vector2i(c, r)] = TurnLoop.VANILLA
	var weights: Array = []
	for result in TurnLoop.play_results(b, goobs, BLUSTERY, 3, O):
		weights.append(result["weight"])
	weights.sort()
	_check(weights == [0.25, 0.25, 0.5], "weights: uneven picks give 1/4, 1/4, 1/2 (got %s)" % [weights])


func _test_threat_on_bouncy() -> void:
	var b := BoardState.new()
	var goobs := {}
	var row0 := [O, P, O, O]
	for c in 4:
		b.drop(c, row0[c])
		goobs[Vector2i(c, 0)] = BOUNCY if c == 3 else TurnLoop.VANILLA
	for c in 3:
		b.drop(c, P)
		goobs[Vector2i(c, 1)] = TurnLoop.VANILLA
	_check(OpponentAI.winning_drops(b, P).has(3), "threat: a plain board sees the win at (3,1)")
	_check(not OpponentAI.winning_drops(b, P, goobs).has(3), "threat: on a Bouncy the drop bounces away, no win")


## Slippery → Springy → over the full columns → back onto the same Slippery,
## two Goobs taking turns: the chain stops instead of looping, nothing floats.
func _test_chain_loop_stops() -> void:
	var t := TurnLoop.new()
	for c: int in [0, 1, 2, 4, 5, 6]:
		for r in BoardState.ROWS:
			_place(t, c, SPRINGY if r == 1 and (c == 2 or c == 4) else TurnLoop.VANILLA, P if (c + r) % 2 == 0 else O)
	_place(t, 3, SLIPPERY)
	_place(t, 3)
	_place(t, 3, TurnLoop.VANILLA, P)
	_place(t, 3, LOPSIDED, P)
	t.destroy_at(Vector2i(3, 1))
	t._roll_fallen([Vector2i(3, 1), Vector2i(3, 2)] as Array[Vector2i])
	_check(not t.board.is_empty(3, 2) and t.board.is_empty(3, 3), "chain loop: stops with column 3 packed (3 Goobs)")
	var gap := false
	for r in BoardState.ROWS:
		if t.board.is_empty(3, r):
			gap = true
		elif gap:
			_check(false, "chain loop: floating Goob at (3,%d)" % r)


# --- M6e Destroy (Sean, 2026-11-23: vault Special Goobs "M6e Destroy rules")

const VOLATILE := preload("res://resources/goobs/volatile_goob.tres")
const SPITEFUL := preload("res://resources/goobs/spiteful_goob.tres")
const OCCULT := preload("res://resources/goobs/occult_goob.tres")
const CRUSHING := preload("res://resources/goobs/crushing_goob.tres")
const BRAWLING := preload("res://resources/goobs/brawling_goob.tres")
const SMOULDERING := preload("res://resources/goobs/smouldering_goob.tres")


## The steps in `steps` with effect `kind`.
func _steps_of(steps: Array[Dictionary], kind: GoobDefinition.EffectType) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for step in steps:
		if step["kind"] == kind:
			found.append(step)
	return found


func _test_destroy_roster() -> void:
	var destroys := GoobRoster.specials(GoobDefinition.Category.DESTROY)
	_check(destroys.size() == 7, "destroy: seven destroy Goobs in the roster (got %d)" % destroys.size())
	for goob in destroys:
		_check(goob.multiplier == 2.0 and goob.display_name.ends_with(" Goob") and goob.effect_description != "", "destroy: %s is x2, named, has card text" % goob.id)
	_check(SPITEFUL.effect_description == "Destroy the next Goob that lands on this Goob.", "destroy: Spiteful card text")
	_check(BRAWLING.display_name == "Brawling Goob" and CRUSHING.display_name == "Crushing Goob" and SMOULDERING.display_name == "Smouldering Goob", "destroy: new names")


func _test_volatile() -> void:
	var t := _with_special(VOLATILE)
	_place(t, 0) # (0,0)
	t._scripted = true
	t._script = [1] # targets, column by column: (0,0), (3,0) = itself
	t.play(3, 0)
	_check(t.last_effect["target"] == Vector2i(3, 0) and t.board.is_empty(3, 0), "volatile: can destroy itself")
	_check(t.player_deck.destroyed_pile == [VOLATILE], "volatile: itself to your destroyed pile")
	_check(t.goob_at(0, 0) == TurnLoop.VANILLA, "volatile: the other Goob survives")
	t = _with_special(VOLATILE)
	_place(t, 0)
	t._scripted = true
	t._script = [0]
	t.play(3, 0)
	_check(t.board.is_empty(0, 0) and t.goob_at(3, 0) == VOLATILE, "volatile: or any other Goob")
	_check(t.opponent_deck.destroyed_pile == [TurnLoop.VANILLA], "volatile: opponent's Goob to his pile")


func _test_crushing() -> void:
	var t := _with_special(CRUSHING)
	_place(t, 2) # (2,0)
	_place(t, 2, FAT) # (2,1): crushed
	t.play(2, 0) # lands (2,2)
	_check(t.last_effect["target"] == Vector2i(2, 1), "crushing: destroys the Goob below")
	_check(t.goob_at(2, 1) == CRUSHING and t.board.is_empty(2, 2), "crushing: falls into its cell")
	_check(t.opponent_deck.destroyed_pile == [FAT], "crushing: Fat to his pile")
	_check(t.last_effect["fell"] == 1, "crushing: only itself fell")
	t = _with_special(CRUSHING)
	t.play(4, 0)
	_check(t.last_effect["fizzled"], "crushing: on the bottom row it fizzles")


func _test_brawling() -> void:
	var t := _with_special(BRAWLING)
	_place(t, 2) # (2,0): diagonal to it, not beside
	_place(t, 3) # (3,0): under it
	_place(t, 2) # (2,1): beside it
	t.play(3, 0) # lands (3,1)
	_check(t.last_effect["target"] == Vector2i(2, 1), "brawling: only one side has a Goob: that one")
	t = _with_special(BRAWLING)
	_place(t, 2)
	_place(t, 4, FAT)
	t._scripted = true
	t._script = [1] # left, right
	t.play(3, 0)
	_check(t.last_effect["target"] == Vector2i(4, 0) and t.goob_at(2, 0) == TurnLoop.VANILLA, "brawling: one side only")
	t = _with_special(BRAWLING)
	_place(t, 3)
	t.play(3, 0) # nothing beside (3,1)
	_check(t.last_effect["fizzled"], "brawling: nothing beside it fizzles")


func _test_spiteful() -> void:
	var t := _with_special(SPITEFUL)
	t.play(3, 0) # Spiteful at (3,0), armed for you
	_check(t.last_effect.get("passive", false) and t.armed_side(Vector2i(3, 0)) == P, "spiteful: armed for the player")
	_check(t.has_status(&"spiteful", P), "spiteful: pill while armed")
	t.play(3, 0) # opponent's Vanilla lands on it
	_check(t.board.is_empty(3, 1), "spiteful: the Goob that landed is destroyed")
	_check(t.opponent_deck.destroyed_pile == [TurnLoop.VANILLA], "spiteful: it goes to his pile")
	var hits := _steps_of(t.effect_steps, GoobDefinition.EffectType.DESTROY_LANDER)
	_check(hits.size() == 1 and hits[0]["target"] == Vector2i(3, 1) and hits[0]["cell"] == Vector2i(3, 0), "spiteful: a step from the Spiteful to the lander")
	_check(t.armed_side(Vector2i(3, 0)) == E and not t.has_status(&"spiteful", P), "spiteful: spent")
	_check(TurnLoop.base_of(t.goob_at(3, 0)) == SPITEFUL, "spiteful: still a Spiteful Goob")
	t.play(3, 0) # your next Goob stays
	_check(t.board.get_owner(3, 1) == P, "spiteful: acts only once")


func _test_spiteful_effect_fires() -> void:
	var t := _with_special(FAT)
	var spite := _place(t, 3, SPITEFUL)
	t._mark(spite, &"armed_by", O)
	_place(t, 2) # (2,0): Fat's target
	t._scripted = true
	t._script = [0] # Fat at (3,1): neighbour 0 = (2,0)
	t.play(3, 0)
	_check(t.board.is_empty(2, 0), "spiteful: the lander's effect still fires")
	_check(t.board.is_empty(3, 1), "spiteful: then the lander is destroyed")
	_check(t.player_deck.destroyed_pile == [FAT], "spiteful: the plain Fat goes to the pile (no marks)")
	_check(t.effect_steps[-1]["kind"] == GoobDefinition.EffectType.DESTROY_LANDER, "spiteful: its destroy comes after the effect")


func _test_spiteful_fall_and_roll() -> void:
	# Falling onto it: (3,1) is destroyed, (3,2) drops onto the Spiteful.
	var t := _with_special(VOLATILE)
	var spite := _place(t, 3, SPITEFUL)
	t._mark(spite, &"armed_by", O)
	_place(t, 3) # (3,1)
	_place(t, 3, FAT) # (3,2)
	t._scripted = true
	t._script = [2] # targets: (0,0) Volatile, (3,0), (3,1), (3,2)
	t.play(0, 0)
	_check(t.board.lowest_empty_row(3) == 1, "spiteful: a Goob falling onto it is destroyed")
	_check(t.opponent_deck.destroyed_pile.has(FAT), "spiteful: the fallen Fat went to the pile")
	# Rolling across it: a Lopsided rolls over it and on; it is still destroyed.
	t = _with_special(LOPSIDED)
	spite = _place(t, 3, SPITEFUL)
	t._mark(spite, &"armed_by", O)
	_place(t, 4) # (4,0)
	t.play(4, 0) # lands (4,1), rolls left over the Spiteful's top, down to (0,0)
	_check(t.board.is_empty(0, 0) and t.board.is_empty(4, 1), "spiteful: a Goob rolling across it is destroyed")
	_check(t.player_deck.destroyed_pile == [LOPSIDED], "spiteful: the Lopsided went to the pile")
	_check(t.armed_side(Vector2i(3, 0)) == E, "spiteful: spent by the roll")


func _test_spiteful_threat() -> void:
	# You have three in row 1; the fourth cell is on an armed Spiteful.
	var b := BoardState.new()
	var goobs := {}
	for c in 3:
		b.drop(c, O)
		b.drop(c, P)
	b.drop(3, O)
	var spite := SPITEFUL.duplicate() as GoobDefinition
	spite.set_meta(&"base", SPITEFUL)
	spite.set_meta(&"armed_by", O)
	goobs[Vector2i(3, 0)] = spite
	_check(OpponentAI.winning_drops(b, P, {}).has(3), "spiteful threat: without it, column 3 wins")
	_check(not OpponentAI.winning_drops(b, P, goobs).has(3), "spiteful threat: on an armed Spiteful it doesn't")


func _test_occult() -> void:
	var t := _with_special(OCCULT)
	t.player_deck.destroyed_pile.append(FAT)
	_place(t, 0) # (0,0): the returned Fat's target
	t._scripted = true
	t._script = [0, 1, 0] # pile 0 (Fat), open column 1, Fat's neighbour 0
	t.play(6, 0) # Occult at (6,0)
	var occult := _steps_of(t.effect_steps, GoobDefinition.EffectType.RESURRECT)
	_check(occult.size() == 1 and occult[0]["returned"] == FAT and occult[0]["extra"] == Vector2i(1, 0), "occult: Fat back in column 1")
	_check(t.last_effect == occult[0], "occult: its own step stays last_effect")
	_check(t.goob_at(1, 0) == FAT and t.board.get_owner(1, 0) == P, "occult: on your side")
	_check(t.board.is_empty(0, 0), "occult: the returned Goob's effect fired")
	_check(t.player_deck.destroyed_pile.is_empty(), "occult: taken off the pile")
	t = _with_special(OCCULT)
	t.play(3, 0)
	_check(t.last_effect["fizzled"], "occult: empty pile fizzles")


func _test_smouldering() -> void:
	var t := _with_special(SMOULDERING)
	t.play(3, 0) # Smouldering at (3,0), armed for you
	_check(t.has_status(&"smouldering", P), "smouldering: pill while pending")
	_check(t.turn_start_steps.is_empty(), "smouldering: not at his turn start")
	t.play(2, 0) # his Vanilla at (2,0)
	var steps := _steps_of(t.turn_start_steps, GoobDefinition.EffectType.DESTROY_LATER)
	_check(steps.size() == 1 and steps[0]["target"] == Vector2i(2, 0), "smouldering: at your turn start, destroys the adjacent Goob")
	_check(t.board.is_empty(2, 0) and _steps_of(t.effect_steps, GoobDefinition.EffectType.DESTROY_LATER).is_empty(), "smouldering: a turn-start step, not the play's")
	_check(not t.has_status(&"smouldering", P) and t.armed_side(Vector2i(3, 0)) == E, "smouldering: done")
	t.play(4, 0)
	t.play(4, 0)
	_check(_steps_of(t.turn_start_steps, GoobDefinition.EffectType.DESTROY_LATER).is_empty(), "smouldering: fires once")
	# Flipped to his side: it still fires at your turn start.
	t = _with_special(SMOULDERING)
	t.play(0, 0)
	t.board.set_owner(0, 0, O)
	t.play(6, 0)
	steps = _steps_of(t.turn_start_steps, GoobDefinition.EffectType.DESTROY_LATER)
	_check(steps.size() == 1 and steps[0]["fizzled"], "smouldering: still yours when flipped; no neighbour fizzles")


## Code review: a Goob falling farther than the Goob under it landed on it.
func _test_spiteful_two_gaps() -> void:
	var t := TurnLoop.new()
	_place(t, 3) # (3,0): lifted below
	_place(t, 3) # (3,1): A
	var spite := _place(t, 3, SPITEFUL) # (3,2)
	t._mark(spite, &"armed_by", O)
	_place(t, 3) # (3,3): lifted
	_place(t, 3, FAT) # (3,4): B
	t._lift(Vector2i(3, 0))
	t._lift(Vector2i(3, 3))
	t._apply_gravity() # A and the Spiteful fall 1, B falls 2 onto the Spiteful
	_check(TurnLoop.base_of(t.goob_at(3, 2)) == FAT and t.goob_at(3, 2).has_meta(&"doomed"), "two gaps: B landed on the Spiteful and is doomed")
	_check(t.armed_side(Vector2i(3, 1)) == E, "two gaps: the Spiteful is spent")


## Code review: the AI's simulation sees the destroyed piles (Occult).
func _test_occult_simulated() -> void:
	var b := BoardState.new()
	var piles := {O: [FAT] as Array[GoobDefinition]}
	var results := TurnLoop.play_results(b, {}, OCCULT, 3, O, 48, piles)
	var back := false
	for result in results:
		var count := 0
		for c in BoardState.COLUMNS:
			if not result["board"].is_empty(c, 0):
				count += 1
		back = back or count == 2
	_check(back, "occult sim: the returned Goob drops in the simulation")
	_check(piles[O].size() == 1, "occult sim: the real pile is untouched")


# --- M6e Discard (Sean, 2026-11-23: vault Special Goobs "M6e Discard rules")

const DISTRACTING := preload("res://resources/goobs/distracting_goob.tres")
const DEFIANT := preload("res://resources/goobs/defiant_goob.tres")
const FICKLE := preload("res://resources/goobs/fickle_goob.tres")
const RUTHLESS := preload("res://resources/goobs/ruthless_goob.tres")
const RECKLESS := preload("res://resources/goobs/reckless_goob.tres")
const THRIFTY := preload("res://resources/goobs/thrifty_goob.tres")
const DESPERATE := preload("res://resources/goobs/desperate_goob.tres")


## Player to move with exactly `hand` (all-Vanilla decks).
func _with_hand(hand: Array[GoobDefinition]) -> TurnLoop:
	var t := TurnLoop.new()
	t.start(true, _seeded(40), _vanilla())
	t.player_deck.hand = hand
	return t


func _goob_count(t: TurnLoop, owner: BoardState.CellOwner) -> int:
	var n := 0
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if t.board.get_owner(c, r) == owner:
				n += 1
	return n


func _discard_steps(t: TurnLoop) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for step in t.effect_steps:
		if step.has("discarded"):
			found.append(step)
	return found


func _test_discard_roster() -> void:
	var expected := {
		DISTRACTING: ["Distracting Goob", "Your opponent discards a random Goob."],
		DEFIANT: ["Defiant Goob", "If this Goob is discarded, play it instead."],
		FICKLE: ["Fickle Goob", "Discard a random Goob, then draw a Goob."],
		RUTHLESS: ["Ruthless Goob", "Discard 2 random Goobs, then destroy a random enemy Goob."],
		RECKLESS: ["Reckless Goob", "Discard your hand. Draw 2 extra Goobs on your next turn."],
		THRIFTY: ["Thrifty Goob", "Bring back one of your discarded Goobs."],
		DESPERATE: ["Desperate Goob", "Discard a random Goob, then destroy a random Goob."],
	}
	var ok := true
	for goob: GoobDefinition in expected:
		ok = ok and goob.display_name == expected[goob][0] and goob.effect_description == expected[goob][1]
		ok = ok and goob.multiplier == 2.0 and goob.category == GoobDefinition.Category.DISCARD
	_check(ok, "discard roster: names, card text, x2, DISCARD")
	var E_ := GoobDefinition.EffectType
	_check(DISTRACTING.effect_type == E_.DISCARD_ENEMY and DEFIANT.effect_type == E_.DEFIANT and FICKLE.effect_type == E_.DISCARD_DRAW
		and RUTHLESS.effect_type == E_.DISCARD_DESTROY_ENEMY and RECKLESS.effect_type == E_.DISCARD_HAND
		and THRIFTY.effect_type == E_.RETURN_DISCARD and DESPERATE.effect_type == E_.DISCARD_DESTROY, "discard roster: effect types")
	_check(GoobRoster.specials(GoobDefinition.Category.DISCARD).size() == 7, "discard roster: 7 in the roster")


func _test_distracting() -> void:
	var t := _with_hand([DISTRACTING, TurnLoop.VANILLA] as Array[GoobDefinition])
	var theirs := t.opponent_deck.hand.size()
	t.play(3, 0)
	_check(t.opponent_deck.discard_pile.size() == 1, "distracting: one opponent Goob discarded")
	_check(t.opponent_deck.hand.size() == theirs - 1 + 1, "distracting: their hand lost one (then their turn draw)")
	var steps := _discard_steps(t)
	_check(steps.size() == 1 and steps[0]["side"] == O and t.effect_steps[0].get("cue", false), "distracting: cue step, then the discard step")
	var e := _with_hand([DISTRACTING] as Array[GoobDefinition])
	e.opponent_deck.hand.clear()
	e.play(3, 0)
	_check(e.last_effect["fizzled"] and e.opponent_deck.discard_pile.is_empty(), "distracting: an empty enemy hand fizzles")


func _test_defiant() -> void:
	var t := _with_hand([DISTRACTING] as Array[GoobDefinition])
	t.opponent_deck.hand = [DEFIANT] as Array[GoobDefinition]
	t.play(3, 0)
	var steps := _discard_steps(t)
	_check(steps.size() == 1 and steps[0].has("played"), "defiant: discarded, it is played instead")
	var at: Vector2i = steps[0]["played"]
	_check(t.board.get_owner(at.x, at.y) == O and TurnLoop.base_of(t.goob_at(at.x, at.y)) == DEFIANT, "defiant: drops for its owner")
	_check(t.opponent_deck.discard_pile.is_empty(), "defiant: not in the discard pile")
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.DISCARD_ENEMY, "defiant: last_effect stays the Distracting step")
	# Board full but for the cell Distracting takes: it goes to the pile.
	var f := _with_hand([DISTRACTING] as Array[GoobDefinition])
	f.opponent_deck.hand = [DEFIANT] as Array[GoobDefinition]
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			if c != 3 or r < BoardState.ROWS - 1:
				_place(f, c, TurnLoop.VANILLA, P if (c + r) % 3 == 0 else O)
	f.play(3, 0)
	_check(f.opponent_deck.discard_pile == [DEFIANT], "defiant: board full, it goes to the pile")
	# Played normally it does nothing.
	var n := _with_hand([DEFIANT, TurnLoop.VANILLA] as Array[GoobDefinition])
	n.play(3, 0)
	_check(n.last_effect.get("passive", false) and _discard_steps(n).is_empty(), "defiant: played, no effect")


func _test_fickle() -> void:
	var t := _with_hand([FICKLE, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	var pile := t.player_deck.draw_pile.size()
	t.play(3, 0)
	_check(t.player_deck.discard_pile.size() == 1 and t.player_deck.hand.size() == 2, "fickle: discard 1, draw 1")
	_check(t.player_deck.draw_pile.size() == pile - 1, "fickle: drew from the deck")
	var last: Dictionary = t.effect_steps[-1]
	var discards := _discard_steps(t)
	_check(last.has("drawn") and last["drawn"].size() == 1 and discards.size() == 1 and t.effect_steps.find(discards[0]) < t.effect_steps.size() - 1, "fickle: the draw step comes after the discard")
	var e := _with_hand([FICKLE] as Array[GoobDefinition])
	var before := e.player_deck.draw_pile.size()
	e.play(3, 0)
	_check(e.last_effect["fizzled"] and e.player_deck.hand.is_empty() and e.player_deck.draw_pile.size() == before, "fickle: empty hand fizzles, no draw")


func _test_ruthless() -> void:
	var t := _with_hand([RUTHLESS, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, O)
	_place(t, 1, TurnLoop.VANILLA, P)
	t.play(6, 0)
	_check(t.player_deck.discard_pile.size() == 2 and t.player_deck.hand.is_empty(), "ruthless: discards 2")
	_check(t.board.is_empty(0, 0) and t.board.get_owner(1, 0) == P, "ruthless: destroys the enemy Goob, not yours")
	_check(t.last_effect.get("target") == Vector2i(0, 0) and t.opponent_deck.destroyed_pile.size() == 1, "ruthless: last_effect is the destroy")
	var one := _with_hand([RUTHLESS, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(one, 0, TurnLoop.VANILLA, O)
	one.play(6, 0)
	_check(one.last_effect["fizzled"] and one.player_deck.discard_pile.is_empty() and one.board.get_owner(0, 0) == O, "ruthless: only one Goob in hand fizzles, nothing discarded")
	var none := _with_hand([RUTHLESS, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	none.play(6, 0)
	_check(none.last_effect["fizzled"] and none.player_deck.discard_pile.is_empty(), "ruthless: no enemy Goob fizzles, nothing discarded")


func _test_ruthless_defiant() -> void:
	var t := _with_hand([RUTHLESS, DEFIANT, DEFIANT] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, O)
	t.play(6, 0)
	_check(t.player_deck.discard_pile.is_empty(), "ruthless + defiant: both Defiants played instead")
	_check(_goob_count(t, P) == 3 and _goob_count(t, O) == 0, "ruthless + defiant: two Defiants on the board, the enemy destroyed")
	var steps := _discard_steps(t)
	var hit := _steps_of(t.effect_steps, GoobDefinition.EffectType.DISCARD_DESTROY_ENEMY)
	_check(steps.size() == 2 and t.effect_steps.find(steps[1]) < t.effect_steps.find(hit[-1]), "ruthless + defiant: the drops come before the destroy")


func _test_reckless() -> void:
	var t := _with_hand([RECKLESS, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0)
	_check(t.player_deck.hand.is_empty() and t.player_deck.discard_pile.size() == 2, "reckless: discards the hand")
	_check(t.has_status(&"reckless", P), "reckless: pill while pending")
	var idx := _discard_steps(t)
	_check(idx.size() == 2 and idx[0]["index"] == 1 and idx[1]["index"] == 0, "reckless: discards from the end (fan indices stay valid)")
	t.play(0, 0) # opponent
	_check(t.player_deck.hand.size() == 3 and t.last_draw.size() == 3, "reckless: draws 3 on your next turn")
	_check(not t.has_status(&"reckless", P), "reckless: pill gone after the draw")
	t.play(1, 0)
	t.play(2, 0)
	_check(t.last_draw.size() == 1, "reckless: only once")
	var e := _with_hand([RECKLESS] as Array[GoobDefinition])
	e.play(3, 0)
	_check(not e.last_effect["fizzled"] and e.has_status(&"reckless", P), "reckless: empty hand still gets the +2")
	e.play(0, 0)
	_check(e.player_deck.hand.size() == 3 and e.phase == TurnLoop.Phase.PLAYER_TURN, "reckless: no skip, 3 drawn")
	var cap := _with_hand([RECKLESS] as Array[GoobDefinition])
	cap.play(3, 0)
	cap.player_deck.hand = [] as Array[GoobDefinition]
	while cap.player_deck.hand.size() < Deck.HAND_MAX - 1:
		cap.player_deck.hand.append(TurnLoop.VANILLA) # 1 + 2 bonus draws, room for 1
	cap.play(0, 0)
	_check(cap.player_deck.hand.size() == Deck.HAND_MAX and cap.last_draw_hand_full, "reckless: the hand cap still applies")


func _test_thrifty() -> void:
	var t := _with_hand([THRIFTY, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.player_deck.discard_pile = [TurnLoop.VANILLA] as Array[GoobDefinition]
	t.play(3, 0)
	_check(t.player_deck.discard_pile.is_empty() and _goob_count(t, P) == 2, "thrifty: the discarded Goob drops for you")
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.RETURN_DISCARD and t.last_effect.has("returned") and t.last_effect.has("extra"), "thrifty: step names the Goob and where it went")
	var e := _with_hand([THRIFTY] as Array[GoobDefinition])
	e.player_deck.destroyed_pile = [TurnLoop.VANILLA] as Array[GoobDefinition]
	e.play(3, 0)
	_check(e.last_effect["fizzled"] and _goob_count(e, P) == 1, "thrifty: empty discard pile fizzles (destroyed pile doesn't count)")


func _test_desperate() -> void:
	var t := _with_hand([DESPERATE, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, P)
	t.play(6, 0)
	_check(t.board.is_empty(0, 0) and t.board.get_owner(6, 0) == P, "desperate: destroys another Goob (yours too), never itself")
	_check(t.player_deck.discard_pile.size() == 1 and t.player_deck.hand.size() == 1, "desperate: discards 1")
	var e := _with_hand([DESPERATE, TurnLoop.VANILLA] as Array[GoobDefinition])
	e.play(6, 0)
	_check(e.last_effect["fizzled"] and e.player_deck.discard_pile.is_empty() and e.board.get_owner(6, 0) == P, "desperate: alone on the board fizzles, nothing discarded")
	var h := _with_hand([DESPERATE] as Array[GoobDefinition])
	_place(h, 0, TurnLoop.VANILLA, O)
	h.play(6, 0)
	_check(h.last_effect["fizzled"] and h.board.get_owner(0, 0) == O, "desperate: empty hand fizzles")


## The AI's simulation uses its hand (sim_state): Ruthless destroys there.
func _test_discard_simulated() -> void:
	var b := BoardState.new()
	b.drop(0, P)
	var hand := [RUTHLESS, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition]
	var state := {"hands": {O: hand, P: [] as Array[GoobDefinition]}}
	var hit := true
	for result in TurnLoop.play_results(b, {Vector2i(0, 0): TurnLoop.VANILLA}, RUTHLESS, 6, O, 48, {}, state):
		hit = hit and result["board"].is_empty(0, 0)
	_check(hit, "discard sim: Ruthless destroys in the simulation")
	_check(hand.size() == 3, "discard sim: the real hand is untouched")
	var t := TurnLoop.new()
	t.start(false, _seeded(41), _vanilla())
	var seen := t.sim_state()
	_check(seen["hands"][O].size() == t.opponent_deck.hand.size() and seen["hands"][P].size() == t.player_deck.hand.size(), "discard sim: hand sizes")
	var plain := true
	for g in seen["hands"][P]:
		plain = plain and g == TurnLoop.VANILLA
	_check(plain, "discard sim: your hand is hidden from the AI (plain Goobs)")


# --- M6e Draw -------------------------------------------------------------------

const JINXING := preload("res://resources/goobs/jinxing_goob.tres")
const GENEROUS := preload("res://resources/goobs/generous_goob.tres")
const PLENTIFUL := preload("res://resources/goobs/plentiful_goob.tres")


func _test_draw_roster() -> void:
	var expected := {
		GREEDY: ["Greedy Goob", "Draw 2 Goobs.", "vanilla"],
		JINXING: ["Jinxing Goob", "Your opponent skips their next draw.", "vanilla"],
		GENEROUS: ["Generous Goob", "While on the board, draw an extra Goob each turn.", "vanilla"],
		PLENTIFUL: ["Plentiful Goob", "While on the board, you draw a Goob whenever your opponent draws one.", "plentiful"],
	}
	var draws := GoobRoster.specials(GoobDefinition.Category.DRAW)
	_check(draws.size() == 4, "draw: four draw Goobs in the roster (got %d)" % draws.size())
	for goob: GoobDefinition in expected:
		_check(goob in draws and goob.multiplier == 2.0, "draw: %s is x2 in the roster" % goob.id)
		_check(goob.display_name == expected[goob][0] and goob.effect_description == expected[goob][1] and goob.art_id == expected[goob][2], "draw: %s name, card text, art" % goob.id)


func _test_jinxing() -> void:
	var t := _with_hand([JINXING, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	var hand := t.opponent_deck.hand.size()
	var pile := t.opponent_deck.draw_pile.size()
	t.play(3, 0)
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.JINX and t.last_effect.get("cue", false), "jinxing: winds up")
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN and t.last_draw.is_empty(), "jinxing: his turn draw is skipped")
	_check(t.opponent_deck.hand.size() == hand and t.opponent_deck.draw_pile.size() == pile, "jinxing: the Goob stays on top of his deck")
	_check(t.last_jinx_lost == 1 and t.last_draw_count == 0, "jinxing: the view gets the no-draw toast")
	_check(t.has_status(&"jinxed", O), "jinxing: pill stays through his jinxed turn")
	t.play(0, 0)
	_check(not t.has_status(&"jinxed", O), "jinxing: pill gone after his turn")
	t.play(4, 0)
	_check(t.last_draw.size() == 1 and t.last_jinx_lost == 0, "jinxing: only his next draw")
	var e := _with_hand([JINXING, TurnLoop.VANILLA] as Array[GoobDefinition])
	e.opponent_deck.draw_pile.clear()
	e.play(3, 0)
	_check(e.last_effect["fizzled"] and not e.has_status(&"jinxed", O), "jinxing: his empty deck fizzles")


func _test_jinxing_adds_up_and_forced_draw() -> void:
	var t := _with_hand([JINXING, TurnLoop.VANILLA] as Array[GoobDefinition])
	t._jinxes[O] = 1 # a Jinxing already on him
	t._bonus_draws[O] = 2 # Reckless: 3 without the jinxes
	t.play(3, 0)
	_check(t.last_draw.size() == 1 and t.last_jinx_lost == 2 and t.last_draw_count == 1, "jinxing: two add up on one turn (3 - 2)")
	var f := _with_hand([JINXING, TurnLoop.VANILLA] as Array[GoobDefinition])
	f._skipped_last[O] = true
	f.play(3, 0)
	_check(f.last_draw.size() == 1 and f.last_jinx_lost == 0, "jinxing: a forced draw after a skip wins")
	_check(not f._jinxes.has(O), "jinxing: the forced draw uses up the jinx")
	var short := _with_hand([JINXING, TurnLoop.VANILLA] as Array[GoobDefinition])
	short._bonus_draws[O] = 1 # 2 without the jinx...
	short.opponent_deck.draw_pile.resize(1) # ...but only 1 left in his deck
	short.play(3, 0)
	_check(short.last_draw.size() == 1 and short.last_jinx_lost == 0, "jinxing: no toast when the deck allowed no more anyway")


func _test_jinxing_skips_empty_hand() -> void:
	var t := _with_hand([JINXING, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.opponent_deck.hand.clear()
	t.play(3, 0)
	_check(t.phase == TurnLoop.Phase.PLAYER_TURN and O in t.last_skipped, "jinxing: empty hand and no draw skips his turn")
	t.play(4, 0)
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN and t.last_draw.size() == 1, "jinxing: his next turn draws (never skipped twice)")


func _test_generous() -> void:
	var t := _with_hand([GENEROUS, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0)
	_check(t.last_effect.get("passive", false) and t.has_status(&"generous", P), "generous: passive, pill while on the board")
	_check(t.last_draw.size() == 1, "generous: his draw is unchanged")
	t.play(0, 0)
	_check(t.last_draw.size() == 2, "generous: your turn draw is 2")
	t.board.set_owner(3, 0, O) # flipped (Convincing)
	t.play(4, 0)
	_check(t.last_draw.size() == 2 and t.has_status(&"generous", O) and not t.has_status(&"generous", P), "generous: the bonus goes with the owner")
	t.play(0, 0)
	_check(t.last_draw.size() == 1, "generous: yours again 1")


func _test_plentiful() -> void:
	var t := _with_hand([PLENTIFUL, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.opponent_deck.hand[0] = GREEDY
	t.play(3, 0)
	_check(t.has_status(&"plentiful", P), "plentiful: pill while on the board")
	_check(t.turn_draw_steps.size() == 1 and t.turn_draw_steps[0]["side"] == P and t.turn_draw_steps[0]["drawn"].size() == 1, "plentiful: his turn draw gives you one")
	_check(t.player_deck.hand.size() == 3, "plentiful: your hand 2 + 1")
	while t.player_deck.hand.size() < Deck.HAND_MAX - 2:
		t.player_deck.hand.append(TurnLoop.VANILLA) # his 2 echo in, then your turn draw hits the cap
	t.play(0, 0) # his Greedy draws 2
	var echo: Array = t.effect_steps.filter(func(st: Dictionary) -> bool: return st["kind"] == GoobDefinition.EffectType.DRAW_ECHO)
	_check(echo.size() == 1 and echo[0]["drawn"].size() == 2, "plentiful: his Greedy gives you two")
	_check(t.effect_steps.find(echo[0]) > t.effect_steps.find(t.last_effect), "plentiful: right after his draw")
	_check(t.player_deck.hand.size() == Deck.HAND_MAX and t.last_draw_hand_full and t.turn_draw_steps.is_empty(), "plentiful: hand cap; your own draws don't trigger it")
	var full := _with_hand([TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(full, 6, PLENTIFUL, P)
	full.opponent_deck.hand[0] = GREEDY
	full.play(3, 0)
	full.player_deck.hand.resize(Deck.HAND_MAX)
	full.player_deck.hand.fill(TurnLoop.VANILLA)
	full.play(0, 0) # his Greedy while your hand is full
	var silent := full.effect_steps.all(func(st: Dictionary) -> bool: return st["kind"] != GoobDefinition.EffectType.DRAW_ECHO)
	_check(silent and full.player_deck.hand.size() == Deck.HAND_MAX, "plentiful: a full hand draws nothing, silently (no step)")


func _test_plentiful_no_loop() -> void:
	var t := _with_hand([PLENTIFUL, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 6, PLENTIFUL, O)
	var his := t.opponent_deck.hand.size()
	t.play(3, 0) # his turn draw: yours echoes, his doesn't answer it
	_check(t.turn_draw_steps.size() == 1 and t.turn_draw_steps[0]["side"] == P, "plentiful: no loop between two Plentifuls")
	_check(t.opponent_deck.hand.size() == his + 1, "plentiful: he drew only his turn draw")
	t.play(0, 0) # your turn draw: his echoes
	_check(t.turn_draw_steps.size() == 1 and t.turn_draw_steps[0]["side"] == O, "plentiful: his Plentiful answers your draw")


# --- M6e Tech (Sean, 2026-11-24: vault Special Goobs "M6e Tech rules") ------

const STEADFAST := preload("res://resources/goobs/steadfast_goob.tres")
const LOYAL := preload("res://resources/goobs/loyal_goob.tres")
const STALWART := preload("res://resources/goobs/stalwart_goob.tres")
const TERRITORIAL := preload("res://resources/goobs/territorial_goob.tres")
const INSPIRING := preload("res://resources/goobs/inspiring_goob.tres")
const STIFLING := preload("res://resources/goobs/stifling_goob.tres")
const THIEVING := preload("res://resources/goobs/thieving_goob.tres")
const HOARDING := preload("res://resources/goobs/hoarding_goob.tres")


func _test_tech_roster() -> void:
	var expected := {
		STEADFAST: ["Steadfast Goob", "Your Goobs can't be moved next turn."],
		LOYAL: ["Loyal Goob", "Your Goobs can't be destroyed next turn."],
		STALWART: ["Stalwart Goob", "This Goob can't be destroyed or moved."],
		TERRITORIAL: ["Territorial Goob", "Your opponent can't play in this column next turn."],
		INSPIRING: ["Inspiring Goob", "Trigger a random adjacent friendly Goob's effect again."],
		STIFLING: ["Stifling Goob", "Your opponent's next Goob has no effect."],
		THIEVING: ["Thieving Goob", "Steal a random enemy Goob's ongoing effect."],
		HOARDING: ["Hoarding Goob", "While on the board, your Goobs can't be discarded."],
	}
	var techs := GoobRoster.specials(GoobDefinition.Category.TECH)
	_check(techs.size() == 8, "tech: eight tech Goobs in the roster (got %d)" % techs.size())
	for goob: GoobDefinition in expected:
		_check(goob in techs and goob.multiplier == 2.0 and goob.art_id == "vanilla", "tech: %s is x2, Vanilla art, in the roster" % goob.id)
		_check(goob.display_name == expected[goob][0] and goob.effect_description == expected[goob][1], "tech: %s name and card text" % goob.id)


func _test_steadfast() -> void:
	var t := _with_hand([STEADFAST, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 2, TurnLoop.VANILLA, P)
	t.play(3, 0) # Steadfast at (3,0)
	_check(t.last_effect.get("cue", false) and t.has_status(&"steadfast", P), "steadfast: winds up, pill")
	t.opponent_deck.hand[0] = SINISTER
	t.play(4, 0) # his Sinister at (4,0) pushes your row left
	_check(t.board.get_owner(2, 0) == P and t.board.get_owner(3, 0) == P and t.last_effect["fizzled"], "steadfast: your Goobs can't be pushed on his turn")
	_check(not t.has_status(&"steadfast", P), "steadfast: the window ends with his turn")
	var b := _with_hand([STEADFAST, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(b, 5, BOUNCY, O)
	b.play(3, 0)
	b.play(0, 0) # his turn
	b.player_deck.hand[0] = TurnLoop.VANILLA
	b._protect(P, GoobDefinition.EffectType.STEADFAST)
	b.play(5, 0) # your Goob onto his Bouncy
	_check(b.board.get_owner(5, 1) == P, "steadfast: your Goob landing on a Bouncy stays on top")


func _test_loyal() -> void:
	var t := _with_hand([LOYAL, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0) # Loyal at (3,0)
	_check(t.has_status(&"loyal", P), "loyal: pill")
	t.opponent_deck.hand[0] = FAT
	t.play(4, 0) # his Fat: (3,0) is its only neighbour
	_check(t.board.get_owner(3, 0) == P and t.last_effect["fizzled"] and t.last_effect["target"] == Vector2i(3, 0), "loyal: a protected target wastes the destroy")
	_check(not t.has_status(&"loyal", P), "loyal: the window ends with his turn")


func _test_stalwart() -> void:
	var s := _with_hand([SINISTER, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(s, 1, STALWART, O)
	_place(s, 2, TurnLoop.VANILLA, O)
	s.play(3, 0) # Sinister at (3,0)
	_check(s.board.get_owner(1, 0) == O and s.board.get_owner(2, 0) == O and s.last_effect["fizzled"], "stalwart: can't be pushed, and walls the Goob behind it")
	var f := _with_hand([FAT, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(f, 2, STALWART, O)
	f.play(3, 0) # Fat at (3,0): only the Stalwart beside it
	_check(f.board.get_owner(2, 0) == O and f.last_effect["fizzled"], "stalwart: can't be destroyed")
	var g := _with_hand([TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(g, 4)
	_place(g, 4, STALWART)
	g.destroy_at(Vector2i(4, 0))
	_check(TurnLoop.base_of(g.goob_at(4, 0)) == STALWART and g.board.is_empty(4, 1), "stalwart: falls when the Goob below goes")


func _test_territorial() -> void:
	var t := _with_hand([TERRITORIAL, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0) # Territorial at (3,0): column 3 locked for him
	_check(t.phase == TurnLoop.Phase.OPPONENT_TURN and t.column_blocked(3) and not t.can_play(3), "territorial: he can't play in its column")
	_check(t.locked_columns(O).size() == 1 and t.locked_columns(O)[0] == 3 and t.has_status(&"territorial", O), "territorial: locked column + pill on his side")
	_check(t.roll_target(3, true) == 4, "territorial: at his timeout the locked column counts as full")
	_check(t.play(3, 0) == -1 and t.phase == TurnLoop.Phase.OPPONENT_TURN, "territorial: his play there is refused")
	t.play(2, 0)
	_check(t.locked_columns(O).is_empty() and not t.has_status(&"territorial", O), "territorial: only for his next turn")
	var lift := _with_hand([TERRITORIAL, TurnLoop.VANILLA] as Array[GoobDefinition])
	lift.play(3, 0)
	for c in [0, 1, 2, 4, 5, 6]:
		while not lift.board.column_full(c):
			lift.board.drop(c, P if (lift.board.lowest_empty_row(c) + c) % 3 == 0 else O)
	_check(lift.can_play(3), "territorial: every other column full lifts the lock")


func _test_inspiring() -> void:
	var t := _with_hand([INSPIRING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 4, FAT, P)
	_place(t, 5, TurnLoop.VANILLA, O)
	t._scripted = true
	t._script = [0, 1] # Inspiring picks the Fat; the Fat picks (5,0)
	t.play(3, 0)
	_check(t.last_effect["kind"] == GoobDefinition.EffectType.INSPIRE and t.last_effect["inspired"] == Vector2i(4, 0), "inspiring: picks the adjacent friendly Fat")
	var fat := _steps_of(t.effect_steps, GoobDefinition.EffectType.DESTROY_ADJACENT)
	_check(fat.size() == 1 and fat[0]["cell"] == Vector2i(4, 0) and fat[0]["side"] == P and t.board.is_empty(5, 0), "inspiring: the Fat destroys again, for you, from its cell")
	var e := _with_hand([INSPIRING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(e, 2, TurnLoop.VANILLA, P)
	_place(e, 4, FAT, O)
	_place(e, 5, BOUNCY, P)
	e.play(3, 0)
	_check(e.last_effect["fizzled"], "inspiring: plain, enemy and passive Goobs are skipped (fizzle)")


func _test_stifling() -> void:
	var t := _with_hand([STIFLING, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0)
	_check(t.last_effect.get("cue", false) and t.has_status(&"stifled", O), "stifling: winds up, pill on his side")
	t.opponent_deck.hand[0] = FAT
	t.play(4, 0) # his Fat beside your Stifling
	_check(t.last_effect["fizzled"] and t.last_effect.get("stifled", false) and t.board.get_owner(3, 0) == P, "stifling: his next Goob has no effect")
	_check(not t.has_status(&"stifled", O), "stifling: used up")
	t.play(0, 0)
	t.opponent_deck.hand[0] = FAT
	t.play(4, 0)
	_check(not t.last_effect.get("stifled", false), "stifling: only one Goob")
	var v := _with_hand([STIFLING, TurnLoop.VANILLA] as Array[GoobDefinition])
	v.play(3, 0)
	v.play(5, 0) # his plain Goob uses it up
	_check(not v.has_status(&"stifled", O) and not v._stifles.has(O), "stifling: a plain Goob wastes it")


func _test_thieving() -> void:
	var t := _with_hand([THIEVING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 5, BOUNCY, O)
	t.play(3, 0)
	_check(t.last_effect["stolen_from"] == Vector2i(5, 0), "thieving: steals the Bouncy")
	_check(t.goob_at(5, 0).effect_type == GoobDefinition.EffectType.NONE and t.goob_at(3, 0).effect_type == GoobDefinition.EffectType.BOUNCY, "thieving: the Bouncy turns plain, the thief bounces")
	_check(TurnLoop.base_of(t.goob_at(3, 0)) == THIEVING and TurnLoop.base_of(t.goob_at(5, 0)) == BOUNCY, "thieving: both keep their type")
	var s := _with_hand([THIEVING, TurnLoop.VANILLA] as Array[GoobDefinition])
	var spite := _place(s, 5, SPITEFUL, O)
	s._mark(spite, &"armed_by", O)
	s.play(3, 0)
	_check(s.armed_side(Vector2i(3, 0)) == P and s.armed_side(spite) == E, "thieving: an armed Spiteful's curse now acts for you")
	var g := _with_hand([THIEVING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(g, 5, GENEROUS, O)
	g.play(3, 0)
	_check(g.has_status(&"generous", P) and not g.has_status(&"generous", O), "thieving: a stolen Generous gives you the bonus")
	var u := _with_hand([THIEVING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(u, 5, SPITEFUL, O) # spent (not armed)
	_place(u, 6, FAT, O) # nothing ongoing
	u.play(3, 0)
	_check(u.last_effect["fizzled"], "thieving: nothing ongoing to steal fizzles")


func _test_hoarding() -> void:
	var t := _with_hand([TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 6, HOARDING, P)
	t.opponent_deck.hand[0] = DISTRACTING
	t.play(3, 0)
	_check(t.has_status(&"hoarding", P), "hoarding: pill")
	t.play(4, 0) # his Distracting
	_check(t.last_effect["fizzled"] and t.player_deck.discard_pile.is_empty(), "hoarding: his discard fizzles")
	var f := _with_hand([FICKLE, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(f, 6, HOARDING, P)
	f.play(3, 0)
	_check(f.last_effect["fizzled"] and f.player_deck.discard_pile.is_empty(), "hoarding: your own discard cost can't be paid")
	var r := _with_hand([RECKLESS, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(r, 6, HOARDING, P)
	r.play(3, 0)
	_check(r.last_effect["fizzled"] and not r._bonus_draws.has(P) and r.player_deck.hand.size() == 1, "hoarding: Reckless discards nothing, no +2")


func _test_tech_simulated() -> void:
	var t := _with_hand([TERRITORIAL, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, P)
	_place(t, 1, TurnLoop.VANILLA, P)
	_place(t, 2, TurnLoop.VANILLA, O)
	_place(t, 0, TurnLoop.VANILLA, O)
	_place(t, 1, TurnLoop.VANILLA, O)
	_place(t, 2, TurnLoop.VANILLA, O) # his three on row 1; (3,1) wins
	t.play(3, 0) # Territorial at (3,0) locks column 3
	var hand: Array[GoobDefinition] = [TurnLoop.VANILLA]
	var move := OpponentAI.choose_move(t.board, hand, 5, _seeded(3), t.cell_goobs(), t.destroyed_piles(), t.sim_state())
	_check(move["column"] != 3 and move["column"] != -1, "tech AI: never plays into a locked column")
	var b := BoardState.new()
	var goobs := {}
	b.drop(3, P)
	goobs[Vector2i(3, 0)] = TurnLoop.VANILLA
	var results := TurnLoop.play_results(b, goobs, FAT, 4, O, 48, {}, {"stifles": {O: 1}})
	_check(results.size() == 1 and results[0]["board"].get_owner(3, 0) == P, "tech AI: a stifled Fat is simulated with no effect")
	var state := {"hands": {P: [TurnLoop.VANILLA], O: []}}
	b.drop(6, P)
	goobs[Vector2i(6, 0)] = HOARDING
	_check(OpponentAI._hand_value(b, DISTRACTING, 1, 5, state, goobs) == 0.0, "tech AI: Distracting is worth nothing against your Hoarding")
	var stifled := {"stifles": {O: 1}}
	var gen := OpponentAI._play_value(b, GENEROUS, 0, 2, 5, goobs, {}, stifled)
	var van := OpponentAI._play_value(b, TurnLoop.VANILLA, 0, 2, 5, goobs, {}, stifled)
	_check(gen > van, "tech AI: a stifled Generous still counts its ongoing bonus")


# --- M6e Uniquely powerful (Sean, 2026-11-24) ---

const SEISMIC := preload("res://resources/goobs/seismic_goob.tres")
const SINKING := preload("res://resources/goobs/sinking_goob.tres")
const ROWDY := preload("res://resources/goobs/rowdy_goob.tres")
const NOSTALGIC := preload("res://resources/goobs/nostalgic_goob.tres")
const MOCKING := preload("res://resources/goobs/mocking_goob.tres")


func _test_unique_roster() -> void:
	var expected := {
		SEISMIC: ["Seismic Goob", "Shift every Goob one column left or right."],
		SINKING: ["Sinking Goob", "The bottom row falls out."],
		ROWDY: ["Rowdy Goob", "The top Goob of every column bounces."],
		NOSTALGIC: ["Nostalgic Goob", "Copy the last Goob you played."],
		MOCKING: ["Mocking Goob", "Copy the last Goob your opponent played."],
	}
	var uniques := GoobRoster.specials(GoobDefinition.Category.UNIQUE)
	_check(uniques.size() == 7 and CONVINCING in uniques and POPULAR in uniques, "unique: seven Goobs incl. Convincing and Popular (got %d)" % uniques.size())
	for goob: GoobDefinition in expected:
		_check(goob in uniques and goob.multiplier == 2.0 and goob.art_id == "vanilla", "unique: %s is x2, Vanilla art, in the roster" % goob.id)
		_check(goob.display_name == expected[goob][0] and goob.effect_description == expected[goob][1], "unique: %s name and card text" % goob.id)


func _test_seismic() -> void:
	var t := _with_hand([SEISMIC, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, P)
	_place(t, 1, FAT, O)
	_place(t, 2, TurnLoop.VANILLA, O)
	t._scripted = true
	t._script = [0] # left
	t.play(4, 0) # Seismic at (4,0)
	var step := t.last_effect
	_check(step["kind"] == GoobDefinition.EffectType.SHIFT and step["dir"] == -1 and not step["fizzled"], "seismic: shifts left")
	_check(t.board.get_owner(0, 0) == O and TurnLoop.base_of(t.goob_at(0, 0)) == FAT and t.board.get_owner(1, 0) == O and t.board.get_owner(3, 0) == P and t.board.is_empty(4, 0), "seismic: every Goob moves one column, itself included")
	_check(step["fallen"].size() == 1 and step["fallen"][0]["owner"] == P and t.player_deck.destroyed_pile.size() == 1, "seismic: the edge Goob falls off and is destroyed")
	var gone: Array = step["motions"].filter(func(m: Dictionary) -> bool: return m.get("gone", false))
	_check(gone.size() == 1 and gone[0]["to"] == Vector2i(-1, 0), "seismic: its motion leaves the board")
	# Walls: a Stalwart stays and stops the Goob behind it; gravity after.
	var w := _with_hand([SEISMIC, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(w, 1, STALWART, O)
	_place(w, 1, TurnLoop.VANILLA, P) # (1,1) on the Stalwart
	_place(w, 2, TurnLoop.VANILLA, O)
	w._scripted = true
	w._script = [0]
	w.play(5, 0) # Seismic at (5,0)
	_check(TurnLoop.base_of(w.goob_at(1, 0)) == STALWART and w.board.get_owner(2, 0) == O, "seismic: a Stalwart stays and walls the Goob behind it")
	_check(w.board.get_owner(0, 0) == P and w.board.is_empty(1, 1) and w.board.get_owner(4, 0) == P, "seismic: the Goob above slides off the Stalwart and falls")
	# Loyal at the edge: it doesn't fall off.
	var l := _with_hand([SEISMIC, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(l, 6, TurnLoop.VANILLA, O)
	l._protect(O, GoobDefinition.EffectType.LOYAL)
	l._scripted = true
	l._script = [1] # right
	l.play(5, 0) # Seismic at (5,0)
	_check(l.board.get_owner(6, 0) == O and l.board.get_owner(5, 0) == P and l.last_effect["fizzled"], "seismic: a Loyal Goob at the edge stays and blocks its row")


func _test_sinking() -> void:
	var t := _with_hand([SINKING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, O)
	_place(t, 0, TurnLoop.VANILLA, P) # (0,1)
	_place(t, 2, TurnLoop.VANILLA, O)
	t.play(4, 0) # Sinking at (4,0)
	_check(t.board.get_owner(0, 0) == P and t.board.is_empty(0, 1), "sinking: the Goobs above fall one row")
	_check(t.board.is_empty(2, 0) and t.board.is_empty(4, 0), "sinking: the bottom row is gone, itself included")
	_check(t.opponent_deck.destroyed_pile.size() == 2 and TurnLoop.base_of(t.player_deck.destroyed_pile[0]) == SINKING, "sinking: they are destroyed (piles)")
	var l := _with_hand([SINKING, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(l, 1, STALWART, O)
	_place(l, 1, TurnLoop.VANILLA, O) # (1,1) on the Stalwart
	_place(l, 3, TurnLoop.VANILLA, P)
	l._protect(P, GoobDefinition.EffectType.LOYAL)
	l.play(5, 0)
	_check(l.board.get_owner(1, 1) == O and l.board.get_owner(3, 0) == P and l.board.get_owner(5, 0) == P and l.last_effect["fizzled"], "sinking: protected Goobs stay with what stands on them; all protected = fizzle")


func _test_rowdy() -> void:
	var t := _with_hand([ROWDY, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(t, 0, TurnLoop.VANILLA, O)
	t._scripted = true
	t._script = [0, 0] # column 0: inward (only choice); Rowdy: left
	t.play(3, 0) # Rowdy at (3,0)
	_check(t.board.get_owner(1, 0) == O and t.board.get_owner(2, 0) == P and t.board.is_empty(0, 0) and t.board.is_empty(3, 0), "rowdy: each top Goob bounces one column, left to right")
	_check(not t.goob_at(1, 0).has_meta(&"rowdy") and not t.goob_at(2, 0).has_meta(&"rowdy"), "rowdy: no marks left behind")
	var s := _with_hand([ROWDY, TurnLoop.VANILLA] as Array[GoobDefinition])
	_place(s, 0, TurnLoop.VANILLA, O)
	_place(s, 2, TurnLoop.VANILLA, O)
	s._scripted = true
	s._script = [0, 1, 1] # (0,0) right onto column 1; (2,0) right; Rowdy right
	s.play(4, 0)
	_check(s.board.get_owner(1, 0) == O and s.board.get_owner(3, 0) == O and s.board.get_owner(5, 0) == P, "rowdy: a Goob moved by it isn't bounced again")
	var f := _with_hand([ROWDY, TurnLoop.VANILLA] as Array[GoobDefinition])
	f._protect(P, GoobDefinition.EffectType.STEADFAST)
	f.play(3, 0)
	_check(f.last_effect["fizzled"] and f.board.get_owner(3, 0) == P, "rowdy: nothing can move = fizzle")


func _test_nostalgic() -> void:
	var t := _with_hand([NOSTALGIC, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(3, 0)
	_check(t.last_effect["fizzled"] and t.goob_at(3, 0).effect_type == GoobDefinition.EffectType.NONE, "nostalgic: no earlier play = a plain Goob")
	_check(not t.goob_at(3, 0).is_special() and t.goob_at(3, 0).ring_texture(P) == null, "nostalgic: copying a plain Goob looks plain (M6f)")
	var f := _with_hand([FAT, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	f.play(3, 0) # Fat at (3,0), no neighbour
	f.play(0, 0) # his
	f.player_deck.hand[0] = NOSTALGIC
	f.play(4, 0) # Nostalgic at (4,0): becomes Fat, destroys (3,0)
	var copy := _steps_of(f.effect_steps, GoobDefinition.EffectType.COPY_OWN)
	_check(copy.size() == 1 and copy[0]["copied"] == "Fat Goob", "nostalgic: copies your last played Goob")
	_check(f.board.is_empty(3, 0) and f.goob_at(3, 0) == null or f.board.get_owner(3, 0) == E, "nostalgic: the copied Fat destroys")
	_check(f.goob_at(4, 0).effect_type == GoobDefinition.EffectType.DESTROY_ADJACENT and TurnLoop.base_of(f.goob_at(4, 0)) == NOSTALGIC, "nostalgic: becomes it, keeps its own type")
	_check(f._last_played[P] == FAT, "nostalgic: counts as what it became")
	var looks := f.goob_at(4, 0)
	_check(looks.ring_family() == GoobDefinition.Category.DESTROY and looks.is_special() and not looks.is_legendary(), "nostalgic: wears the copied Fat's ring, no glint (M6f)")
	f.play(1, 0) # his
	f.player_deck.hand[0] = NOSTALGIC
	f.play(6, 0)
	var again := _steps_of(f.effect_steps, GoobDefinition.EffectType.COPY_OWN)
	_check(again.size() == 1 and again[0]["copied"] == "Fat Goob", "nostalgic: copying a Nostalgic copies what it became")


## M6f (Sean, 2026-11-24): family rings, legendary, sparkles.
func _test_m6f_looks() -> void:
	var g := func(id: String) -> GoobDefinition: return load("res://resources/goobs/%s_goob.tres" % id)
	_check(not TurnLoop.VANILLA.is_special() and TurnLoop.VANILLA.ring_texture(P) == null, "looks: a plain Goob has no ring")
	var rings := {"fickle": GoobDefinition.Category.DISCARD, "fat": GoobDefinition.Category.DESTROY, "greedy": GoobDefinition.Category.DRAW,
		"sinister": GoobDefinition.Category.MOVE, "stalwart": GoobDefinition.Category.TECH, "seismic": GoobDefinition.Category.MOVE,
		"rowdy": GoobDefinition.Category.MOVE, "sinking": GoobDefinition.Category.DESTROY, "convincing": GoobDefinition.Category.TECH,
		"popular": GoobDefinition.Category.DRAW, "nostalgic": GoobDefinition.Category.TECH, "mocking": GoobDefinition.Category.TECH}
	for id: String in rings:
		var goob: GoobDefinition = g.call(id)
		_check(goob.ring_family() == rings[id] and goob.ring_texture(O) != null, "looks: %s wears the %s ring" % [id, rings[id]])
		_check(goob.is_legendary() == (goob.category == GoobDefinition.Category.UNIQUE), "looks: %s legendary only if Uniquely powerful" % id)
	var sparkles := {"bouncy": &"chevrons", "springy": &"chevrons", "slippery": &"crackle", "lopsided": &"crackle_left", "tipsy": &"crackle_right",
		"generous": &"motes", "plentiful": &"motes", "stalwart": &"stars", "hoarding": &"stars", "steadfast": &"steadfast", "loyal": &"loyal",
		"spiteful": &"", "fat": &"", "defiant": &""}
	for id: String in sparkles:
		_check((g.call(id) as GoobDefinition).sparkle() == sparkles[id], "looks: %s sparkle %s" % [id, sparkles[id]])
	var armed: GoobDefinition = (g.call("smouldering") as GoobDefinition).duplicate()
	armed.set_meta(&"armed_by", P)
	_check(armed.sparkle() == &"embers", "looks: an armed Smouldering has embers")


func _test_mocking() -> void:
	var t := _with_hand([TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	t.play(0, 0)
	t.opponent_deck.hand[0] = BOUNCY
	t.play(6, 0) # his Bouncy
	t.player_deck.hand[0] = MOCKING
	t.play(3, 0) # Mocking at (3,0): becomes a Bouncy
	_check(t.goob_at(3, 0).effect_type == GoobDefinition.EffectType.BOUNCY and t.board.get_owner(3, 0) == P, "mocking: becomes his last Goob, on your side")
	_check(t.goob_at(3, 0).effect_description.begins_with("Copied Bouncy Goob"), "mocking: inspect says what it copied")
	t._scripted = true
	t._script = [1]
	t.play(3, 0) # his Goob lands on it and bounces right
	_check(t.board.get_owner(4, 0) == O and t.board.is_empty(3, 1), "mocking: keeps the passive for good")
	var d := _with_hand([TurnLoop.VANILLA, TurnLoop.VANILLA, TurnLoop.VANILLA] as Array[GoobDefinition])
	d.play(0, 0)
	d.opponent_deck.hand[0] = DISTRACTING
	d.play(6, 0) # his Distracting: you discard one
	d.player_deck.hand[0] = MOCKING
	d.play(3, 0)
	var discards: Array = d.effect_steps.filter(func(st: Dictionary) -> bool: return st.has("discarded") and st["side"] == O)
	_check(discards.size() == 1 and d.opponent_deck.discard_pile.size() == 1, "mocking: a copied Distracting makes him discard")


func _test_unique_simulated() -> void:
	var b := BoardState.new()
	var goobs := {}
	b.drop(0, P)
	goobs[Vector2i(0, 0)] = TurnLoop.VANILLA
	var results := TurnLoop.play_results(b, goobs, SEISMIC, 3, O)
	_check(results.size() == 2, "unique AI: Seismic's two directions are simulated (got %d)" % results.size())
	var copied := TurnLoop.play_results(b, goobs, NOSTALGIC, 1, O, 48, {}, {"last_played": {O: FAT}})
	_check(copied.size() == 1 and copied[0]["board"].is_empty(0, 0), "unique AI: Nostalgic simulates the Goob it becomes")
	var state := {"last_played": {O: GENEROUS}}
	var nos := OpponentAI._play_value(b, NOSTALGIC, 4, 2, 5, goobs, {}, state)
	var van := OpponentAI._play_value(b, TurnLoop.VANILLA, 4, 2, 5, goobs, {}, state)
	_check(nos > van, "unique AI: a Nostalgic copying Generous gets Generous's value")
