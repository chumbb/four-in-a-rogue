extends Control

@onready var _prompt: Label = %PressStartLabel


func _ready() -> void:
	_prompt.text = "Press Start"


## True for a touch press (a mouse click on desktop, via touch emulation) or
## ui_accept (Enter / Space). Mouse events are ignored, or a click would count
## twice (the click plus its emulated touch).
static func is_press_start(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouse:
		return false
	return event.is_action_pressed("ui_accept")


## _input, not _unhandled_input: tapping anywhere on the screen counts.
func _input(event: InputEvent) -> void:
	if is_press_start(event):
		get_viewport().set_input_as_handled()
		set_process_input(false) # one Press Start per visit
		GameFlow.begin_play_flow_from_title()
