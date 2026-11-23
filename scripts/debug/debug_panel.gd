class_name DebugPanel
extends Control
## F4 debug picker (M6e; debug builds only, the scenario never builds it in a
## release build). A plain panel over a scrim that pauses the tree like the
## pause menu: pick a side (You / Opponent), give that side any roster Goob,
## discard a random Goob from its hand, add a test status, or force the
## category deck roll (top pool Auto / Unique / Tech, main pool Auto or a pair
## of Move / Destroy / Discard) and start a new game with it. The scenario
## does the work through the signals.

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
const C := GoobDefinition.Category
const TOP_CHOICES: Dictionary = {"Auto top": -1, "Unique": C.UNIQUE, "Tech": C.TECH}
const MAIN_CHOICES: Dictionary = {
	"Auto main": [],
	"Move + Destroy": [C.MOVE, C.DESTROY],
	"Move + Discard": [C.MOVE, C.DISCARD],
	"Destroy + Discard": [C.DESTROY, C.DISCARD],
}

var _buttons: Dictionary = {} ## label -> Button
var _side := BoardState.CellOwner.PLAYER
## The picked TOP_CHOICES / MAIN_CHOICES labels.
var _top := "Auto top"
var _main := "Auto main"
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
	_label("Deck top pool")
	_choice_row(TOP_CHOICES.keys(), 3, func(label: String) -> void: _top = label)
	_label("Deck main pool")
	_choice_row(MAIN_CHOICES.keys(), 2, func(label: String) -> void: _main = label)
	grid = _grid(2)
	_button("New game with these", grid).pressed.connect(func() -> void:
		var picked := forced()
		close()
		new_game_requested.emit(picked))
	_button("Close", grid).pressed.connect(close)


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


## The chosen categories as DeckBuilder's `forced` ({} = all Auto).
func forced() -> Dictionary:
	var result := {}
	if TOP_CHOICES[_top] != -1:
		result["top"] = TOP_CHOICES[_top]
	if not MAIN_CHOICES[_main].is_empty():
		result["main"] = MAIN_CHOICES[_main].duplicate()
	return result


## Shows `categories` (GameFlow.debug_forced_categories) as the picked choices.
func set_forced(categories: Dictionary) -> void:
	_top = "Auto top"
	_main = "Auto main"
	for label: String in TOP_CHOICES:
		if categories.has("top") and TOP_CHOICES[label] == categories["top"]:
			_top = label
	var main: Array = categories.get("main", [])
	for label: String in MAIN_CHOICES:
		var pair: Array = MAIN_CHOICES[label]
		if main.size() == 2 and pair.size() == 2 and main.has(pair[0]) and main.has(pair[1]):
			_main = label
	_show_picked(_top)
	_show_picked(_main)


func _exit_tree() -> void:
	# Never leave the tree paused behind a freed panel.
	if visible and is_inside_tree():
		get_tree().paused = false
