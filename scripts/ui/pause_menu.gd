class_name PauseMenu
extends Control
## Pause menu (slice §2B; Art B mock 4): Resume / Options / Quit in a window
## over a scrim. While it is open the scene tree is paused, so the turn timer,
## the opponent, every animation and the game's sounds stop (this menu and its
## sounds keep running). Quit asks "Quit this scenario?" (Quit / Cancel) and
## goes to the Title: no scoring, not a loss. Decklist (Sean, 2026-11-27) shows
## your deck: its decklist name, its specials by rarity and each rarity's count.
## Tapping a special there opens the inspect view over it; the next tap closes it.

signal opened
signal resumed

const WIDTH := 180.0
const BUTTON_W := 140.0
const CONFIRM_W := 250.0
const CONFIRM_BUTTON_W := 100.0
const GOLD_HI := Color("fbb954")
const DECK_W := 240.0
const DECK_HEAD_H := 14.0
## Goob plates: two per row, 36 game px tall (the 96 px touch floor).
const DECK_PLATE_H := 36.0
const DECK_PLATE_GAP := 4.0
const DECK_PAD := 10.0
const DECK_BUTTON_W := 100.0
const RARITY_NAMES := {GoobDefinition.Rarity.LEGENDARY: "Legendary", GoobDefinition.Rarity.VERY_RARE: "Very rare", GoobDefinition.Rarity.RARE: "Rare", GoobDefinition.Rarity.COMMON: "Goob"}

var _scrim: ColorRect
var _stage: PixelStage
var _menu: NinePatchRect
var _confirm: NinePatchRect
var _deck: NinePatchRect
var _deck_name := ""
var _deck_goobs: Array[GoobDefinition] = []
var _inspect_px := 0.0
var _inspect: InspectPanel
## Over the deck window while the inspect view is open: the next tap closes it.
var _inspect_blocker: Control
var _options: OptionsPanel
var _sfx: Sfx
var _buttons: Dictionary = {} ## label -> Button


func _init() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Above everything in the scene, incl. a drawn Goob popping in at the centre
	# (HandView raises it to z 20; Sean, M6c playtest).
	z_index = 100
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
	_menu = _window(Vector2(WIDTH, 212))
	_title(_menu, "Paused")
	for i in 4:
		var label: String = ["Resume", "Decklist", "Options", "Quit"][i]
		var button := _stage.add_button(label, BUTTON_W, _menu)
		button.position = Vector2((WIDTH - BUTTON_W) * 0.5, 46.0 + i * 40.0)
		_buttons[label] = button
	_buttons["Resume"].pressed.connect(resume)
	_buttons["Decklist"].pressed.connect(_on_decklist)
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
	_inspect = InspectPanel.new()
	add_child(_inspect)
	_inspect_blocker = Control.new()
	_inspect_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_blocker.visible = false
	add_child(_inspect_blocker)
	_inspect_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect_blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			close_inspect())
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
	for window: NinePatchRect in [_menu, _confirm, _deck]:
		if window == null:
			continue
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
	_hide_inspect()
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


func is_viewing_deck() -> bool:
	return visible and _deck != null and _deck.visible


## Your deck for the Decklist window (`deck_name` "" = no decklist name);
## `inspect_px`: the inspect view's big Goob size (as on the board).
func set_deck(deck_name: String, goobs: Array[GoobDefinition], inspect_px: float) -> void:
	_deck_name = deck_name
	_deck_goobs = goobs
	_inspect_px = inspect_px


func is_inspecting() -> bool:
	return visible and _inspect.is_open()


func close_inspect() -> void:
	if not _inspect.is_open():
		return
	_hide_inspect()
	_sfx.play(&"inspect_close")


func _hide_inspect() -> void:
	_inspect.close()
	_inspect_blocker.visible = false


func _on_deck_goob(goob: GoobDefinition) -> void:
	_sfx.play(&"inspect_open")
	_inspect.open(goob, BoardState.CellOwner.PLAYER, _inspect_px)
	_inspect_blocker.visible = true


