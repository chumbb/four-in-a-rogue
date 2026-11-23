class_name OptionsPanel
extends Control
## Options (slice §2B; Art B mock 5), opened from the title and the pause menu:
## one window over a scrim. Rows are 38 game px (≥ 96 px at the 720 base):
## Speed Normal / Fast · Haptics · Screen shake · Auto-flip coin (tap
## anywhere on an On/Off row) · Auto-play button (debug builds only) · Master / Music / SFX (slider in 5 % steps + a
## speaker mute button) · Back. Every change applies and saves at once
## (Settings). Works while the tree is paused.

signal closed

const ROW_H := 38.0
const WIDTH := 254.0
const FIRST_ROW_Y := 40.0
const LABEL_X := 12.0
const SPEEDS := [["Normal", 72.0], ["Fast", 72.0]] ## Skip removed (Sean, 2026-11-22)
const SPEED_X := 84.0
const TOGGLES := [[&"haptics", "Haptics"], [&"screen_shake", "Screen shake"], [&"auto_flip", "Auto-flip coin"]]
## Debug builds add this row after TOGGLES (M6e auto-play).
const DEBUG_TOGGLE := [&"autoplay_button", "Auto-play button"]
const BUSES := [[&"Master", "Master"], [&"Music", "Music"], [&"SFX", "SFX"]]
const SLIDER_X := 56.0
## (151 − 11 px knob) / 20 steps = 7 game px per 5 %, so the knob always sits
## on whole game pixels.
const SLIDER_W := 151.0
const SLIDER_STEP := 0.05
const MUTE_VISUAL := Vector2(26, 30)
const MUTE_HIT := 36.0
const BACK_W := 100.0
const GOLD_HI := Color("fbb954")
const OFF_GREY := Color("9babb2")
const TOGGLE_ON := preload("res://assets/ui/toggle_on.png")
const TOGGLE_OFF := preload("res://assets/ui/toggle_off.png")
const SPEAKER := preload("res://assets/ui/icon_speaker.png")
const SPEAKER_MUTED := preload("res://assets/ui/icon_speaker_muted.png")

var _scrim: ColorRect
var _stage: PixelStage
var _window: NinePatchRect
var _segments: Array[Button] = []
var _toggles: Dictionary = {} ## setting -> [TextureRect, Label]
var _sliders: Dictionary = {} ## bus -> HSlider
var _mutes: Dictionary = {} ## bus -> TextureRect (speaker icon)
var _back: Button
var _sfx: Sfx
var _syncing := false

static var _slider_theme: Theme


func _init() -> void:
	name = "Options"
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
	_build()
	_stage.relayout.connect(_layout)


