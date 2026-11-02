class_name BoardState
extends RefCounted
## 7×6 Connect 4 grid — logic source of truth (handoff §3.1). No rendering here.
##
## Coordinates: column 0..6 left→right, row 0..5 bottom→top.
## Gravity pulls toward row 0.

const COLUMNS := 7
const ROWS := 6
const CONNECT := 4

enum CellOwner {
	EMPTY,
	PLAYER,
	OPPONENT,
}

## Line directions checked for four-in-a-row: horizontal, vertical, both diagonals.
const _DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(1, -1),
]

var _cells: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	_cells.clear()
	for _row in ROWS:
		var row: Array = []
		row.resize(COLUMNS)
		row.fill(CellOwner.EMPTY)
		_cells.append(row)


# --- Queries ---------------------------------------------------------------

func is_empty(column: int, row: int) -> bool:
	return get_owner(column, row) == CellOwner.EMPTY


func get_owner(column: int, row: int) -> CellOwner:
	if not in_bounds(column, row):
		return CellOwner.EMPTY
	return _cells[row][column] as CellOwner


func in_bounds(column: int, row: int) -> bool:
	return column >= 0 and column < COLUMNS and row >= 0 and row < ROWS


func is_valid_column(column: int) -> bool:
	return column >= 0 and column < COLUMNS


## Lowest empty row in a column, or -1 if the column is full / out of range.
func lowest_empty_row(column: int) -> int:
	if not is_valid_column(column):
		return -1
	for row in ROWS:
		if _cells[row][column] == CellOwner.EMPTY:
			return row
	return -1


func column_full(column: int) -> bool:
	return lowest_empty_row(column) == -1


func is_board_full() -> bool:
	for column in COLUMNS:
		if not column_full(column):
			return false
	return true


# --- Mutations -------------------------------------------------------------

## Drops a Goob for `owner` into `column`. Returns the landed row, or -1 if the
## column is full, out of range, or `owner` is EMPTY.
func drop(column: int, owner: CellOwner) -> int:
	if owner == CellOwner.EMPTY:
		push_error("BoardState.drop: owner must be PLAYER or OPPONENT")
		return -1
	var row := lowest_empty_row(column)
	if row == -1:
		return -1
	_cells[row][column] = owner
	return row


## Direct cell write for effects (M5: flip). Does not apply gravity.
func set_owner(column: int, row: int, owner: CellOwner) -> bool:
	if not in_bounds(column, row):
		return false
	_cells[row][column] = owner
	return true


## Destroys the Goob at (column, row) (M5: Fat Goob). Goobs above it fall one
## row so the column has no gaps. Returns false if out of bounds or empty.
func destroy_cell(column: int, row: int) -> bool:
	if not in_bounds(column, row) or _cells[row][column] == CellOwner.EMPTY:
		return false
	for r in range(row, ROWS - 1):
		_cells[r][column] = _cells[r + 1][column]
	_cells[ROWS - 1][column] = CellOwner.EMPTY
	return true


# --- Win detection ---------------------------------------------------------

enum Outcome {
	NONE, ## nobody has four
	PLAYER_WIN,
	OPPONENT_WIN,
	DRAW, ## both sides have four at once (possible after M5 effects) — per Sean
}


## Result of the win check. Use this rather than find_winner() to end a game,
## so a mutual four is treated as a draw.
func get_outcome() -> Outcome:
	var player := not find_winning_line(CellOwner.PLAYER).is_empty()
	var opponent := not find_winning_line(CellOwner.OPPONENT).is_empty()
	if player and opponent:
		return Outcome.DRAW
	if player:
		return Outcome.PLAYER_WIN
	if opponent:
		return Outcome.OPPONENT_WIN
	return Outcome.NONE


## The side with four in a row, or EMPTY if nobody — or both sides — have one
## (both = draw; see get_outcome()).
func find_winner() -> CellOwner:
	match get_outcome():
		Outcome.PLAYER_WIN:
			return CellOwner.PLAYER
		Outcome.OPPONENT_WIN:
			return CellOwner.OPPONENT
	return CellOwner.EMPTY


## First winning line for `owner` as 4 cells (Vector2i(column, row)), ordered
## along the line. Empty array if none. Used for scoring + highlight.
func find_winning_line(owner: CellOwner) -> Array[Vector2i]:
	var lines := find_all_winning_lines(owner)
	if lines.is_empty():
		return [] as Array[Vector2i]
	return lines[0]


## Every distinct run of exactly CONNECT cells for `owner`. A run of 5 yields
## two overlapping lines of 4.
func find_all_winning_lines(owner: CellOwner) -> Array:
	var lines: Array = []
	if owner == CellOwner.EMPTY:
		return lines
	for row in ROWS:
		for column in COLUMNS:
			for dir in _DIRECTIONS:
				var line: Array[Vector2i] = []
				for i in CONNECT:
					var c := column + dir.x * i
					var r := row + dir.y * i
					if not in_bounds(c, r) or _cells[r][c] != owner:
						break
					line.append(Vector2i(c, r))
				if line.size() == CONNECT:
					lines.append(line)
	return lines


# --- Debug -----------------------------------------------------------------

## ASCII dump, top row first. P = player, O = opponent, . = empty.
func to_debug_string() -> String:
	var lines: PackedStringArray = []
	for row in range(ROWS - 1, -1, -1):
		var chars: PackedStringArray = []
		for column in COLUMNS:
			match _cells[row][column]:
				CellOwner.PLAYER:
					chars.append("P")
				CellOwner.OPPONENT:
					chars.append("O")
				_:
					chars.append(".")
		lines.append(" ".join(chars))
	return "\n".join(lines)
