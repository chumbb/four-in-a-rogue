extends Control
## Scenario controller — M2 board-core test harness.
##
## M2 has no turn loop yet (that's M3), so both sides are driven by hand:
##   Left click a column  → drop PLAYER (red)
##   Right click a column → drop OPPONENT (blue)
##   Reset Board button   → clear the grid
## A four-in-a-row stops input until reset.

@onready var _grid_label: Label = %GridStatusLabel
@onready var _first_player_label: Label = %FirstPlayerLabel
@onready var _result_label: Label = %ResultLabel
@onready var _board_view: Node3D = %BoardView3D
@onready var _board_container: Control = $BoardViewportContainer

var _board := BoardState.new()
var _toast: Toast
var _sfx_error: AudioStreamPlayer
var _sfx_drop: AudioStreamPlayer
var _game_over := false


func _ready() -> void:
	var first := "You" if GameFlow.player_moves_first else "Opponent"
	_first_player_label.text = "First player (coin flip): %s" % first
	_build_feedback_nodes()
	_board_view.column_clicked.connect(_on_column_clicked)
	_board_container.mouse_exited.connect(_board_view.clear_hover)
	_reset_board()


func _build_feedback_nodes() -> void:
	_toast = Toast.new()
	$HUD.add_child(_toast)
	_sfx_error = AudioStreamPlayer.new()
	_sfx_error.stream = Sfx.error_buzz()
	add_child(_sfx_error)
	_sfx_drop = AudioStreamPlayer.new()
	_sfx_drop.stream = Sfx.drop_click()
	add_child(_sfx_drop)


func _on_column_clicked(column: int, button_index: int) -> void:
	var owner: BoardState.CellOwner
	match button_index:
		MOUSE_BUTTON_LEFT:
			owner = BoardState.CellOwner.PLAYER
		MOUSE_BUTTON_RIGHT:
			owner = BoardState.CellOwner.OPPONENT
		_:
			return
	try_drop(column, owner)


## Drop entry point. M3+ turn loop and the AI should call this too.
## Returns the landed row, or -1 if the game is over, the column index is
## invalid (a caller bug, not player error), or the column is full (feedback).
func try_drop(column: int, owner: BoardState.CellOwner) -> int:
	if _game_over:
		return -1
	if not _board.is_valid_column(column):
		push_error("Scenario.try_drop: invalid column %d" % column)
		return -1
	if _board.column_full(column):
		_reject_placement(Toast.MSG_COLUMN_FULL)
		return -1
	var row := _board.drop(column, owner)
	_sfx_drop.play()
	# §4.2 order: land → special effect (M5) → win check last.
	_board_view.sync_from_board(_board)
	_check_for_winner()
	_refresh_grid_display()
	return row


## §4.6 feedback: shake + error sound + toast.
func _reject_placement(message: String) -> void:
	_board_view.shake()
	_sfx_error.play()
	_toast.show_message(message)
	_place_toast()


func _place_toast() -> void:
	# Centered over the board, just above its bottom edge.
	var rect := _board_container.get_global_rect()
	_toast.position = Vector2(
		rect.position.x + (rect.size.x - _toast.size.x) * 0.5,
		rect.end.y - _toast.size.y - 24.0
	)


func _check_for_winner() -> void:
	match _board.get_outcome():
		BoardState.Outcome.PLAYER_WIN:
			_board_view.highlight_cells(_board.find_winning_line(BoardState.CellOwner.PLAYER))
			_end_test_game("Red (player) connects four!")
		BoardState.Outcome.OPPONENT_WIN:
			_board_view.highlight_cells(_board.find_winning_line(BoardState.CellOwner.OPPONENT))
			_end_test_game("Blue (opponent) connects four!")
		BoardState.Outcome.DRAW:
			_board_view.highlight_cells(_board.find_winning_line(BoardState.CellOwner.PLAYER))
			_board_view.highlight_cells(_board.find_winning_line(BoardState.CellOwner.OPPONENT))
			_end_test_game("Both sides connect four — draw.")
		_:
			if _board.is_board_full():
				_end_test_game("Board full — no four in a row.")


func _end_test_game(text: String) -> void:
	_game_over = true
	_board_view.input_enabled = false
	_result_label.text = text + "  Press Reset Board to play again."


func _reset_board() -> void:
	_board.reset()
	_game_over = false
	_board_view.input_enabled = true
	_board_view.sync_from_board(_board)
	_result_label.text = ""
	_refresh_grid_display()


func _refresh_grid_display() -> void:
	_grid_label.text = (
		"M2 test: Left click = red (player), Right click = blue (opponent).\n\n%s"
		% _board.to_debug_string()
	)


func _on_reset_board_pressed() -> void:
	_reset_board()


func _on_back_to_menu_pressed() -> void:
	GameFlow.return_to_title()
