class_name OpponentAI
extends RefCounted
## M3 opponent rule: take a winning column if one exists, else block the
## player's winning column, else pick a random legal column. Ties among
## winning/blocking columns resolve to the lowest column index. M6 replaces
## this with human-like logic. Stateless; `rng` is injected for determinism.


## Returns a non-full column 0-6, or -1 if every column is full.
## Does not mutate `board`.
static func choose_column(board: BoardState, rng: RandomNumberGenerator) -> int:
	var legal: Array[int] = []
	for column in BoardState.COLUMNS:
		if not board.column_full(column):
			legal.append(column)
	if legal.is_empty():
		return -1
	for column in legal:
		if _wins(board, column, BoardState.CellOwner.OPPONENT, BoardState.Outcome.OPPONENT_WIN):
			return column
	for column in legal:
		if _wins(board, column, BoardState.CellOwner.PLAYER, BoardState.Outcome.PLAYER_WIN):
			return column
	return legal[rng.randi_range(0, legal.size() - 1)]


static func _wins(board: BoardState, column: int, side: BoardState.CellOwner, expected: BoardState.Outcome) -> bool:
	var trial := board.copy()
	trial.drop(column, side)
	return trial.get_outcome() == expected
