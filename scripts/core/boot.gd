extends Control


func _ready() -> void:
	# Deferred: changing scene inside the first scene's _ready() errors
	# ("Parent node is busy adding/removing children").
	GameFlow.go_to.call_deferred(GameFlow.SceneKey.TITLE)
