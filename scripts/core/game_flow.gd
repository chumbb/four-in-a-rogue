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
## Draw replay skips Strange Man and goes straight to coin flip (v0.1 rules).
var skip_strange_man_on_next_run: bool = false


func go_to(key: SceneKey) -> void:
	var path: String = SCENE_PATHS.get(key, "")
	if path.is_empty():
		push_error("GameFlow: unknown scene key %s" % str(key))
		return
	get_tree().change_scene_to_file(path)


func begin_play_flow_from_title() -> void:
	if skip_strange_man_on_next_run:
		skip_strange_man_on_next_run = false
		go_to(SceneKey.COIN_FLIP)
	else:
		go_to(SceneKey.STRANGE_MAN)


func return_to_title() -> void:
	go_to(SceneKey.TITLE)
