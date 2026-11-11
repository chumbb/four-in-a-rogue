extends Control

@onready var _prompt: Label = %PressStartLabel


func _ready() -> void:
	_prompt.text = "Press Start"


## True for a pressed left mouse button or ui_accept.
static func is_press_start(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed("ui_accept")


func _unhandled_input(event: InputEvent) -> void:
	if is_press_start(event):
		get_viewport().set_input_as_handled()
		GameFlow.begin_play_flow_from_title()
