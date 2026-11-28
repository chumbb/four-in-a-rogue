class_name DebugPanel
extends Control
## F4 debug picker (M6e; debug builds only, the scenario never builds it in a
## release build). A plain panel over a scrim that pauses the tree like the
## pause menu: pick a side (You / Opponent), give that side any roster Goob,
## discard a random Goob from its hand, add a test status, or force each
## side's deck (Auto, Random or a decklist; DeckBuilder) and start a new game
## with it. The scenario does the work through the signals.

signal toggle_requested
signal give_requested(goob: GoobDefinition, side: BoardState.CellOwner)
## Emitted after the panel closed (the reveal shows unpaused).
signal discard_requested(side: BoardState.CellOwner)
signal status_requested(side: BoardState.CellOwner)
## Emitted after the panel closed.
signal new_game_requested(forced: Dictionary)

const BUTTON_H := 96.0
const GAP := 8
const EDGE := 24
## Deck rows: button label prefix per forced key (labels must be unique).
const DECK_ROWS := {"player": "You: ", "opponent": "Him: "}
const AUTO := "Auto"

var _buttons: Dictionary = {} ## label -> Button
var _side := BoardState.CellOwner.PLAYER
## The picked deck per DECK_ROWS key (AUTO, DeckBuilder.RANDOM or a decklist name).
var _decks := {"player": AUTO, "opponent": AUTO}
var _box: VBoxContainer


func _init() -> void:
	name = "DebugPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var scrim := ColorRect.new()
	scrim.color = UiKit.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, EDGE)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", UiKit.stylebox(&"panel", 2))
	scroll.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", GAP)
	panel.add_child(_box)
	_build()


func _build() -> void:
	_label("Debug (F4)", &"Mono2")
	_label("Side")
	_choice_row(["You", "Opponent"], 2, func(label: String) -> void:
		_side = BoardState.CellOwner.PLAYER if label == "You" else BoardState.CellOwner.OPPONENT)
	_label("Give Goob")
	var grid := _grid(2)
	for goob in GoobRoster.all():
		var button := _button(goob.display_name, grid)
		button.pressed.connect(func() -> void: give_requested.emit(goob, _side))
	grid = _grid(2)
	_button("Discard random", grid).pressed.connect(func() -> void:
		close()
		discard_requested.emit(_side))
	_button("Add test status", grid).pressed.connect(func() -> void: status_requested.emit(_side))
	for key: String in DECK_ROWS:
		_label("Your deck" if key == "player" else "His deck")
		var labels: Array = []
		for choice in _deck_choices():
			labels.append(DECK_ROWS[key] + choice)
		_choice_row(labels, 2, func(label: String) -> void: _decks[key] = label.trim_prefix(DECK_ROWS[key]))
	grid = _grid(2)
	_button("New game with these", grid).pressed.connect(func() -> void:
		var picked := forced()
		close()
		new_game_requested.emit(picked))
	_button("Close", grid).pressed.connect(close)
	# M6g: check Sentry from an exported debug build (nothing is sent from F5).
	_label("Diagnostics")
	grid = _grid(2)
	_button("Test error", grid).pressed.connect(func() -> void:
		push_error("Debug panel: test error (M6g)"))
	_button("Test crash", grid).pressed.connect(func() -> void:
		if Engine.has_singleton("SentrySDK"):
			Engine.get_singleton("SentrySDK").call("get_bad_code").call("crash_with_abort"))


func _label(text: String, variation: StringName = &"") -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	_box.add_child(label)


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override(&"h_separation", GAP)
	grid.add_theme_constant_override(&"v_separation", GAP)
	_box.add_child(grid)
	return grid


func _button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = BUTTON_H
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	_buttons[text] = button
	return button


## Toggle buttons in one group (the first starts picked); a press calls
## `on_pick` with its label.
func _choice_row(labels: Array, columns: int, on_pick: Callable) -> void:
	var grid := _grid(columns)
	var group := ButtonGroup.new()
	for label: String in labels:
		var button := _button(label, grid)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void:
			_show_picked(label)
			on_pick.call(label))
	_show_picked(labels[0])


## Shows `label`'s toggle as the pressed one of its group.
func _show_picked(label: String) -> void:
	var picked: Button = _buttons[label]
	for button in picked.button_group.get_buttons():
		button.set_pressed_no_signal(button == picked)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		toggle_requested.emit()


func open() -> void:
	if visible:
		return
	get_tree().paused = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


func button(label: String) -> Button:
	return _buttons[label]


func _deck_choices() -> Array:
	var choices: Array = [AUTO, DeckBuilder.RANDOM]
	choices.append_array(DeckBuilder.decklist_names())
	return choices


## The chosen decks as DeckBuilder.roll_pair's `forced` ({} = both Auto).
func forced() -> Dictionary:
	var result := {}
	for key: String in _decks:
		if _decks[key] != AUTO:
			result[key] = _decks[key]
	return result


## Shows `decks` (GameFlow.debug_forced_categories) as the picked choices.
func set_forced(decks: Dictionary) -> void:
	for key: String in DECK_ROWS:
		var picked: String = decks.get(key, AUTO)
		if not _deck_choices().has(picked):
			picked = AUTO
		_decks[key] = picked
		_show_picked(DECK_ROWS[key] + picked)


func _exit_tree() -> void:
	# Never leave the tree paused behind a freed panel.
	if visible and is_inside_tree():
		get_tree().paused = false
