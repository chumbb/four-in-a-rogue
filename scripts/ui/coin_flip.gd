extends Control

@onready var _result_label: Label = %ResultLabel

var _player_choice_heads: bool = true
var _resolved: bool = false


func _ready() -> void:
	_result_label.text = "Choose heads or tails, then flip."


func _on_heads_pressed() -> void:
	_player_choice_heads = true
	_update_choice_hint()


func _on_tails_pressed() -> void:
	_player_choice_heads = false
	_update_choice_hint()


func _update_choice_hint() -> void:
	if _resolved:
		return
	_result_label.text = "You chose: %s — press Flip." % ("Heads" if _player_choice_heads else "Tails")


func _on_flip_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	var flip_is_heads := randi() % 2 == 0
	var player_won := _player_choice_heads == flip_is_heads
	GameFlow.player_moves_first = player_won
	_result_label.text = (
		"Flip: %s — %s moves first. (Stub animation TBD)"
		% ["Heads" if flip_is_heads else "Tails", "You" if player_won else "Opponent"]
	)
	%ContinueButton.disabled = false


func _on_continue_pressed() -> void:
	GameFlow.go_to(GameFlow.SceneKey.SCENARIO)
