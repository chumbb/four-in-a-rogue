extends Control
## Title (slice §2B, Art pass B mock 1): the painted Goob kingdom vista (its
## painted Goobs are the idle Goobs; Sean 2026-11-20), pixel logo, pulsing
## "Tap to start", Options, and Quit on desktop builds only. Tapping anywhere
## except a button is Press Start.

const LOGO := preload("res://assets/ui/logo.png")
const LOGO_Y := 60.0
const PROMPT_GAP := 176.0 ## logo top → "Tap to start" top (mock: 60 → 236)
const PULSE_SEC := 0.7
const BUTTON_GAP := 6.0
const QUIT_BOTTOM := 458.0 ## mock: Quit bottom on the 480-tall design
const DESIGN_HEIGHT := 480.0

var _stage: PixelStage
var _logo: TextureRect
var _prompt: Label
var _options: Button
var _quit: Button
var _options_panel: OptionsPanel
var _started := false


func _ready() -> void:
	add_child(GameFlow.make_vignette())
	_stage = PixelStage.new()
	add_child(_stage)
	_logo = _stage.add_image(LOGO)
	_prompt = _stage.add_label("Tap to start", PixelStage.WHITE, &"Mono2")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	_prompt.add_theme_constant_override(&"shadow_offset_x", 0)
	_prompt.add_theme_constant_override(&"shadow_offset_y", 2)
	_options = _stage.add_button("Options", 120)
	_options.pressed.connect(_on_options_pressed)
	_quit = _stage.add_button("Quit", 80)
	_quit.pressed.connect(_on_quit_pressed)
	_quit.visible = OS.has_feature("pc") # never on phones
	_stage.relayout.connect(_layout)
	_options_panel = OptionsPanel.new()
	add_child(_options_panel)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_prompt, "modulate:a", 0.35, PULSE_SEC).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_prompt, "modulate:a", 1.0, PULSE_SEC).set_trans(Tween.TRANS_SINE)


## The mock's 480-tall layout, centred on taller screens, kept inside the safe area.
func _layout() -> void:
	var safe := _stage.safe
	var w := _stage.game_size.x
	var top := floorf((_stage.game_size.y - DESIGN_HEIGHT) * 0.5)
	_logo.position = Vector2(floorf((w - LOGO.get_width()) * 0.5), maxf(top + LOGO_Y, safe.position.y + 12.0))
	_prompt.size = Vector2(w, 32)
	_prompt.position = Vector2(0, _logo.position.y + PROMPT_GAP)
	var bottom := minf(top + QUIT_BOTTOM, safe.end.y - 8.0)
	if _quit.visible:
		_quit.position = Vector2(floorf((w - _quit.size.x) * 0.5), bottom - _quit.size.y)
		bottom = _quit.position.y - BUTTON_GAP
	_options.position = Vector2(floorf((w - _options.size.x) * 0.5), bottom - _options.size.y)


## True for a touch press (a mouse click on desktop, via touch emulation) or
## ui_accept (Enter / Space). Mouse events are ignored, or a click would count
## twice (the click plus its emulated touch).
static func is_press_start(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouse:
		return false
	return event.is_action_pressed("ui_accept")


## _input, not _unhandled_input: tapping anywhere on the screen counts, except
## on the Options / Quit buttons.
func _input(event: InputEvent) -> void:
	# Desktop Esc closes Options (Sean, M6f 2026-11-24).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _options_panel.is_open() and not OS.has_feature("mobile"):
			get_viewport().set_input_as_handled()
			_options_panel._on_back()
		return
	if _started or GameFlow.is_fading() or _options_panel.is_open() or not is_press_start(event):
		return
	if event is InputEventScreenTouch and PixelStage.touches_button(self, event.position):
		return
	get_viewport().set_input_as_handled()
	_started = true # one Press Start per visit
	GameFlow.sfx.play(&"press_start")
	GameFlow.begin_play_flow_from_title()


## The shared Options panel (M6b), over a scrim.
func _on_options_pressed() -> void:
	GameFlow.sfx.play(&"ui_tap")
	_options_panel.open()


func _on_quit_pressed() -> void:
	GameFlow.sfx.play(&"ui_tap")
	get_tree().quit()
