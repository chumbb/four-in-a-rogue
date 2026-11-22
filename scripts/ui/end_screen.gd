class_name EndScreen
extends Control
## Win / lose / draw screen in the HUD's pixel style (Sean, M6c playtest; was a
## plain dark band): the pause menu's scrim, the Art B end-banner frame (gold
## corner studs), the result in the logo's gold pixel letters ("YOU WIN!",
## red "YOU LOSE", cream "DRAW") and pixel buttons: "View board" (minimise to
## review the board) and "Back to title" / "Replay". Copy per slice §2B.

signal primary_pressed
signal view_pressed

const HEADINGS := {
	&"win": preload("res://assets/ui/heading_you_win.png"),
	&"lose": preload("res://assets/ui/heading_you_lose.png"),
	&"draw": preload("res://assets/ui/heading_draw.png"),
}
const TEXT := {&"win": "You win!", &"lose": "You lose", &"draw": "Draw"}
const PRIMARY := {&"win": "Back to title", &"lose": "Back to title", &"draw": "Replay"}
const WIDTH := 236.0
const HEIGHT := 104.0
const BUTTON_W := 104.0
const BUTTON_GAP := 8.0
const HEADING_Y := 14.0
const BUTTONS_Y := 60.0
const INTRO_SEC := 0.35

var _scrim: ColorRect
var _stage: PixelStage
var _window: NinePatchRect
var _heading: TextureRect
var _primary: Button
var _view: Button
var _result := &""
var _pulse: Tween


func _init() -> void:
	name = "EndScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = ColorRect.new()
	_scrim.color = UiKit.SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = PixelStage.new()
	add_child(_stage)
	_window = NinePatchRect.new()
	_window.texture = UiKit.texture(&"banner")
	var m: Array = UiKit.MARGINS[&"banner"]
	_window.patch_margin_left = m[0]
	_window.patch_margin_top = m[1]
	_window.patch_margin_right = m[2]
	_window.patch_margin_bottom = m[3]
	_window.size = Vector2(WIDTH, HEIGHT)
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.canvas.add_child(_window)
	_heading = _stage.add_image(HEADINGS[&"win"], Vector2.ZERO, _window)
	_view = _stage.add_button("View board", BUTTON_W, _window)
	_view.name = "ViewButton"
	_primary = _stage.add_button("Back to title", BUTTON_W, _window)
	_primary.name = "PrimaryButton"
	_view.position = Vector2(floorf(WIDTH * 0.5 - BUTTON_W - BUTTON_GAP * 0.5), BUTTONS_Y)
	_primary.position = Vector2(floorf(WIDTH * 0.5 + BUTTON_GAP * 0.5), BUTTONS_Y)
	_view.pressed.connect(view_pressed.emit)
	_primary.pressed.connect(primary_pressed.emit)
	_stage.relayout.connect(_layout)


func _layout() -> void:
	_window.position = (Vector2(_stage.game_size.x - WIDTH, _stage.game_size.y - HEIGHT) * 0.5).floor()


## &"win", &"lose" or &"draw": sets the heading and buttons.
func set_result(kind: StringName) -> void:
	_result = kind
	_heading.texture = HEADINGS[kind]
	_heading.size = _heading.texture.get_size()
	_heading.position = Vector2(floorf((WIDTH - _heading.size.x) * 0.5), HEADING_Y)
	_primary.text = PRIMARY[kind]


## The window pops open over a fading scrim; the heading then glows softly
## (brightness only, so the pixel letters stay crisp).
func play_intro(animated: bool = true) -> void:
	if not animated: # tests
		_window.scale = Vector2.ONE
		_window.modulate = Color.WHITE
		_scrim.modulate.a = 1.0
		return
	_window.pivot_offset = _window.size * 0.5
	_window.scale = Vector2(1.0, 0.0)
	_window.modulate = Color(2.5, 2.5, 2.5)
	_scrim.modulate.a = 0.0
	var intro := create_tween().set_parallel()
	intro.tween_property(_scrim, "modulate:a", 1.0, 0.25)
	intro.tween_property(_window, "scale", Vector2.ONE, INTRO_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_window, "modulate", Color.WHITE, INTRO_SEC + 0.05)
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_heading, "modulate", Color(1.25, 1.25, 1.25), 0.45).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_heading, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


func result_text() -> String:
	return TEXT.get(_result, "")


func primary_button() -> Button:
	return _primary


func view_button() -> Button:
	return _view
