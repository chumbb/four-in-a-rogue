extends SceneTree
## Headless BoardState.copy + OpponentAI tests.
## Run: godot --headless -s res://tests/test_opponent_ai.gd
## Exits 0 on pass, 1 on any failure.

const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_copy_is_independent()
	_test_takes_win()
	_test_win_beats_block()
	_test_blocks_player()
	_test_random_is_legal()
	_test_opens_centre()
	_test_blocks_single_end()
	_test_avoids_playing_under_player_win()
	_test_flip_to_win()
	_test_saves_specials()
	_test_plays_plentiful_with_room()
	_test_blocking_flag()
	_test_open_threes()
	_test_full_board_returns_minus_one()
	_test_does_not_mutate()

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


func _fill_column(board: BoardState, column: int) -> void:
	for row in BoardState.ROWS:
		board.drop(column, _fill_owner(column, row))


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _test_copy_is_independent() -> void:
	var a := BoardState.new()
	a.drop(0, P)
	var b := a.copy()
	b.drop(1, O)
	_check(a.is_empty(1, 0), "copy: original untouched by drop on copy")
	_check(b.get_owner(0, 0) == P, "copy: copy carries original cells")
	_check(b.get_owner(1, 0) == O, "copy: copy has its own drop")
	a.drop(2, O)
	_check(b.is_empty(2, 0), "copy: copy untouched by drop on original")


func _test_takes_win() -> void:
	var b := BoardState.new()
	for c in 3:
		b.drop(c, O)
	for c in 3:
		b.drop(c, P)
	_check(OpponentAI.choose_column(b, _rng(1)) == 3, "takes the winning column")


func _test_win_beats_block() -> void:
	var b := BoardState.new()
	for i in 3:
		b.drop(6, O)
	for c in 3:
		b.drop(c, P)
	_check(OpponentAI.choose_column(b, _rng(1)) == 6, "win beats block")


func _test_blocks_player() -> void:
	# Open three on the bottom row: both ends lose, so either end is fine.
	var b := BoardState.new()
	for c in [1, 2, 3]:
		b.drop(c, P)
	b.drop(6, O)
	for s in range(1, 6):
		var col := OpponentAI.choose_column(b, _rng(s))
		_check(col == 0 or col == 4, "blocks an end of an open three (seed %d, got %d)" % [s, col])


func _test_random_is_legal() -> void:
	var b := BoardState.new()
	for c in 6:
		_fill_column(b, c)
	_check(b.get_outcome() == BoardState.Outcome.NONE, "random: filled cols have no four")
	for s in range(1, 21):
		_check(OpponentAI.choose_column(b, _rng(s)) == 6, "only legal column is 6 (seed %d)" % s)


func _test_opens_centre() -> void:
	for s in range(1, 11):
		_check(OpponentAI.choose_column(BoardState.new(), _rng(s)) == 3, "empty board: opens in the centre (seed %d)" % s)


func _test_blocks_single_end() -> void:
	var b := BoardState.new()
	for c in [0, 1, 2]:
		b.drop(c, P)
	b.drop(6, O)
	b.drop(6, O)
	for s in range(1, 6):
		_check(OpponentAI.choose_column(b, _rng(s)) == 3, "blocks the only winning cell (seed %d)" % s)


func _test_avoids_playing_under_player_win() -> void:
	# Player three on row 1 (cols 1-3); its winning cells (0,1) and (4,1)
	# open only once someone drops into columns 0 or 4.
	var b := BoardState.new()
	b.drop(1, P)
	b.drop(2, O)
	b.drop(3, P)
	for c in [1, 2, 3]:
		b.drop(c, P)
	for s in range(1, 11):
		var col := OpponentAI.choose_column(b, _rng(s))
		_check(col != 0 and col != 4, "never plays under the player's winning cell (seed %d, got %d)" % [s, col])


func _hand(goobs: Array) -> Array[GoobDefinition]:
	var hand: Array[GoobDefinition] = []
	for g: GoobDefinition in goobs:
		hand.append(g)
	return hand


