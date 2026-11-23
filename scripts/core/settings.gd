extends Node
## Player options (slice §2B Options; autoload `Settings`): animation speed,
## haptics, screen shake, auto-flip coin, and Master / Music / SFX volume with a
## mute each. Saved to a settings file (not a game save) and applied at once;
## `changed` fires after every change.

signal changed

## Skip was removed (Sean, M6c playtest 2026-11-22); a saved Skip (2) loads as Normal.
enum Speed { NORMAL, FAST }

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
## Sean, 2026-11-13 sound grill.
const DEFAULT_VOLUME := {&"Master": 0.8, &"Music": 0.7, &"SFX": 0.8}
## Fast plays animations at double speed (Normal / Fast, slice A10).
const FAST_SCALE := 2.0
const HAPTIC_MS := 35

## Default Normal.
var speed := Speed.NORMAL
var haptics := true
var screen_shake := true
var auto_flip := false
var volume: Dictionary = DEFAULT_VOLUME.duplicate()
var muted: Dictionary = {&"Master": false, &"Music": false, &"SFX": false}
## Tests point this at a scratch file so they never touch the player's settings.
var path := PATH


func _ready() -> void:
	load_file()


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var saved := int(cfg.get_value("play", "speed", Speed.NORMAL))
		speed = Speed.FAST if saved == Speed.FAST else Speed.NORMAL
		haptics = bool(cfg.get_value("play", "haptics", true))
		screen_shake = bool(cfg.get_value("play", "screen_shake", true))
		auto_flip = bool(cfg.get_value("play", "auto_flip", false))
		for bus in BUSES:
			volume[bus] = clampf(float(cfg.get_value("audio", "%s_volume" % bus, DEFAULT_VOLUME[bus])), 0.0, 1.0)
			muted[bus] = bool(cfg.get_value("audio", "%s_muted" % bus, false))
	apply_audio()


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("play", "speed", speed)
	cfg.set_value("play", "haptics", haptics)
	cfg.set_value("play", "screen_shake", screen_shake)
	cfg.set_value("play", "auto_flip", auto_flip)
	for bus in BUSES:
		cfg.set_value("audio", "%s_volume" % bus, volume[bus])
		cfg.set_value("audio", "%s_muted" % bus, muted[bus])
	cfg.save(path)


## Back to the defaults (tests; nothing in the UI resets yet).
func reset() -> void:
	speed = Speed.NORMAL
	haptics = true
	screen_shake = true
	auto_flip = false
	volume = DEFAULT_VOLUME.duplicate()
	muted = {&"Master": false, &"Music": false, &"SFX": false}
	apply_audio()
	changed.emit()


func set_speed(value: Speed) -> void:
	speed = value
	_commit()


func set_haptics(on: bool) -> void:
	haptics = on
	_commit()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_commit()


func set_auto_flip(on: bool) -> void:
	auto_flip = on
	_commit()


func set_volume(bus: StringName, value: float) -> void:
	volume[bus] = clampf(value, 0.0, 1.0)
	_commit()


func set_muted(bus: StringName, on: bool) -> void:
	muted[bus] = on
	_commit()


## Play-animation time for `sec` at the current speed: Normal as is, Fast
## halved.
func anim_sec(sec: float) -> float:
	return sec / anim_scale()


## Tween speed scale for play animations.
func anim_scale() -> float:
	return FAST_SCALE if speed == Speed.FAST else 1.0


## One short pulse (your Goob lands, invalid drop); Haptics Off = none. Phones
## only: Input.vibrate_handheld() does nothing on desktop.
func vibrate() -> void:
	if haptics:
		Input.vibrate_handheld(HAPTIC_MS)


func apply_audio() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index == -1:
			continue
		var value: float = volume[bus]
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(index, muted[bus] or value <= 0.0)


func _commit() -> void:
	apply_audio()
	save_file()
	changed.emit()