## Back to the pause menu from the Quit confirm or the Decklist (button / Esc).
func back_to_menu() -> void:
	_sfx.play(&"ui_tap")
	_show(_menu)


func _show(window: NinePatchRect) -> void:
	_menu.visible = window == _menu
	_confirm.visible = window == _confirm
	if _deck != null:
		_deck.visible = window == _deck


func _on_decklist() -> void:
	_sfx.play(&"ui_tap")
	_build_deck()
	_show(_deck)


## The Decklist window, rebuilt each time: name, then per rarity (legendary
## first) "<Rarity> (n)" and its specials in deck order as tappable plates
## (two per row), then the plain Goob count.
func _build_deck() -> void:
	if _deck != null:
		_deck.free()
		_buttons.erase("DeckBack")
	var groups := {}
	for rarity in RARITY_NAMES:
		groups[rarity] = []
	for goob in _deck_goobs:
		var rarity: GoobDefinition.Rarity = goob.rarity if goob.is_special() else GoobDefinition.Rarity.COMMON
		groups[rarity].append(goob)
	var height := 44.0
	for rarity in groups:
		var count: int = groups[rarity].size()
		if count == 0:
			continue
		height += DECK_HEAD_H + 4.0
		if rarity != GoobDefinition.Rarity.COMMON:
			height += ceili(count / 2.0) * (DECK_PLATE_H + DECK_PLATE_GAP)
	_deck = _window(Vector2(DECK_W, height + 48.0))
	_title(_deck, _deck_name if _deck_name != "" else "Your deck")
	var plate_w := floorf((DECK_W - DECK_PAD * 2.0 - DECK_PLATE_GAP) * 0.5)
	var y := 44.0
	for rarity in groups:
		var goobs: Array = groups[rarity]
		if goobs.is_empty():
			continue
		var head := _stage.add_label("%s (%d)" % [RARITY_NAMES[rarity], goobs.size()], GOLD_HI, &"", _deck)
		head.position = Vector2(DECK_PAD + 2.0, y)
		y += DECK_HEAD_H
		if rarity != GoobDefinition.Rarity.COMMON:
			for i in goobs.size():
				var goob: GoobDefinition = goobs[i]
				var plate := _deck_plate(goob, Vector2(plate_w, DECK_PLATE_H))
				plate.position = Vector2(DECK_PAD + (i % 2) * (plate_w + DECK_PLATE_GAP), y + (i / 2) * (DECK_PLATE_H + DECK_PLATE_GAP))
			y += ceili(goobs.size() / 2.0) * (DECK_PLATE_H + DECK_PLATE_GAP)
		y += 4.0
	var back := _stage.add_button("Back", DECK_BUTTON_W, _deck)
	back.position = Vector2((DECK_W - DECK_BUTTON_W) * 0.5, y + 4.0)
	back.pressed.connect(back_to_menu)
	_buttons["DeckBack"] = back
	_layout()


## A tappable Goob name on a segment plate; opens its inspect view.
func _deck_plate(goob: GoobDefinition, size_px: Vector2) -> Button:
	var plate := Button.new()
	plate.name = "Deck_" + goob.id
	plate.text = goob.display_name.trim_suffix(" Goob") # "Distracting Goob" won't fit a plate
	plate.focus_mode = Control.FOCUS_NONE
	plate.clip_text = true
	for state: StringName in [&"normal", &"hover"]:
		plate.add_theme_stylebox_override(state, UiKit.stylebox(&"segment_normal"))
	for state: StringName in [&"pressed", &"hover_pressed"]:
		plate.add_theme_stylebox_override(state, UiKit.stylebox(&"segment_pressed"))
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		plate.add_theme_color_override(state, PixelStage.CREAM)
	plate.pressed.connect(_on_deck_goob.bind(goob))
	_deck.add_child(plate)
	plate.size = size_px
	return plate


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
	back_to_menu()


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
