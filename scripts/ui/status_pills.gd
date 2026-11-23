class_name StatusPills
extends Control
## Active statuses (TurnLoop.statuses, M6e) as pills in one row in the strip of
## the gap above the aim lane (between the HUD and the aim lane: column input
## always wins, so no pill covers a column's hit area): yours from the left in
## blue, his from the right in red. Each pill is a button on the game-pixel
## grid (toast-pill 9-slice, Monogram 1×) as tall as that strip, at least
## 10 game px (over the HUD block's bottom edge when the strip is shorter);
## pressing it
## emits its explanation for the scenario to toast. Placeholder look: the
## 96 px height floor is knowingly relaxed (Art pass G revisits).

signal pill_pressed(text: String)

## Touch-target floor (slice §2B): 96 px wide at the 720 base.
const MIN_WIDTH := 96.0
## Game px from the screen sides, between pills, and text padding each side.
const SIDE_X := 6.0
const SPACING := 4.0
const PAD_X := 5.0
## Monogram 1× line height (game px); the label is centred on the pill.
const LINE_H := 16.0
## Team colours: the board's blue / red (Resurrect 64, as the coin flip and
## the turn ribbons).
const COLORS := BoardView2D.COLOR_DEBRIS

var stage: PixelStage
var _buttons: Array[Button] = []
var _sides: Array[BoardState.CellOwner] = []
## The strip in viewport units (set_band): HUD bottom, aim lane top.
var _top := 0.0
var _bottom := 0.0


func _init() -> void:
	name = "StatusPills"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = PixelStage.new()
	add_child(stage)
	stage.relayout.connect(_layout)


## The strip: `top` and `bottom_y` in viewport units (HUD bottom, aim lane top).
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
		# No button text: its minimum height would outgrow the strip. The
		# label is a child, centred, and may overhang the pill's border.
		var button := stage.add_button("", MIN_WIDTH)
		var style := UiKit.stylebox(&"toast")
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			button.add_theme_stylebox_override(state, style)
		var label := stage.add_label(status["label"], COLORS[side], &"", button)
		label.name = "Text"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var text: String = status["text"]
		button.pressed.connect(func() -> void: pill_pressed.emit(text))
		_buttons.append(button)
		_sides.append(side)
	_layout()


## The pills on show (tests).
func buttons() -> Array[Button]:
	return _buttons


## A pill's label (its status's label).
static func label_of(button: Button) -> String:
	return (button.get_node("Text") as Label).text


func _layout() -> void:
	if stage.k <= 0.0:
		return
	var top := ceilf((_top - stage.canvas.position.y) / stage.k)
	var bottom := floorf((_bottom - stage.canvas.position.y) / stage.k)
	var strip := maxf(0.0, bottom - top)
	var min_w := ceilf(MIN_WIDTH / stage.k)
	var left := stage.safe.position.x + SIDE_X
	var right := stage.safe.end.x - SIDE_X
	for i in _buttons.size():
		var button := _buttons[i]
		var label: Label = button.get_node("Text")
		label.reset_size()
		# Never hidden: at least the pill's minimum height (10 game px), its
		# bottom on the aim lane's top; with no room it overhangs the HUD
		# block's bottom edge, which has no touch targets (M6e ruling).
		var height := maxf(strip, button.get_minimum_size().y)
		button.size = Vector2(maxf(label.size.x + PAD_X * 2.0, min_w), height)
		label.size.x = button.size.x
		var y := bottom - height
		label.position = Vector2(0, floorf((height - LINE_H) * 0.5))
		if _sides[i] == BoardState.CellOwner.PLAYER:
			button.position = Vector2(left, y)
			left += button.size.x + SPACING
		else:
			right -= button.size.x
			button.position = Vector2(right, y)
			right -= SPACING