## `with_scrim` false when another menu's scrim is already up (pause).
func open(with_scrim := true) -> void:
	_scrim.visible = with_scrim
	_sync()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _build() -> void:
	_window = NinePatchRect.new()
	_window.texture = UiKit.texture(&"window")
	var m: Array = UiKit.MARGINS[&"window"]
	_window.patch_margin_left = m[0]
	_window.patch_margin_top = m[1]
	_window.patch_margin_right = m[2]
	_window.patch_margin_bottom = m[3]
	var toggles := _toggle_rows()
	_window.size = Vector2(WIDTH, FIRST_ROW_Y + ROW_H * (1 + toggles.size() + BUSES.size()) + 52.0)
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.canvas.add_child(_window)
	var title := _shadowed(_stage.add_label("Options", GOLD_HI, &"Mono2", _window), 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(WIDTH, 32)
	title.position = Vector2(0, 6)
	var y := FIRST_ROW_Y
	_row_label("Speed", y)
	var x := SPEED_X
	for i in SPEEDS.size():
		var seg := Button.new()
		seg.text = SPEEDS[i][0]
		seg.focus_mode = Control.FOCUS_NONE
		seg.pressed.connect(_on_speed.bind(i))
		_window.add_child(seg)
		seg.size = Vector2(SPEEDS[i][1], 36)
		seg.position = Vector2(x, y + 1)
		_segments.append(seg)
		x += SPEEDS[i][1] - 1.0
	y += ROW_H
	for entry: Array in toggles:
		var row := _flat_button(Vector2(6, y + 1), Vector2(WIDTH - 12, 36))
		row.name = String(entry[0])
		row.pressed.connect(_on_toggle.bind(entry[0]))
		_shadowed(_stage.add_label(entry[1], PixelStage.CREAM, &"", row)).position = Vector2(LABEL_X - 6, 9)
		var knob := _stage.add_image(TOGGLE_ON, Vector2(WIDTH - 12 - 30 - 26 - 6, 10), row)
		var state := _shadowed(_stage.add_label("On", PixelStage.CREAM, &"", row))
		state.position = Vector2(WIDTH - 12 - 20 - 6, 9)
		_toggles[entry[0]] = [knob, state]
		y += ROW_H
	for entry: Array in BUSES:
		var bus: StringName = entry[0]
		_row_label(entry[1], y)
		var slider := HSlider.new()
		slider.name = String(bus)
		slider.theme = _theme_for_slider()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = SLIDER_STEP
		slider.focus_mode = Control.FOCUS_NONE
		slider.position = Vector2(SLIDER_X, y + 1)
		slider.size = Vector2(SLIDER_W, 36)
		slider.value_changed.connect(_on_volume.bind(bus))
		_window.add_child(slider)
		_sliders[bus] = slider
		var mute := _flat_button(Vector2(WIDTH - 12 - MUTE_VISUAL.x * 0.5 - MUTE_HIT * 0.5, y + 1), Vector2(MUTE_HIT, MUTE_HIT))
		mute.name = "Mute" + String(bus)
		mute.pressed.connect(_on_mute.bind(bus))
		var plate := NinePatchRect.new()
		plate.texture = UiKit.texture(&"segment_normal")
		var sm: Array = UiKit.MARGINS[&"segment_normal"]
		plate.patch_margin_left = sm[0]
		plate.patch_margin_top = sm[1]
		plate.patch_margin_right = sm[2]
		plate.patch_margin_bottom = sm[3]
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.size = MUTE_VISUAL
		plate.position = ((Vector2(MUTE_HIT, MUTE_HIT) - MUTE_VISUAL) * 0.5).floor()
		mute.add_child(plate)
		_mutes[bus] = _stage.add_image(SPEAKER, Vector2(8, 10), plate)
		y += ROW_H
	_back = _stage.add_button("Back", BACK_W, _window)
	_back.position = Vector2(floorf((WIDTH - BACK_W) * 0.5), y + 4)
	_back.pressed.connect(_on_back)


## TOGGLES, plus the Auto-play button row in debug builds.
static func _toggle_rows() -> Array:
	var rows := TOGGLES.duplicate()
	if OS.is_debug_build():
		rows.append(DEBUG_TOGGLE)
	return rows


func _row_label(text: String, y: float) -> void:
	_shadowed(_stage.add_label(text, PixelStage.CREAM, &"", _window)).position = Vector2(LABEL_X, y + 10)


func _shadowed(label: Label, drop := 1) -> Label:
	label.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", drop)
	return label


## An invisible button (the whole row or a large hit area round a small
## visual), so every target is ≥ 36 game px.
func _flat_button(pos: Vector2, size_px: Vector2) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.position = pos
	button.size = size_px
	_window.add_child(button)
	return button


func _layout() -> void:
	var safe := _stage.safe
	var y := floorf((_stage.game_size.y - _window.size.y) * 0.5)
	y = clampf(y, safe.position.y, maxf(safe.position.y, safe.end.y - _window.size.y))
	_window.position = Vector2(floorf((_stage.game_size.x - WIDTH) * 0.5), y)
	# Built before entering the tree, the segments measured the default font
	# and grew; now the pixel theme applies, set their widths again.
	for i in _segments.size():
		_segments[i].size = Vector2(SPEEDS[i][1], 36)


## Shows the current Settings.
func _sync() -> void:
	_syncing = true
	for i in _segments.size():
		var seg := _segments[i]
		var selected := i == int(Settings.speed)
		var normal := UiKit.stylebox(&"segment_selected" if selected else &"segment_normal")
		seg.add_theme_stylebox_override(&"normal", normal)
		seg.add_theme_stylebox_override(&"hover", normal)
		seg.add_theme_stylebox_override(&"pressed", UiKit.stylebox(&"segment_pressed"))
		seg.add_theme_stylebox_override(&"hover_pressed", UiKit.stylebox(&"segment_pressed"))
		var colour := PixelStage.INK0 if selected else PixelStage.CREAM
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			seg.add_theme_color_override(state, colour)
	for key: StringName in _toggles:
		var on: bool = Settings.get(key)
		var parts: Array = _toggles[key]
		(parts[0] as TextureRect).texture = TOGGLE_ON if on else TOGGLE_OFF
		var state: Label = parts[1]
		state.text = "On" if on else "Off"
		state.add_theme_color_override(&"font_color", PixelStage.CREAM if on else OFF_GREY)
	for bus: StringName in _sliders:
		(_sliders[bus] as HSlider).value = Settings.volume[bus]
		(_mutes[bus] as TextureRect).texture = SPEAKER_MUTED if Settings.muted[bus] else SPEAKER
	_syncing = false


func _on_speed(index: int) -> void:
	_sfx.play(&"ui_tap")
	Settings.set_speed(index as Settings.Speed)
	_sync()


func _on_toggle(key: StringName) -> void:
	_sfx.play(&"ui_tap")
	match key:
		&"haptics":
			Settings.set_haptics(not Settings.haptics)
			Settings.vibrate() # feel it when it turns on
		&"screen_shake":
			Settings.set_screen_shake(not Settings.screen_shake)
		&"auto_flip":
			Settings.set_auto_flip(not Settings.auto_flip)
		&"autoplay_button":
			Settings.set_autoplay_button(not Settings.autoplay_button)
	_sync()


func _on_volume(value: float, bus: StringName) -> void:
	if _syncing:
		return
	Settings.set_volume(bus, value)
	_sfx.play(&"slider_tick")


func _on_mute(bus: StringName) -> void:
	Settings.set_muted(bus, not Settings.muted[bus])
	_sfx.play(&"ui_tap")
	_sync()


func _on_back() -> void:
	_sfx.play(&"ui_tap")
	close()


## Kit slider: groove 9-slice, honey fill up to the knob, round knob.
static func _theme_for_slider() -> Theme:
	if _slider_theme:
		return _slider_theme
	var theme := Theme.new()
	var track := UiKit.stylebox(&"slider_track")
	var fill := UiKit.stylebox(&"slider_fill")
	for box: StyleBoxTexture in [track, fill]:
		# Draw at the art's 7 px height (the minimum height sets the groove).
		box.content_margin_top = 3
		box.content_margin_bottom = 4
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var knob: Texture2D = UiKit.texture(&"slider_knob")
	var knob_pressed: Texture2D = UiKit.texture(&"slider_knob_pressed")
	theme.set_icon(&"grabber", &"HSlider", knob)
	theme.set_icon(&"grabber_highlight", &"HSlider", knob_pressed)
	theme.set_icon(&"grabber_disabled", &"HSlider", knob)
	theme.set_icon(&"tick", &"HSlider", ImageTexture.new())
	_slider_theme = theme
	return theme
