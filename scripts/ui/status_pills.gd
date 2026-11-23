class_name StatusPills
extends Control
## Active statuses (TurnLoop.statuses, M6e) as pills in one row along the
## bottom of the gap between the HUD and the board: yours from the left in
## blue, his from the right in red. Each pill is a button on the game-pixel
## grid (toast-pill 9-slice, Monogram 1×); pressing it emits its explanation
## for the scenario to toast.

signal pill_pressed(text: String)

## Touch-target floor (slice §2B): 96 px at the 720 base.
const MIN_WIDTH := 96.0
## Tallest pill (game px; 36 = 96 px at 720) and its share of the gap.
const MAX_HEIGHT := 36.0
const GAP_SHARE := 0.5
## Game px from the screen sides, between pills and above the board.
const SIDE_X := 6.0
const SPACING := 4.0
const BOTTOM_GAP := 2.0
## Team colours: the board's blue / red (Resurrect 64, as the coin flip and
## the turn ribbons).
const COLORS := BoardView2D.COLOR_DEBRIS

var stage: PixelStage
var _buttons: Array[Button] = []
var _sides: Array[BoardState.CellOwner] = []
## Gap between the HUD and the board in viewport units (set_band).
var _top := 0.0
var _bottom := 0.0


func _init() -> void:
	name = "StatusPills"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = PixelStage.new()
	add_child(stage)
	stage.relayout.connect(_layout)


## The gap: `top` and `bottom_y` in viewport units (HUD bottom, board top).
func set_band(top: float, bottom_y: float) -> void:
	_top = top
	_bottom = bottom_y
	_layout()


## Replaces the pills with one per status ({side, label, text}).
func show_statuses(statuses: Array[Dictionary]) -> void:
	for button in _buttons:
		button.visible = false
		button.queue_free()
	_buttons.clear()
	_sides.clear()
	for status in statuses:
		var side: BoardState.CellOwner = status["side"]
		var button := stage.add_button(status["label"], MIN_WIDTH)
		var style := UiKit.stylebox(&"toast")
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_font_override(&"font", UiTheme.FONT)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			button.add_theme_color_override(state, COLORS[side])
		var text: String = status["text"]
		button.pressed.connect(func() -> void: pill_pressed.emit(text))
		_buttons.append(button)
		_sides.append(side)
	_layout()


## The pills on show (tests).
func buttons() -> Array[Button]:
	return _buttons


func _layout() -> void:
	if stage.k <= 0.0:
		return
	var band := Vector2((_top - stage.canvas.position.y) / stage.k, (_bottom - stage.canvas.position.y) / stage.k)
	var height := clampf(floorf((band.y - band.x) * GAP_SHARE), 0.0, MAX_HEIGHT)
	var min_w := ceilf(MIN_WIDTH / stage.k)
	var left := stage.safe.position.x + SIDE_X
	var right := stage.safe.end.x - SIDE_X
	for i in _buttons.size():
		var button := _buttons[i]
		button.size = Vector2.ZERO # shrink to the text, then grow to the floors
		button.size = Vector2(maxf(button.size.x, min_w), maxf(button.size.y, height))
		var y := floorf(band.y - BOTTOM_GAP - button.size.y)
		if _sides[i] == BoardState.CellOwner.PLAYER:
			button.position = Vector2(left, y)
			left += button.size.x + SPACING
		else:
			right -= button.size.x
			button.position = Vector2(right, y)
			right -= SPACING