func _test_flip_to_win() -> void:
	var b := BoardState.new()
	b.drop(0, O)
	b.drop(1, O)
	b.drop(2, P)
	var convincing: GoobDefinition = load("res://resources/goobs/convincing_goob.tres")
	var move := OpponentAI.choose_move(b, _hand([TurnLoop.VANILLA, convincing]), 10, _rng(1))
	_check(move["hand_index"] == 1 and move["column"] == 3, "plays Convincing to flip into a four (got %s)" % move)


func _test_saves_specials() -> void:
	var convincing: GoobDefinition = load("res://resources/goobs/convincing_goob.tres")
	var fat: GoobDefinition = load("res://resources/goobs/fat_goob.tres")
	for s in range(1, 6):
		var move := OpponentAI.choose_move(BoardState.new(), _hand([convincing, fat, TurnLoop.VANILLA]), 10, _rng(s))
		_check(move["hand_index"] == 2, "empty board: plays Vanilla, saves specials (seed %d)" % s)


func _test_plays_plentiful_with_room() -> void:
	var plentiful: GoobDefinition = load("res://resources/goobs/plentiful_goob.tres")
	var move := OpponentAI.choose_move(BoardState.new(), _hand([TurnLoop.VANILLA, plentiful]), 10, _rng(1))
	_check(move["hand_index"] == 1, "plays Plentiful when the hand has room")
	move = OpponentAI.choose_move(BoardState.new(), _hand([TurnLoop.VANILLA, plentiful]), 0, _rng(1))
	_check(move["hand_index"] == 0, "empty deck: Plentiful gains nothing, Vanilla instead")


func _test_blocking_flag() -> void:
	var b := BoardState.new()
	for c in [0, 1, 2]:
		b.drop(c, P)
	var move := OpponentAI.choose_move(b, _hand([TurnLoop.VANILLA]), 5, _rng(1))
	_check(move["blocking"], "blocking flag set when the player threatens four")
	move = OpponentAI.choose_move(BoardState.new(), _hand([TurnLoop.VANILLA]), 5, _rng(1))
	_check(not move["blocking"], "no blocking flag on an empty board")


func _test_open_threes() -> void:
	var b := BoardState.new()
	for c in [0, 1, 2]:
		b.drop(c, O)
	_check(OpponentAI.open_threes(b, O) == 1, "three with an open fourth counts")
	b.drop(3, P)
	_check(OpponentAI.open_threes(b, O) == 0, "three with a blocked fourth does not")
	var t := BoardState.new()
	t.drop(0, O)
	t.drop(1, O)
	_check(OpponentAI.open_lines(t, O, 2) == 1, "an open two counts (one window: columns 0-3)")
	t.drop(2, P)
	_check(OpponentAI.open_lines(t, O, 2) == 0, "a blocked two does not")
	var gap := BoardState.new()
	gap.drop(0, O)
	gap.drop(2, O)
	_check(OpponentAI.open_lines(gap, O, 2) == 1, "O_O_ is an open two")
	_check(OpponentAI.open_lines(gap, O, 2, true) == 0, "but not a side-by-side pair")
	_check(OpponentAI.open_lines(t, O, 2, true) == 0 and OpponentAI.open_lines(gap, O, 3) == 0, "touching pairs: blocked still 0")


func _test_full_board_returns_minus_one() -> void:
	var b := BoardState.new()
	for c in BoardState.COLUMNS:
		_fill_column(b, c)
	_check(b.is_board_full(), "full board is full")
	_check(OpponentAI.choose_column(b, _rng(1)) == -1, "full board returns -1")


func _test_does_not_mutate() -> void:
	var b := BoardState.new()
	for c in [1, 2, 3]:
		b.drop(c, P)
	b.drop(6, O)
	var before := b.to_debug_string()
	OpponentAI.choose_column(b, _rng(1))
	_check(b.to_debug_string() == before, "choose_column does not mutate board")
