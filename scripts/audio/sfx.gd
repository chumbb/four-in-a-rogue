class_name Sfx
extends Node
## Sound effects player (slice §2B Sound). Add one to a scene and call
## play(&"name"). Sounds come from CC0 / credited packs (assets/audio/CREDITS.md).
##
## Repeats get ±5 % random pitch; opponent sounds are ~10 % lower; each sound
## plays at most once per frame. Everything plays on the SFX bus (volume and
## mute from Settings, M6b).

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
	&"column_tick": preload("res://assets/audio/sfx/column_tick.ogg"),
	&"error": preload("res://assets/audio/sfx/error.ogg"),
	&"hand_full": preload("res://assets/audio/sfx/hand_full.ogg"),
	&"inspect_open": preload("res://assets/audio/sfx/inspect_open.ogg"),
	&"inspect_close": preload("res://assets/audio/sfx/inspect_close.ogg"),
	&"times_up": preload("res://assets/audio/sfx/times_up.ogg"),
	# M5 effects (tactile) and scoring (chiptune): art/audio/make_effect_sounds.py
	&"flip": preload("res://assets/audio/sfx/effect_flip.ogg"),
	&"crunch": preload("res://assets/audio/sfx/effect_crunch.ogg"),
	&"popular": preload("res://assets/audio/sfx/effect_popular.ogg"),
	&"fizzle": preload("res://assets/audio/sfx/effect_fizzle.ogg"),
	&"score_0": preload("res://assets/audio/sfx/score_0.ogg"),
	&"score_1": preload("res://assets/audio/sfx/score_1.ogg"),
	&"score_2": preload("res://assets/audio/sfx/score_2.ogg"),
	&"score_3": preload("res://assets/audio/sfx/score_3.ogg"),
	&"score_4": preload("res://assets/audio/sfx/score_4.ogg"),
	&"score_5": preload("res://assets/audio/sfx/score_5.ogg"),
	&"score_6": preload("res://assets/audio/sfx/score_6.ogg"),
	&"score_7": preload("res://assets/audio/sfx/score_7.ogg"),
	&"score_8": preload("res://assets/audio/sfx/score_8.ogg"),
	&"score_collapse": preload("res://assets/audio/sfx/score_collapse.ogg"),
	&"score_recognise": preload("res://assets/audio/sfx/score_recognise.ogg"),
	# M6a flow (art/audio/make_flow_sounds.py): chiptune UI, tactile coin.
	&"press_start": preload("res://assets/audio/sfx/press_start.ogg"),
	&"ui_tap": preload("res://assets/audio/sfx/ui_tap.ogg"),
	&"page": preload("res://assets/audio/sfx/page_click.ogg"),
	&"goob_pop": preload("res://assets/audio/sfx/draw_pop.ogg"),
	&"coin_swipe": preload("res://assets/audio/sfx/fly_swish.ogg"),
	&"coin_whirr": preload("res://assets/audio/sfx/coin_whirr.ogg"),
	&"coin_land": preload("res://assets/audio/sfx/coin_clink.ogg"),
	&"first_sting": preload("res://assets/audio/sfx/first_sting.ogg"),
	# M6b menus and turn banners (art/audio/make_menu_sounds.py): chiptune.
	&"pause_open": preload("res://assets/audio/sfx/pause_open.ogg"),
	&"pause_close": preload("res://assets/audio/sfx/pause_close.ogg"),
	&"slider_tick": preload("res://assets/audio/sfx/slider_tick.ogg"),
	&"turn_player": preload("res://assets/audio/sfx/turn_player.ogg"),
	&"turn_opponent": preload("res://assets/audio/sfx/turn_opponent.ogg"),
}
## Scoring ladder notes, lowest first; the ladder must stay in tune, so these
## get no random pitch.
const SCORE_LADDER: Array[StringName] = [&"score_0", &"score_1", &"score_2", &"score_3", &"score_4", &"score_5", &"score_6", &"score_7", &"score_8"]
## Base pitch per sound where the raw sample needs it (cancel = lower swish).
const BASE_PITCH := {&"cancel": 0.8, &"goob_pop": 0.8}
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
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)


## Plays `sound`; `opponent` lowers the pitch ~10 %; `pitch` scales it further
## (the coin whirr rises with toss strength).
func play(sound: StringName, opponent := false, pitch_mult := 1.0) -> void:
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
	var pitch: float = BASE_PITCH.get(sound, 1.0) * pitch_mult
	if not SCORE_LADDER.has(sound) and sound != &"score_collapse" and sound != &"score_recognise":
		pitch *= _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
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
