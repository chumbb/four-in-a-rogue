extends Control
## Scenario controller — turn loop with decks and hands (M4) in the portrait
## touch layout, on the M3.6 2D pixel board.
##
## The coin-flip winner moves first. Each turn draws 1 Goob (the player's pops
## in big, then flies into the fan). The player plays a hand Goob two ways
## (slice §2B): drag it onto a column and release (release off the board
## cancels and it flies back), or tap it to select, tap a column to aim and tap
## that column again to drop; holding or sliding on a column and releasing
## also drops. A blue flash and the floating Goob follow the aimed column.
## Column touches with no Goob selected are ignored (Sean, 2026-11-13).
## Double tap inspects a hand Goob, or a board Goob when none is selected. The opponent (OpponentAI) replies after a short delay and a
## red flash on its column. Player turns are timed (slice §2B): at timeout the
## Goob goes into the column under the finger, else a random column, rolling
## off full columns. Goobs fall (or roll) into place before the next turn;
## input stays locked until they land. The result is a big centred announcement: win/lose
## offers "Back to title", a draw "Replay" (straight back to the coin flip).

const OPPONENT_DELAY_SEC := 0.6
## Red flash on the opponent's column right before its Goob is played.
const OPPONENT_FLASH_SEC := 0.15
## Per-scenario player turn limit (slice §2B); v0.1 has one scenario.
const TURN_SECONDS := 30.0
## Timeout auto-play must be obvious (Sean, 2026-11-11): "Time's up!" and a
## flash on the column for this long before the Goob drops.
const TIMEOUT_REVEAL_SEC := 0.7
const MSG_TIMES_UP := "Time's up!"
const MSG_HAND_FULL := "Hand full"
## Drag starts once the finger moves this far from the press (slice §2B).
const DRAG_START_PX := 12.0
## A press on a column held this long (or slid) drops on release; shorter
## taps only aim (Sean, 2026-11-11).
const HOLD_SEC := 0.25
const DOUBLE_TAP_SEC := 0.3
## Skipped draw: short whole-screen shake (slice §4, ~0.25 s).
const SCREEN_SHAKE_PX := [8, -8, 6, -6, 3, -3, 0]
const SCREEN_SHAKE_STEP_SEC := 0.035

const COLOR_FLASH_PLAYER := Color(0.3, 0.55, 1.0, 0.35)
const COLOR_FLASH_OPPONENT := Color(1.0, 0.2, 0.2, 0.45)
const COLOR_FULL_GREY := Color(0.08, 0.08, 0.1, 0.55)
const COLOR_WIN := Color(1.0, 0.85, 0.3)
const COLOR_LOSE := Color(1.0, 0.3, 0.3)
const COLOR_DRAW := Color(0.75, 0.82, 1.0)

@onready var _turn_label: Label = %TurnLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _result_label: Label = %ResultLabel
@onready var _end_button: Button = %EndButton
@onready var _board_view: BoardView2D = %BoardView
@onready var _aim_lane: Control = %AimLane
@onready var _flash: ColorRect = %ColumnFlash
@onready var _table: ColorRect = %Table
@onready var _end_overlay: Control = %EndOverlay
@onready var _banner: Control = %Banner
@onready var _hand: HandView = %PlayerHand

## Seconds before the opponent drops. Tests set 0.0 (move immediately).
var opponent_delay_sec := OPPONENT_DELAY_SEC
## Tests set 0.0 to skip the red flash.
var opponent_flash_sec := OPPONENT_FLASH_SEC
var turn_seconds := TURN_SECONDS
## Tests set 0.0 to drop at once on timeout.
var timeout_reveal_sec := TIMEOUT_REVEAL_SEC
## Tests set false: Goobs land at once (no fall / roll animation).
var animate_drops := true

var _loop := TurnLoop.new()
var _rng := RandomNumberGenerator.new()
var _toast: Toast
var _sfx: Sfx
## One-shot child timers: anything pending is freed with the scene.
var _opponent_timer: Timer
var _flash_timer: Timer
var _turn_timer: Timer
var _timeout_timer: Timer
var _opponent_column := -1
var _timeout_column := -1
var _timeout_hand_index := -1
## Columns the timeout Goob rolls over (off-board entries = edge bounces).
var _timeout_path: Array[int] = []

## Player input is accepted only while true (player turn, nothing animating).
var _input_enabled := false
## What the current finger started on.
enum Gesture { NONE, HAND, BOARD, SWALLOW }

