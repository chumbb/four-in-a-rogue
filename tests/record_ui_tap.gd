extends SceneTree
## Dev tool: records what the game actually plays for a UI tap (Master bus) to a WAV.
## godot --headless -s res://tests/record_ui_tap.gd -- <out.wav> <sound>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	rec.set_recording_active(true)
	await create_timer(0.1).timeout
	root.get_node("GameFlow").sfx.play(StringName(args[1]))
	await create_timer(0.5).timeout
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	print("mix rate ", AudioServer.get_mix_rate(), " len ", wav.data.size() if wav else -1)
	if wav:
		wav.save_to_wav(args[0])
	quit()
