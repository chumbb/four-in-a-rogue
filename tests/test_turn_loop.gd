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
