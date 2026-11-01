extends Control

const OPENING_DIALOGUE := (
	"Hey, you must not be from around here. This is a land of Goobs. "
	+ "If you want to progress, you'll need to get 4 goobs in a row before your opponent does. "
	+ "You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know..."
)


func _ready() -> void:
	%DialogueLabel.text = OPENING_DIALOGUE


func _on_continue_pressed() -> void:
	GameFlow.go_to(GameFlow.SceneKey.COIN_FLIP)
