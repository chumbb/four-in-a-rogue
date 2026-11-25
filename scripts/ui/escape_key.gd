class_name EscapeKey
extends Node
## Desktop Esc (Sean, M6f 2026-11-24): runs even while the tree is paused
## (menus pause it) and hands the key to `handler`, which closes the topmost
## menu and returns true when it used the key. Never on mobile builds.

var handler: Callable


func _init(on_escape: Callable) -> void:
	name = "EscapeKey"
	handler = on_escape
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if OS.has_feature("mobile") or not handler.is_valid():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if handler.call():
			get_viewport().set_input_as_handled()
