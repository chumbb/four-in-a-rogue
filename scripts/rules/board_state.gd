class_name BoardState
extends RefCounted
## Minimal 7×6 Connect 4 grid placeholder (logic only, no drops yet).

const COLUMNS := 7
const ROWS := 6

enum CellOwner {
	EMPTY,
	PLAYER,
	OPPONENT,
}

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


func is_empty(column: int, row: int) -> bool:
	return get_owner(column, row) == CellOwner.EMPTY


func get_owner(column: int, row: int) -> CellOwner:
	if not _in_bounds(column, row):
		return CellOwner.EMPTY
	return _cells[row][column] as CellOwner


func _in_bounds(column: int, row: int) -> bool:
	return column >= 0 and column < COLUMNS and row >= 0 and row < ROWS
