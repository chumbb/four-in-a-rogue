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
	_test_random_spread()
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
	var b := BoardState.new()
	for c in [1, 2, 3]:
		b.drop(c, P)
	b.drop(6, O)
	for s in range(1, 6):
		_check(OpponentAI.choose_column(b, _rng(s)) == 0, "blocks at lowest index (seed %d)" % s)


func _test_random_is_legal() -> void:
	var b := BoardState.new()
	for c in 6:
		_fill_column(b, c)
	_check(b.get_outcome() == BoardState.Outcome.NONE, "random: filled cols have no four")
	for s in range(1, 21):
		_check(OpponentAI.choose_column(b, _rng(s)) == 6, "only legal column is 6 (seed %d)" % s)


func _test_random_spread() -> void:
	var seen := {}
	for s in range(1, 51):
		var col := OpponentAI.choose_column(BoardState.new(), _rng(s))
		_check(col >= 0 and col <= 6, "empty board result in range (seed %d)" % s)
		seen[col] = true
	_check(seen.size() >= 3, "random spread covers at least 3 columns (got %d)" % seen.size())


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
