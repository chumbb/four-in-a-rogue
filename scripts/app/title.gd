extends Control

@onready var _prompt: Label = %PressStartLabel


func _ready() -> void:
	_prompt.text = "Press Start"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		GameFlow.begin_play_flow_from_title()
