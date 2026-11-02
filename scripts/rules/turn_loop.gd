class_name TurnLoop
extends RefCounted
## Alternating-turn rules for one scenario. Owns the BoardState; no rendering.

enum Phase {
	PLAYER_TURN,
	OPPONENT_TURN,
	OVER,
}

## DRAW covers both a mutual four and a full board with no four.
enum Result {
	NONE,
	PLAYER_WIN,
	OPPONENT_WIN,
	DRAW,
}

var board: BoardState
var phase: Phase = Phase.PLAYER_TURN
var result: Result = Result.NONE


func _init() -> void:
	board = BoardState.new()


func start(player_first: bool) -> void:
	board.reset()
	result = Result.NONE
	phase = Phase.PLAYER_TURN if player_first else Phase.OPPONENT_TURN


func current_side() -> BoardState.CellOwner:
	match phase:
		Phase.PLAYER_TURN:
			return BoardState.CellOwner.PLAYER
		Phase.OPPONENT_TURN:
			return BoardState.CellOwner.OPPONENT
	return BoardState.CellOwner.EMPTY


func can_play(column: int) -> bool:
	return phase != Phase.OVER and board.is_valid_column(column) and not board.column_full(column)


## Drops for the current side. Returns the landed row, or -1 with no state
## change if the move is not allowed.
func play(column: int) -> int:
	if not can_play(column):
		return -1
	var row := board.drop(column, current_side())
	match board.get_outcome():
		BoardState.Outcome.PLAYER_WIN:
			_finish(Result.PLAYER_WIN)
		BoardState.Outcome.OPPONENT_WIN:
			_finish(Result.OPPONENT_WIN)
		BoardState.Outcome.DRAW:
			_finish(Result.DRAW)
		_:
			if board.is_board_full():
				_finish(Result.DRAW)
			elif phase == Phase.PLAYER_TURN:
				phase = Phase.OPPONENT_TURN
			else:
				phase = Phase.PLAYER_TURN
	return row


func _finish(r: Result) -> void:
	result = r
	phase = Phase.OVER
