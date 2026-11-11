extends Node
## Scene flow for M1 shell: title → strange man → coin flip → scenario.

enum SceneKey {
	BOOT,
	TITLE,
	STRANGE_MAN,
	COIN_FLIP,
	SCENARIO,
}

const SCENE_PATHS: Dictionary = {
	SceneKey.BOOT: "res://scenes/app/boot.tscn",
	SceneKey.TITLE: "res://scenes/app/title.tscn",
	SceneKey.STRANGE_MAN: "res://scenes/app/strange_man.tscn",
	SceneKey.COIN_FLIP: "res://scenes/ui/coin_flip.tscn",
	SceneKey.SCENARIO: "res://scenes/scenario/scenario.tscn",
}

## Set after coin flip stub; true = player moves first.
var player_moves_first: bool = true


## F3 (debug builds only) toggles simulated phone safe-area insets (§2A).
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		SafeArea.simulate_insets = not SafeArea.simulate_insets
		get_tree().call_group(SafeArea.GROUP, "apply")
		get_viewport().set_input_as_handled()


func go_to(key: SceneKey) -> void:
	var path: String = SCENE_PATHS.get(key, "")
	if path.is_empty():
		push_error("GameFlow: unknown scene key %s" % str(key))
		return
	get_tree().change_scene_to_file(path)


func begin_play_flow_from_title() -> void:
	go_to(SceneKey.STRANGE_MAN)


## Draw replay skips Title and Strange Man: straight back to the coin flip.
func replay_after_draw() -> void:
	go_to(SceneKey.COIN_FLIP)


func return_to_title() -> void:
	go_to(SceneKey.TITLE)
