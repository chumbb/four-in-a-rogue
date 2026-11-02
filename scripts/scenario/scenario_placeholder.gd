extends Control
## Scenario controller — M3 turn loop.
##
## The coin-flip winner moves first. The player left-clicks a column; the
## opponent (OpponentAI) replies after a short delay. Win/lose shows
## "Back to title"; a draw shows "Replay" (straight back to the coin flip).

const OPPONENT_DELAY_SEC := 0.6

@onready var _grid_label: Label = %GridStatusLabel
@onready var _first_player_label: Label = %FirstPlayerLabel
@onready var _result_label: Label = %ResultLabel
@onready var _end_button: Button = %EndButton
@onready var _board_view: Node3D = %BoardView3D
@onready var _board_container: Control = $BoardViewportContainer

## Seconds before the opponent drops. Tests set 0.0 (move immediately).
var opponent_delay_sec := OPPONENT_DELAY_SEC

var _loop := TurnLoop.new()
var _rng := RandomNumberGenerator.new()
var _toast: Toast
var _sfx_error: AudioStreamPlayer
var _sfx_drop: AudioStreamPlayer
## One-shot child timer: a pending opponent move is freed with the scene.
var _opponent_timer: Timer


func _ready() -> void:
	_rng.randomize()
	var first := "You" if GameFlow.player_moves_first else "Opponent"
	_first_player_label.text = "First player (coin flip): %s" % first
	_build_feedback_nodes()
	_opponent_timer = Timer.new()
	_opponent_timer.one_shot = true
	_opponent_timer.timeout.connect(_play_opponent_move)
	add_child(_opponent_timer)
	_board_view.column_clicked.connect(_on_column_clicked)
	_board_container.mouse_exited.connect(_board_view.clear_hover)
	_end_button.visible = false
	_result_label.text = ""
	_loop.start(GameFlow.player_moves_first)
	_board_view.sync_from_board(_loop.board)
	_after_play()


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
	if button_index != MOUSE_BUTTON_LEFT:
		return
	try_drop(column)


## Player entry point. Returns the landed row, or -1 if it is not the
## player's turn (silently), the column index is invalid (a caller bug), or
## the column is full (shake + sound + toast).
func try_drop(column: int) -> int:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return -1
	if not _loop.board.is_valid_column(column):
		push_error("Scenario.try_drop: invalid column %d" % column)
		return -1
	if _loop.board.column_full(column):
		_reject_placement(Toast.MSG_COLUMN_FULL)
		return -1
	var row := _loop.play(column)
	_sfx_drop.play()
	# §4.2 order: land → special effect (M5) → win check last (in TurnLoop).
	_board_view.sync_from_board(_loop.board)
	_after_play()
	return row


func _after_play() -> void:
	_refresh_grid_display()
	match _loop.phase:
		TurnLoop.Phase.OVER:
			_show_end()
		TurnLoop.Phase.OPPONENT_TURN:
			_run_opponent_turn()
		_:
			_board_view.input_enabled = true


func _run_opponent_turn() -> void:
	_board_view.input_enabled = false
	if opponent_delay_sec > 0.0:
		_opponent_timer.start(opponent_delay_sec)
	else:
		_play_opponent_move()


func _play_opponent_move() -> void:
	_loop.play(OpponentAI.choose_column(_loop.board, _rng))
	_sfx_drop.play()
	_board_view.sync_from_board(_loop.board)
	_after_play()


func _show_end() -> void:
	_board_view.input_enabled = false
	match _loop.result:
		TurnLoop.Result.PLAYER_WIN:
			_board_view.highlight_cells(_loop.board.find_winning_line(BoardState.CellOwner.PLAYER))
			_result_label.text = "Win"
			_end_button.text = "Back to title"
		TurnLoop.Result.OPPONENT_WIN:
			_board_view.highlight_cells(_loop.board.find_winning_line(BoardState.CellOwner.OPPONENT))
			_result_label.text = "Lose"
			_end_button.text = "Back to title"
		_:
			_result_label.text = "Draw"
			_end_button.text = "Replay"
	_end_button.visible = true


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


func _refresh_grid_display() -> void:
	var turn := ""
	match _loop.phase:
		TurnLoop.Phase.PLAYER_TURN:
			turn = "Your turn"
		TurnLoop.Phase.OPPONENT_TURN:
			turn = "Opponent's turn"
	_grid_label.text = "%s\n\n%s" % [turn, _loop.board.to_debug_string()]


func _on_end_pressed() -> void:
	if _loop.result == TurnLoop.Result.DRAW:
		GameFlow.replay_after_draw()
	else:
		GameFlow.return_to_title()


func _on_back_to_menu_pressed() -> void:
	GameFlow.return_to_title()
