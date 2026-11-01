extends Control

@onready var _grid_label: Label = %GridStatusLabel
@onready var _first_player_label: Label = %FirstPlayerLabel

var _board := BoardState.new()


func _ready() -> void:
	var first := "You" if GameFlow.player_moves_first else "Opponent"
	_first_player_label.text = "First player (coin flip): %s" % first
	_refresh_grid_display()


func _refresh_grid_display() -> void:
	var lines: PackedStringArray = []
	for row in BoardState.ROWS:
		var row_chars: PackedStringArray = []
		for col in BoardState.COLUMNS:
			row_chars.append(".")
		lines.append("|".join(row_chars))
	_grid_label.text = (
		"Scenario placeholder — empty %d×%d board (gameplay TBD).\n\n%s"
		% [BoardState.COLUMNS, BoardState.ROWS, "\n".join(lines)]
	)


func _on_back_to_menu_pressed() -> void:
	GameFlow.return_to_title()
