class_name PauseMenu
extends Control
## Pause menu (slice §2B; Art B mock 4): Resume / Options / Quit in a window
## over a scrim. While it is open the scene tree is paused, so the turn timer,
## the opponent, every animation and the game's sounds stop (this menu and its
## sounds keep running). Quit asks "Quit this scenario?" (Quit / Cancel) and
## goes to the Title: no scoring, not a loss.

signal opened
signal resumed

const WIDTH := 180.0
const BUTTON_W := 140.0
const CONFIRM_W := 250.0
const CONFIRM_BUTTON_W := 100.0
const GOLD_HI := Color("fbb954")

var _scrim: ColorRect
var _stage: PixelStage
var _menu: NinePatchRect
var _confirm: NinePatchRect
var _options: OptionsPanel
var _sfx: Sfx
var _buttons: Dictionary = {} ## label -> Button


func _init() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim = ColorRect.new()
	_scrim.color = UiKit.SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = PixelStage.new()
	add_child(_stage)
	_sfx = Sfx.new()
	add_child(_sfx)
	_menu = _window(Vector2(WIDTH, 172))
	_title(_menu, "Paused")
	for i in 3:
		var label: String = ["Resume", "Options", "Quit"][i]
		var button := _stage.add_button(label, BUTTON_W, _menu)
		button.position = Vector2((WIDTH - BUTTON_W) * 0.5, 46.0 + i * 40.0)
		_buttons[label] = button
	_buttons["Resume"].pressed.connect(resume)
	_buttons["Options"].pressed.connect(_on_options)
	_buttons["Quit"].pressed.connect(_on_quit)
	_confirm = _window(Vector2(CONFIRM_W, 100))
	_title(_confirm, "Quit this scenario?")
	for i in 2:
		var label: String = ["Quit", "Cancel"][i]
		var button := _stage.add_button(label, CONFIRM_BUTTON_W, _confirm)
		button.position = Vector2(CONFIRM_W * 0.5 + (-CONFIRM_BUTTON_W - 5.0 if i == 0 else 5.0), 52)
		_buttons["Confirm" + label] = button
	_buttons["ConfirmQuit"].pressed.connect(_on_confirm_quit)
	_buttons["ConfirmCancel"].pressed.connect(_on_cancel)
	_options = OptionsPanel.new()
	add_child(_options)
	_options.closed.connect(_on_options_closed)
	_stage.relayout.connect(_layout)


func _window(size_px: Vector2) -> NinePatchRect:
	var window := NinePatchRect.new()
	window.texture = UiKit.texture(&"window")
	var m: Array = UiKit.MARGINS[&"window"]
	window.patch_margin_left = m[0]
	window.patch_margin_top = m[1]
	window.patch_margin_right = m[2]
	window.patch_margin_bottom = m[3]
	window.size = size_px
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.canvas.add_child(window)
	return window


func _title(window: NinePatchRect, text: String) -> void:
	var label := _stage.add_label(text, GOLD_HI, &"Mono2", window)
	label.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(window.size.x, 32)
	label.position = Vector2(0, 8)


func _layout() -> void:
	for window: NinePatchRect in [_menu, _confirm]:
		window.position = (Vector2(_stage.game_size.x - window.size.x, _stage.game_size.y - window.size.y) * 0.5).floor()


func open() -> void:
	if visible:
		return
	get_tree().paused = true
	_show(_menu)
	visible = true
	_sfx.play(&"pause_open")
	opened.emit()


func resume() -> void:
	if not visible:
		return
	visible = false
	_options.visible = false
	get_tree().paused = false
	_sfx.play(&"pause_close")
	resumed.emit()


func is_open() -> bool:
	return visible


func button(label: String) -> Button:
	return _buttons[label]


func options() -> OptionsPanel:
	return _options


func is_confirming() -> bool:
	return visible and _confirm.visible


func _show(window: NinePatchRect) -> void:
	_menu.visible = window == _menu
	_confirm.visible = window == _confirm


func _on_options() -> void:
	_sfx.play(&"ui_tap")
	_show(null)
	_options.open(false)


func _on_options_closed() -> void:
	if visible:
		_show(_menu)


func _on_quit() -> void:
	_sfx.play(&"ui_tap")
	_show(_confirm)


func _on_cancel() -> void:
	_sfx.play(&"ui_tap")
	_show(_menu)


## Not a loss: straight back to the Title (black fade).
func _on_confirm_quit() -> void:
	_sfx.play(&"ui_tap")
	get_tree().paused = false
	_show(null)
	GameFlow.return_to_title()


func _exit_tree() -> void:
	# Never leave the tree paused behind a freed menu.
	if visible and is_inside_tree():
		get_tree().paused = false
