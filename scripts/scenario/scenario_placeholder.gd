extends Control
## Scenario controller — M3 turn loop in the M3.5 portrait touch layout.
##
## The coin-flip winner moves first. The player presses a column (a blue flash
## follows the finger over the columns) and releases to drop; releasing off the
## board cancels. The opponent (OpponentAI) replies after a short delay and a
## red flash on its column. Player turns are timed (slice §2B): at timeout the
## Goob goes into the column under the finger, else a random column, rolling
## off full columns. Win/lose shows "Back to title"; a draw shows "Replay"
## (straight back to the coin flip).

const OPPONENT_DELAY_SEC := 0.6
## Red flash on the opponent's column right before its Goob is played.
const OPPONENT_FLASH_SEC := 0.15
## Per-scenario player turn limit (slice §2B); v0.1 has one scenario.
const TURN_SECONDS := 30.0

const COLOR_FLASH_PLAYER := Color(0.3, 0.55, 1.0, 0.35)
const COLOR_FLASH_OPPONENT := Color(1.0, 0.2, 0.2, 0.45)

@onready var _turn_label: Label = %TurnLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _first_player_label: Label = %FirstPlayerLabel
@onready var _result_label: Label = %ResultLabel
@onready var _end_button: Button = %EndButton
@onready var _board_view: Node3D = %BoardView3D
@onready var _board_container: SubViewportContainer = %BoardViewportContainer
@onready var _aim_lane: Control = %AimLane
@onready var _flex_band: Control = %FlexBand
@onready var _flash: ColorRect = %ColumnFlash

## Seconds before the opponent drops. Tests set 0.0 (move immediately).
var opponent_delay_sec := OPPONENT_DELAY_SEC
## Tests set 0.0 to skip the red flash.
var opponent_flash_sec := OPPONENT_FLASH_SEC
var turn_seconds := TURN_SECONDS

var _loop := TurnLoop.new()
var _rng := RandomNumberGenerator.new()
var _toast: Toast
var _sfx_error: AudioStreamPlayer
var _sfx_drop: AudioStreamPlayer
## One-shot child timers: anything pending is freed with the scene.
var _opponent_timer: Timer
var _flash_timer: Timer
var _turn_timer: Timer
var _opponent_column := -1

## Player input is accepted only while true (player turn, nothing animating).
var _input_enabled := false
## Single pointer: the finger that started on a column owns the gesture.
var _touch_index := -1
## Column under that finger, -1 when it is off the board. Also the timeout
## column; cleared by release and cancel.
var _touch_column := -1


func _ready() -> void:
	_rng.randomize()
	var first := "You" if GameFlow.player_moves_first else "Opponent"
	_first_player_label.text = "First player (coin flip): %s" % first
	_build_feedback_nodes()
	_opponent_timer = _make_timer(_choose_opponent_move)
	_flash_timer = _make_timer(_on_opponent_flash_done)
	_turn_timer = _make_timer(_on_turn_timeout)
	_end_button.visible = false
	_result_label.text = ""
	_loop.start(GameFlow.player_moves_first)
	_board_view.sync_from_board(_loop.board)
	_after_play()


func _process(_delta: float) -> void:
	if _input_enabled and not _turn_timer.is_stopped():
		_timer_label.text = "%ds" % ceili(_turn_timer.time_left)


func _make_timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _build_feedback_nodes() -> void:
	_toast = Toast.new()
	add_child(_toast)
	_sfx_error = AudioStreamPlayer.new()
	_sfx_error.stream = Sfx.error_buzz()
	add_child(_sfx_error)
	_sfx_drop = AudioStreamPlayer.new()
	_sfx_drop.stream = Sfx.drop_click()
	add_child(_sfx_drop)


# --- Touch input (slice §2B column touch) ------------------------------------

## Touch events only: on desktop a click arrives both as a mouse event and as
## an emulated touch, so reading both would act twice. _input (not
## _unhandled_input) so Controls under the finger can't swallow it.
func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index != -1:
				return # a second finger; single pointer only
			var column := column_at(event.position)
			if column == -1:
				return
			_touch_index = event.index
			_enter_column(column)
			get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			var column := column_at(event.position)
			_end_touch()
			get_viewport().set_input_as_handled()
			if column != -1 and not event.canceled and not _loop.board.column_full(column):
				try_drop(column)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var column := column_at(event.position)
		if column != _touch_column:
			_enter_column(column)


## The finger moved onto `column` (-1 = off the board). A full column errors
## once per entry: this only runs when the column under the finger changes.
func _enter_column(column: int) -> void:
	_touch_column = column
	if column == -1:
		_hide_flash()
	elif _loop.board.column_full(column):
		_hide_flash()
		_reject_placement(Toast.MSG_COLUMN_FULL)
	else:
		_show_flash(column, COLOR_FLASH_PLAYER)


