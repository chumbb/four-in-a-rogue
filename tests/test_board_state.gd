extends SceneTree
## Headless BoardState tests.
## Run: godot --headless -s res://tests/test_board_state.gd
## Exits 0 on pass, 1 on any failure.

const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT
const E := BoardState.CellOwner.EMPTY

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_empty_board()
	_test_drop_gravity()
	_test_full_column()
	_test_invalid_columns()
	_test_horizontal_win()
	_test_vertical_win()
	_test_diagonal_up_win()
	_test_diagonal_down_win()
	_test_three_is_not_win()
	_test_mixed_line_is_not_win()
	_test_opponent_win()
	_test_run_of_five()
	_test_destroy_and_set()
	_test_board_full()
	_test_outcomes()

	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _test_empty_board() -> void:
	var b := BoardState.new()
	for c in BoardState.COLUMNS:
		_check(b.lowest_empty_row(c) == 0, "empty board col %d lowest row 0" % c)
		_check(not b.column_full(c), "empty board col %d not full" % c)
	_check(b.find_winner() == E, "empty board has no winner")


func _test_drop_gravity() -> void:
	var b := BoardState.new()
	_check(b.drop(3, P) == 0, "first drop lands row 0")
	_check(b.drop(3, O) == 1, "second drop stacks to row 1")
	_check(b.get_owner(3, 0) == P and b.get_owner(3, 1) == O, "owners stored")
	_check(b.drop(4, O) == 0, "other column independent")


func _test_full_column() -> void:
	var b := BoardState.new()
	for i in BoardState.ROWS:
		_check(b.drop(0, P if i % 2 == 0 else O) == i, "fill row %d" % i)
	_check(b.column_full(0), "column full after 6")
	_check(b.drop(0, P) == -1, "drop into full column returns -1")
	_check(b.get_owner(0, 5) == O, "full-column drop did not overwrite top")


func _test_invalid_columns() -> void:
	var b := BoardState.new()
	_check(b.drop(-1, P) == -1, "column -1 rejected")
	_check(b.drop(7, P) == -1, "column 7 rejected")
	_check(b.column_full(7), "out-of-range column reports full")


func _test_horizontal_win() -> void:
	var b := BoardState.new()
	for c in [1, 2, 3]:
		b.drop(c, P)
	_check(b.find_winner() == E, "three horizontal no win")
	b.drop(4, P)
	_check(b.find_winner() == P, "four horizontal wins")
	var line := b.find_winning_line(P)
	_check(line == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "horizontal line cells: %s" % str(line))


func _test_vertical_win() -> void:
	var b := BoardState.new()
	b.drop(6, O)
	for i in 4:
		b.drop(6, P)
	_check(b.find_winner() == P, "four vertical wins")
	_check(b.find_winning_line(P)[0] == Vector2i(6, 1), "vertical line starts above opponent piece")


func _test_diagonal_up_win() -> void:
	# P at (0,0) (1,1) (2,2) (3,3)
	var b := BoardState.new()
	b.drop(0, P)
	b.drop(1, O); b.drop(1, P)
	b.drop(2, O); b.drop(2, O); b.drop(2, P)
	b.drop(3, O); b.drop(3, O); b.drop(3, O)
	_check(b.find_winner() == E, "diag up incomplete")
	b.drop(3, P)
	_check(b.find_winner() == P, "diag up wins")


func _test_diagonal_down_win() -> void:
	# P at (3,3) (4,2) (5,1) (6,0)
	var b := BoardState.new()
	b.set_owner(3, 0, O); b.set_owner(3, 1, O); b.set_owner(3, 2, O); b.set_owner(3, 3, P)
	b.set_owner(4, 0, O); b.set_owner(4, 1, O); b.set_owner(4, 2, P)
	b.set_owner(5, 0, O); b.set_owner(5, 1, P)
	b.set_owner(6, 0, P)
	_check(b.find_winner() == P, "diag down wins")