## Single pointer: the finger that started the gesture owns it.
var _touch_index := -1
var _gesture := Gesture.NONE
## Column under that finger, -1 when it is off the board. Also the timeout
## column; cleared by release and cancel.
var _touch_column := -1
## Hand index of the selected Goob, -1 when none.
var _selected := -1
## Column aimed by a tap (stays shown after the finger lifts), -1 when none.
var _aim_column := -1
var _aim_at_press := -1
var _press_pos := Vector2.ZERO
var _press_msec := 0
var _dragging := false
var _slid := false
## Double tap: what the last tap hit and when.
var _last_tap_key := ""
var _last_tap_msec := -100000
var _inspect: InspectPanel
var _grey: Array[ColorRect] = []
var _shake_tween: Tween


func _ready() -> void:
	_rng.randomize()
	_build_feedback_nodes()
	_opponent_timer = _make_timer(_choose_opponent_move)
	_flash_timer = _make_timer(_on_opponent_flash_done)
	_turn_timer = _make_timer(_on_turn_timeout)
	_timeout_timer = _make_timer(_finish_timeout)
	_end_overlay.visible = false
	_board_view.animate = animate_drops
	_hand.animate = animate_drops
	_board_view.item_rect_changed.connect(_layout_table.call_deferred)
	_layout_table.call_deferred()
	_loop.start(GameFlow.player_moves_first, _rng)
	_board_view.sync_from_board(_loop.board)
	# The player's first-turn draw is revealed by _after_play(), so the fan
	# starts without it.
	var start_hand := _loop.player_deck.hand.duplicate()
	if _loop.phase == TurnLoop.Phase.PLAYER_TURN:
		for goob in _loop.last_draw:
			start_hand.remove_at(start_hand.rfind(goob))
	_hand.rebuild(start_hand)
	_after_play()


func _process(_delta: float) -> void:
	if _input_enabled and not _turn_timer.is_stopped():
		_timer_label.text = "%ds" % ceili(_turn_timer.time_left)


## The table runs from under the board's floor to the bottom of the screen:
## the board stands on it, and the hand (M4) lies on it.
func _layout_table() -> void:
	var top := _board_view.floor_bottom_y()
	_table.position = Vector2(0.0, top)
	_table.size = Vector2(size.x, maxf(0.0, size.y - top))
	_hand.set_pixel_size(_board_view.hand_px())


func _make_timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _build_feedback_nodes() -> void:
	_toast = Toast.new()
	add_child(_toast)
	_sfx = Sfx.new()
	add_child(_sfx)
	_board_view.drop_sound.connect(_on_drop_sound)
	_hand.hand_sound.connect(_sfx.play)
	for column in BoardState.COLUMNS:
		var grey := ColorRect.new()
		grey.color = COLOR_FULL_GREY
		grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grey.visible = false
		add_child(grey)
		_grey.append(grey)
	_inspect = InspectPanel.new()
	add_child(_inspect)
	move_child(_inspect, _end_overlay.get_index())


# --- Touch input (slice §2B) ---------------------------------------------------

## Touch events only: on desktop a click arrives both as a mouse event and as
## an emulated touch, so reading both would act twice. _input (not
## _unhandled_input) so Controls under the finger can't swallow it.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event)
		elif event.index == _touch_index:
			_on_release(event)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_on_drag(event)


func _on_press(event: InputEventScreenTouch) -> void:
	if _touch_index != -1:
		return # a second finger; single pointer only
	if _inspect.is_open():
		# The next tap closes the inspect view and does nothing else.
		_inspect.close()
		_sfx.play(&"inspect_close")
		_start_gesture(event, Gesture.SWALLOW)
		return
	if not _input_enabled:
		return
	var hand_index := _hand.goob_at(event.position)
	if hand_index != -1:
		_start_gesture(event, Gesture.HAND)
		var double := _is_double_tap("hand:%d" % hand_index)
		if _selected != hand_index:
			_sfx.play(&"select")
		_select(hand_index)
		if double:
			_open_inspect(_loop.player_deck.hand[hand_index], BoardState.CellOwner.PLAYER)
			_gesture = Gesture.SWALLOW
		return
	var column := column_at(event.position)
	if column == -1:
		return
	_start_gesture(event, Gesture.BOARD)
	_aim_at_press = _aim_column
	if _selected != -1:
		_enter_column(column)
		return
	# No Goob selected: column touches are ignored (Sean, 2026-11-13), but a
	# double tap on a board Goob inspects it.
	var cell := _board_view.cell_at(event.position)
	var goob := _loop.goob_at(cell.x, cell.y)
	if goob != null and _is_double_tap("cell:%d,%d" % [cell.x, cell.y]):
		_open_inspect(goob, _loop.board.get_owner(cell.x, cell.y))
		_gesture = Gesture.SWALLOW


