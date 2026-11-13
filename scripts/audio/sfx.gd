class_name Sfx
extends Node
## Sound effects player (slice §2B Sound). Add one to a scene and call
## play(&"name"). Sounds come from CC0 / credited packs (assets/audio/CREDITS.md).
##
## Repeats get ±5 % random pitch; opponent sounds are ~10 % lower; each sound
## plays at most once per frame. Buses and volume options come in M6.

const STREAMS := {
	&"land": preload("res://assets/audio/sfx/land.ogg"),
	&"rest": preload("res://assets/audio/sfx/rest_tap.ogg"),
	&"fall": preload("res://assets/audio/sfx/fall.ogg"),
	&"roll": preload("res://assets/audio/sfx/roll_tick.ogg"),
	&"bounce": preload("res://assets/audio/sfx/bounce.ogg"),
	&"draw_pop": preload("res://assets/audio/sfx/draw_pop.ogg"),
	&"fly": preload("res://assets/audio/sfx/fly_swish.ogg"),
	&"select": preload("res://assets/audio/sfx/select.ogg"),
	&"drag": preload("res://assets/audio/sfx/drag_pickup.ogg"),
	&"cancel": preload("res://assets/audio/sfx/fly_swish.ogg"),
	&"column": preload("res://assets/audio/sfx/column_blip.ogg"),
	&"column_tick": preload("res://assets/audio/sfx/column_tick.ogg"),
	&"error": preload("res://assets/audio/sfx/error.ogg"),
	&"hand_full": preload("res://assets/audio/sfx/hand_full.ogg"),
	&"inspect_open": preload("res://assets/audio/sfx/inspect_open.ogg"),
	&"inspect_close": preload("res://assets/audio/sfx/inspect_close.ogg"),
	&"times_up": preload("res://assets/audio/sfx/times_up.ogg"),
}
## Base pitch per sound where the raw sample needs it (cancel = lower swish).
const BASE_PITCH := {&"cancel": 0.8}
const PITCH_JITTER := 0.05
const OPPONENT_PITCH := 0.9
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _played_frame: Dictionary = {} ## name -> process frame it last played
var _rng := RandomNumberGenerator.new()
## Names played so far, newest last (tests read this; trimmed to 32).
var history: Array[StringName] = []


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


## Plays `sound`; `opponent` lowers the pitch ~10 %.
func play(sound: StringName, opponent := false) -> void:
	if not STREAMS.has(sound):
		push_error("Sfx: unknown sound '%s'" % sound)
		return
	var frame := Engine.get_process_frames()
	if _played_frame.get(sound, -1) == frame:
		return
	_played_frame[sound] = frame
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = STREAMS[sound]
	var pitch: float = BASE_PITCH.get(sound, 1.0) * _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	if opponent:
		pitch *= OPPONENT_PITCH
	player.pitch_scale = pitch
	player.play()
	history.append(sound)
	if history.size() > 32:
		history.pop_front()


func is_playing(sound: StringName) -> bool:
	for player in _pool:
		if player.playing and player.stream == STREAMS[sound]:
			return true
	return false