func _test_three_is_not_win() -> void:
	var b := BoardState.new()
	for i in 3:
		b.drop(2, O)
	_check(b.find_winner() == E, "three vertical no win")


func _test_mixed_line_is_not_win() -> void:
	var b := BoardState.new()
	b.drop(0, P); b.drop(1, P); b.drop(2, O); b.drop(3, P); b.drop(4, P)
	_check(b.find_winner() == E, "interrupted horizontal no win")


func _test_opponent_win() -> void:
	var b := BoardState.new()
	for c in [3, 4, 5, 6]:
		b.drop(c, O)
	_check(b.find_winner() == O, "opponent four wins")
	_check(b.find_winning_line(P).is_empty(), "player has no line")


func _test_run_of_five() -> void:
	var b := BoardState.new()
	for c in 5:
		b.drop(c, P)
	_check(b.find_all_winning_lines(P).size() == 2, "run of five yields two lines of four")


func _test_destroy_and_set() -> void:
	var b := BoardState.new()
	b.drop(2, P); b.drop(2, O); b.drop(2, P)
	_check(b.destroy_cell(2, 0), "destroy bottom in bounds")
	_check(b.get_owner(2, 0) == O and b.get_owner(2, 1) == P and b.get_owner(2, 2) == E, "pieces above fall one row")
	_check(b.lowest_empty_row(2) == 2, "column has no gap after destroy")
	_check(b.destroy_cell(2, 1), "destroy top piece")
	_check(b.get_owner(2, 0) == O and b.get_owner(2, 1) == E, "destroying top leaves rest in place")
	_check(not b.destroy_cell(2, 3), "destroy empty cell rejected")
	_check(not b.destroy_cell(9, 0), "destroy out of bounds rejected")
	_check(b.get_owner(3, 0) == E, "other columns untouched")
	# Full column: destroy middle, top row empties.
	for i in BoardState.ROWS:
		b.drop(5, P if i % 2 == 0 else O)
	b.destroy_cell(5, 2)
	_check(b.get_owner(5, 5) == E and not b.column_full(5), "full column reopens after destroy")
	_check(b.get_owner(5, 2) == O and b.get_owner(5, 4) == O, "middle destroy shifts upper pieces down")
	# A fall can complete a line: win check happens after effects.
	var w := BoardState.new()
	for c in [0, 1, 2]:
		w.drop(c, P)
	w.drop(3, O); w.drop(3, P)
	_check(w.find_winner() == E, "no four before destroy")
	w.destroy_cell(3, 0)
	_check(w.find_winner() == P, "fallen piece completes four")
	b.set_owner(2, 0, P)
	_check(b.get_owner(2, 0) == P, "set_owner flips")
	_check(not b.set_owner(9, 9, P), "set_owner out of bounds rejected")


func _test_board_full() -> void:
	var b := BoardState.new()
	_check(not b.is_board_full(), "empty board not full")
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			b.drop(c, P if (c + r) % 2 == 0 else O)
	_check(b.is_board_full(), "board full after 42 drops")


func _test_outcomes() -> void:
	const Outcome := BoardState.Outcome
	var b := BoardState.new()
	_check(b.get_outcome() == Outcome.NONE, "empty board outcome NONE")
	for c in 4:
		b.drop(c, P)
	_check(b.get_outcome() == Outcome.PLAYER_WIN, "player four → PLAYER_WIN")
	var o := BoardState.new()
	for i in 4:
		o.drop(6, O)
	_check(o.get_outcome() == Outcome.OPPONENT_WIN, "opponent four → OPPONENT_WIN")
	# Both sides have four (as an effect could cause) → draw, no winner.
	for i in 4:
		b.drop(6, O)
	_check(b.get_outcome() == Outcome.DRAW, "both fours → DRAW")
	_check(b.find_winner() == E, "find_winner names nobody on mutual four")
