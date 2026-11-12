extends Control

## Time to read the result before the scenario loads. The whole flip, from
## pressing Flip to play starting, must stay within 3 s (Sean, 2026-11-11).
const RESULT_HOLD_SEC := 1.5

@onready var _result_label: Label = %ResultLabel
@onready var _heads_button: Button = %HeadsButton
@onready var _tails_button: Button = %TailsButton
@onready var _flip_button: Button = %FlipButton

var _player_choice_heads: bool = true
var _resolved: bool = false
var _hold_timer: Timer


func _ready() -> void:
	_result_label.text = "Choose heads or tails, then flip."
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.timeout.connect(_on_hold_timeout)
	add_child(_hold_timer)


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
	_heads_button.disabled = true
	_tails_button.disabled = true
	_flip_button.disabled = true
	var flip_is_heads := randi() % 2 == 0
	var player_won := _player_choice_heads == flip_is_heads
	GameFlow.player_moves_first = player_won
	_result_label.text = (
		"Flip: %s — %s moves first. (Stub animation TBD)"
		% ["Heads" if flip_is_heads else "Tails", "You" if player_won else "Opponent"]
	)
	_hold_timer.start(RESULT_HOLD_SEC)


func _on_hold_timeout() -> void:
	GameFlow.go_to(GameFlow.SceneKey.SCENARIO)