func _start_gesture(event: InputEventScreenTouch, gesture: Gesture) -> void:
	_touch_index = event.index
	_gesture = gesture
	_press_pos = event.position
	_press_msec = Time.get_ticks_msec()
	_dragging = false
	_slid = false
	get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	match _gesture:
		Gesture.HAND:
			if not _dragging and event.position.distance_to(_press_pos) > DRAG_START_PX:
				_dragging = true
				_last_tap_key = "" # a drag is not a tap
				_hand.begin_drag(_selected)
				_sfx.play(&"drag")
			if _dragging:
				_hand.drag_to(event.position)
				var column := column_at(event.position)
				if column != _touch_column:
					_enter_column(column)
				_hand.set_drag_visible(not _board_view.is_preview_visible())
		Gesture.BOARD:
			if _selected == -1:
				return
			var column := column_at(event.position)
			if column != _touch_column:
				_slid = true
				_enter_column(column)


func _on_release(event: InputEventScreenTouch) -> void:
	var gesture := _gesture
	var dragging := _dragging
	_touch_index = -1
	_gesture = Gesture.NONE
	_dragging = false
	get_viewport().set_input_as_handled()
	if not _input_enabled or _selected == -1:
		return
	var column := column_at(event.position)
	var legal := column != -1 and not event.canceled and not _loop.board.column_full(column)
	match gesture:
		Gesture.HAND:
			if not dragging:
				return # a tap: the Goob stays selected
			if legal:
				_play_selected(column)
			else:
				# Released off the board (or on a full column): it flies back.
				_hand.cancel_drag()
				_sfx.play(&"cancel")
				_clear_aim()
				_select(-1)
		Gesture.BOARD:
			var held := _slid or Time.get_ticks_msec() - _press_msec >= HOLD_SEC * 1000.0
			if not legal:
				_clear_aim() # off the board or a full column: back to neutral
			elif held or column == _aim_at_press:
				_play_selected(column)
			else:
				# A quick tap only aims; tapping the same column again drops.
				_aim_column = column
				_touch_column = -1