func _end_touch() -> void:
	_touch_index = -1
	_touch_column = -1
	_hide_flash()


## Column whose hit area (column slot + the aim lane above it) contains the
## viewport position, or -1.
func column_at(pos: Vector2) -> int:
	for column in BoardState.COLUMNS:
		if column_hit_rect(column).has_point(pos):
			return column
	return -1


## A column's slot on screen, stretched up through the aim lane.
func column_hit_rect(column: int) -> Rect2:
	var sub: SubViewport = _board_container.get_child(0)
	var slot: Rect2 = _board_view.column_rect(column)
	var box := _board_container.get_global_rect()
	var k := box.size / Vector2(sub.size)
	var left := box.position.x + slot.position.x * k.x
	var top := _aim_lane.get_global_rect().position.y
	var bottom := box.position.y + slot.end.y * k.y
	return Rect2(left, top, slot.size.x * k.x, bottom - top)


func _show_flash(column: int, color: Color) -> void:
	var rect := column_hit_rect(column)
	_flash.color = color
	_flash.global_position = rect.position
	_flash.size = rect.size
	_flash.visible = true


func _hide_flash() -> void:
	_flash.visible = false


func _set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		_turn_timer.start(turn_seconds)
	else:
		_turn_timer.stop()
		_end_touch()
	_refresh_hud()


# --- Turns -------------------------------------------------------------------

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
	return _play_player(column)


func _play_player(column: int) -> int:
	_set_input_enabled(false) # locked until the drop finishes
	var row := _loop.play(column)
	_sfx_drop.play()
	# §4.2 order: land → special effect (M5) → win check last (in TurnLoop).
	# Placeholder animation: the Goob appears in its final cell.
	_board_view.sync_from_board(_loop.board)
	_after_play()
	return row


## Timeout: the column under the finger, else a random one (full included).
## A full column sends the Goob rolling to the first open one (slice §2B).
func _on_turn_timeout() -> void:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return
	var column := _touch_column
	if _touch_index == -1 or column == -1:
		column = _rng.randi_range(0, BoardState.COLUMNS - 1)
	_play_player(_loop.board.roll_target(column, _rng.randi() % 2 == 0))


func _after_play() -> void:
	match _loop.phase:
		TurnLoop.Phase.OVER:
			_show_end()
		TurnLoop.Phase.OPPONENT_TURN:
			_run_opponent_turn()
		_:
			_set_input_enabled(true)


func _run_opponent_turn() -> void:
	_set_input_enabled(false)
	if opponent_delay_sec > 0.0:
		_opponent_timer.start(opponent_delay_sec)
	else:
		_choose_opponent_move()


func _choose_opponent_move() -> void:
	_opponent_column = OpponentAI.choose_column(_loop.board, _rng)
	if opponent_flash_sec > 0.0:
		_show_flash(_opponent_column, COLOR_FLASH_OPPONENT)
		_flash_timer.start(opponent_flash_sec)
	else:
		_play_opponent_move()


func _on_opponent_flash_done() -> void:
	_hide_flash()
	_play_opponent_move()


func _play_opponent_move() -> void:
	if _loop.play(_opponent_column) == -1:
		push_error("Scenario: opponent chose illegal column %d" % _opponent_column)
		return
	_sfx_drop.play()
	_board_view.sync_from_board(_loop.board)
	_after_play()


func _show_end() -> void:
	_set_input_enabled(false)
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


## Toasts live in the flex band; when it is too short they overlap the aim lane.
func _place_toast() -> void:
	var band := _flex_band.get_global_rect()
	_toast.position = Vector2(
		(size.x - _toast.size.x) * 0.5,
		maxf(band.position.y, band.end.y - _toast.size.y - 8.0)
	)


func _refresh_hud() -> void:
	match _loop.phase:
		TurnLoop.Phase.PLAYER_TURN:
			_turn_label.text = "Your turn"
		TurnLoop.Phase.OPPONENT_TURN:
			_turn_label.text = "Opponent's turn"
		_:
			_turn_label.text = ""
	_timer_label.visible = _input_enabled
	if _input_enabled:
		_timer_label.text = "%ds" % ceili(turn_seconds)


func _on_end_pressed() -> void:
	if _loop.result == TurnLoop.Result.DRAW:
		GameFlow.replay_after_draw()
	else:
		GameFlow.return_to_title()


func _on_back_to_menu_pressed() -> void:
	GameFlow.return_to_title()