func _is_double_tap(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if key == _last_tap_key and now - _last_tap_msec <= DOUBLE_TAP_SEC * 1000.0:
		_last_tap_key = ""
		return true
	_last_tap_key = key
	_last_tap_msec = now
	return false


func _select(index: int) -> void:
	_selected = index
	if _hand.selected() != index:
		_hand.select(index)
	_refresh_grey()


func _open_inspect(goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	_sfx.play(&"inspect_open")
	_inspect.open(goob, side, HandView.GOOB_PX * _board_view.hand_px() * 2.0)


## The finger moved onto `column` (-1 = off the board). A full column errors
## once per entry: this only runs when the column under the finger changes.
func _enter_column(column: int) -> void:
	_touch_column = column
	_aim_column = -1
	if column == -1:
		_hide_aim()
	elif _loop.board.column_full(column):
		_hide_aim()
		_reject_placement(Toast.MSG_COLUMN_FULL)
	else:
		# First touch on a column blips; sliding to another one ticks.
		_sfx.play(&"column_tick" if _board_view.is_preview_visible() else &"column")
		_show_aim(column)


func _clear_aim() -> void:
	_aim_column = -1
	_touch_column = -1
	_hide_aim()


## Input locks: drop any gesture, aim, selection and inspect view.
func _end_touch() -> void:
	if _hand.is_dragging():
		_hand.cancel_drag()
	_touch_index = -1
	_gesture = Gesture.NONE
	_dragging = false
	_clear_aim()
	_select(-1)
	_inspect.close()


## Full columns grey out while a Goob is selected (slice §2B).
func _refresh_grey() -> void:
	for column in BoardState.COLUMNS:
		var grey := _grey[column]
		grey.visible = _selected != -1 and _input_enabled and _loop.board.column_full(column)
		if grey.visible:
			var rect := column_hit_rect(column)
			grey.global_position = rect.position
			grey.size = rect.size


## Column whose hit area (column slot + the aim lane above it) contains the
## viewport position, or -1.
func column_at(pos: Vector2) -> int:
	for column in BoardState.COLUMNS:
		if column_hit_rect(column).has_point(pos):
			return column
	return -1


## A column's slot on screen, stretched up through the aim lane.
func column_hit_rect(column: int) -> Rect2:
	var slot := _board_view.column_rect(column)
	var top := _aim_lane.get_global_rect().position.y
	return Rect2(slot.position.x, top, slot.size.x, slot.end.y - top)


func _show_flash(column: int, color: Color) -> void:
	var rect := column_hit_rect(column)
	_flash.color = color
	_flash.global_position = rect.position
	_flash.size = rect.size
	_flash.visible = true


func _hide_flash() -> void:
	_flash.visible = false


## Player aim feedback: blue column flash + their Goob floating on top of the
## board over that column.
func _show_aim(column: int) -> void:
	_show_flash(column, COLOR_FLASH_PLAYER)
	_board_view.show_preview(column, BoardState.CellOwner.PLAYER)


func _hide_aim() -> void:
	_hide_flash()
	_board_view.hide_preview()


func _set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		_turn_timer.start(turn_seconds)
	else:
		_turn_timer.stop()
		_end_touch()
	_refresh_grey()
	_refresh_hud()


# --- Turns -------------------------------------------------------------------

## Player entry point: plays hand Goob `hand_index` into `column`. Returns
## the landed row, or -1 if it is not the player's turn (silently), the column
## or hand index is invalid (a caller bug), or the column is full (shake +
## sound + toast).
func try_drop(column: int, hand_index: int = 0) -> int:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return -1
	if not _loop.board.is_valid_column(column):
		push_error("Scenario.try_drop: invalid column %d" % column)
		return -1
	if hand_index < 0 or hand_index >= _loop.player_deck.hand.size():
		push_error("Scenario.try_drop: invalid hand index %d" % hand_index)
		return -1
	if _loop.board.column_full(column):
		_reject_placement(Toast.MSG_COLUMN_FULL)
		return -1
	return _play_player(column, hand_index)


## Plays the selected hand Goob into `column` (no undo).
func _play_selected(column: int) -> void:
	_play_player(column, _selected)


## `roll_path`: the timeout roll over full columns (see _roll_path()).
func _play_player(column: int, hand_index: int, roll_path: Array[int] = []) -> int:
	_set_input_enabled(false) # locked until the drop finishes
	_hand.remove(hand_index)
	var row := _loop.play(column, hand_index)
	_land_then_continue(column, row, BoardState.CellOwner.PLAYER, roll_path)
	return row


## The Goob falls (or rolls) into place, then the next turn starts.
## §4.2 order: land → special effect (M5) → win check last (in TurnLoop).
func _land_then_continue(column: int, row: int, side: BoardState.CellOwner, roll_path: Array[int] = []) -> void:
	await _board_view.play_drop(column, row, side, roll_path)
	_sfx.play(&"land", side == BoardState.CellOwner.OPPONENT)
	_board_view.sync_from_board(_loop.board)
	_after_play()


## Timeout: the column under the finger, else a random one (full included).
## Input locks, "Time's up!" shows and the column flashes, then the Goob drops;
## a full column sends it rolling to the first open one (slice §2B).
func _on_turn_timeout() -> void:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return
	# Column under the finger, else the tap-aimed column, else random.
	var column := _touch_column if _touch_index != -1 else -1
	if column == -1:
		column = _aim_column
	if column == -1:
		column = _rng.randi_range(0, BoardState.COLUMNS - 1)
	# The selected (or dragged) Goob, else a random one (Sean, 2026-11-13).
	_timeout_hand_index = _selected
	if _timeout_hand_index == -1:
		_timeout_hand_index = _rng.randi_range(0, _loop.player_deck.hand.size() - 1)
	_set_input_enabled(false)
	_hand.remove(_timeout_hand_index)
	_timer_label.text = "0s"
	_timer_label.visible = true
	_toast.show_message(MSG_TIMES_UP)
	_sfx.play(&"times_up")
	_place_toast()
	var rightward := _rng.randi() % 2 == 0
	_timeout_column = _loop.board.roll_target(column, rightward)
	_timeout_path = _roll_path(column, rightward)
	if timeout_reveal_sec > 0.0:
		_show_aim(column)
		_timeout_timer.start(timeout_reveal_sec)
	else:
		_finish_timeout()


func _finish_timeout() -> void:
	_hide_aim()
	_play_player(_timeout_column, _timeout_hand_index, _timeout_path)


## Columns a Goob played into full `column` rolls over before it falls, for
## the roll animation. Same walk as BoardState.roll_target(); an off-board
## entry (-1 or COLUMNS) marks a bounce off that edge. [column] if it is open.
func _roll_path(column: int, rightward: bool) -> Array[int]:
	var path: Array[int] = [column]
	if _loop.board.roll_target(column, rightward) == -1:
		return path
	var step := 1 if rightward else -1
	var at := column
	while _loop.board.column_full(at):
		if not _loop.board.is_valid_column(at + step):
			path.append(at + step)
			step = -step
		at += step
		path.append(at)
	return path


func _after_play() -> void:
	match _loop.phase:
		TurnLoop.Phase.OVER:
			_show_end()
		TurnLoop.Phase.OPPONENT_TURN:
			_run_opponent_turn()
		_:
			await _show_turn_draw()
			if is_inside_tree() and _loop.phase == TurnLoop.Phase.PLAYER_TURN:
				_set_input_enabled(true)


## The player's start-of-turn draw: each drawn Goob pops in big and flies into
## the fan; a draw skipped by a full hand shows "Hand full" + a screen shake.
func _show_turn_draw() -> void:
	if _loop.last_draw_hand_full:
		_toast.show_message(MSG_HAND_FULL)
		_sfx.play(&"hand_full")
		_place_toast()
		_shake_screen()
	for goob in _loop.last_draw:
		await _hand.reveal(goob)


func _on_drop_sound(kind: StringName, side: BoardState.CellOwner) -> void:
	_sfx.play(kind, side == BoardState.CellOwner.OPPONENT)


## Short whole-screen shake in whole logical px.
func _shake_screen() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for px: int in SCREEN_SHAKE_PX:
		_shake_tween.tween_property(self, "position:x", float(px), SCREEN_SHAKE_STEP_SEC)


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
	# Until the M6 AI: a random Goob from its hidden hand (Sean, 2026-11-13).
	var hand_index := _rng.randi_range(0, _loop.opponent_deck.hand.size() - 1)
	var row := _loop.play(_opponent_column, hand_index)
	if row == -1:
		push_error("Scenario: opponent chose illegal column %d" % _opponent_column)
		return
	_land_then_continue(_opponent_column, row, BoardState.CellOwner.OPPONENT)


func _show_end() -> void:
	_set_input_enabled(false)
	var color := COLOR_DRAW
	match _loop.result:
		TurnLoop.Result.PLAYER_WIN:
			_board_view.highlight_cells(_loop.board.find_winning_line(BoardState.CellOwner.PLAYER))
			_result_label.text = "You Win!"
			_end_button.text = "Back to title"
			color = COLOR_WIN
		TurnLoop.Result.OPPONENT_WIN:
			_board_view.highlight_cells(_loop.board.find_winning_line(BoardState.CellOwner.OPPONENT))
			_result_label.text = "You Lose"
			_end_button.text = "Back to title"
			color = COLOR_LOSE
		_:
			_result_label.text = "Draw"
			_end_button.text = "Replay"
	_result_label.add_theme_color_override("font_color", color)
	(_banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = color
	_end_overlay.visible = true
	_announce.call_deferred()


## Placeholder juice: dim fades in, the banner slams in with overshoot and a
## white flash, then the result text keeps pulsing.
func _announce() -> void:
	var dim: Control = _end_overlay.get_node("Dim")
	_banner.pivot_offset = _banner.size * 0.5
	_result_label.pivot_offset = _result_label.size * 0.5
	dim.modulate.a = 0.0
	_banner.scale = Vector2(1.0, 0.0)
	_banner.modulate = Color(3.0, 3.0, 3.0)
	var intro := create_tween().set_parallel()
	intro.tween_property(dim, "modulate:a", 1.0, 0.25)
	intro.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_banner, "modulate", Color.WHITE, 0.4)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_result_label, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_result_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


## §4.6 feedback: shake + error sound + toast.
func _reject_placement(message: String) -> void:
	_board_view.shake()
	_sfx.play(&"error")
	_toast.show_message(message)
	_place_toast()


## Toasts sit just above the aim lane.
func _place_toast() -> void:
	var lane := _aim_lane.get_global_rect()
	_toast.position = Vector2((size.x - _toast.size.x) * 0.5, lane.position.y - _toast.size.y - 8.0)


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
