extends Control
## Coin flip (slice §4 / §2B; Sean 2026-11-13, supersedes the heads/tails
## pick). The coin is a Vanilla Goob with a blue face and a red face in the
## screen centre. Swipe up anywhere to toss it (starting on the coin = a
## stronger toss); a tap is a gentle toss. 50/50; the landed colour goes first
## (blue = player). A stronger toss only adds spins and arc within the same
## TOSS_SEC. Then: rest, a flash in the winner's colour + "goes first" banner,
## and the board fades in over the forest. Release → scenario ≤ 3 s.

const FRAME_PATH := "res://assets/goobs/vanilla/%s_pitch/frame_%02d.png"
## A half turn, blue face → red face: blue 0 (face), 1, 2 (edge), then red
## 6 (edge), 7, and red 0 is the next face (and the reverse for red → blue).
const HALF_TURN_OUT: Array[int] = [0, 1, 2]
const HALF_TURN_IN: Array[int] = [6, 7]
const COIN_SCALE := 2.0 ## 32 px Goob drawn at 2× game px
const COIN_PX := 32.0
const PROMPT_GAP := 48.0 ## coin centre → prompt top
const BANNER_SIZE := Vector2(258, 44)
const BANNER_GAP := 52.0 ## coin centre → banner top

const POP_SEC := 0.25
const AUTO_FLIP_SEC := 0.5 ## Options "Auto-flip coin": toss this long after the coin appears
const TOSS_SEC := 0.6
const REST_SEC := 0.5
const RESULT_SEC := 1.0 ## winner flash + banner
## Release → scenario on screen: toss + rest + result + forest fade (≤ 3 s, Sean 2026-11-11).
const TOTAL_SEC := TOSS_SEC + REST_SEC + RESULT_SEC + GameFlow.FADE_SEC * 2.0

const SWIPE_MIN_PX := 40.0 ## upward travel (720 base) that counts as a swipe
const SWIPE_FULL_PX := 500.0 ## travel for a full-strength swipe
const TAP_STRENGTH := 0.15
const COIN_BONUS := 0.35 ## swipe that starts on the coin
const MIN_HALF_TURNS := 2
const EXTRA_HALF_TURNS := 8.0 ## at strength 1
const MIN_ARC_PX := 24.0
const EXTRA_ARC_PX := 120.0
const LAND_HOP_PX := 3.0

const COLOR_PLAYER := Color("4d9be6") ## Resurrect 64 blue
const COLOR_OPPONENT := Color("e83b3b") ## Resurrect 64 red
const FLASH_PEAK := 0.8
const FLASH_HOLD := 0.35

var rng := RandomNumberGenerator.new()
## Set by toss(): true = blue face up = player goes first.
var player_first := true
var half_turns := 0
var arc_px := 0.0
var tossed := false

var _stage: PixelStage
var _coin: TextureRect
var _prompt: Label
var _banner: NinePatchRect
var _banner_label: Label
var _flash: ColorRect
var _frames: Dictionary = {} ## "blue" / "red" -> Array[Texture2D]
var _rest := Vector2.ZERO ## coin top-left at rest, game px
var _ready_for_toss := false
var _press_pos := Vector2.ZERO
var _press_on_coin := false
var _pressed := false


func _ready() -> void:
	rng.randomize()
	for colour: String in ["blue", "red"]:
		var frames: Array[Texture2D] = []
		for i in 8:
			frames.append(load(FRAME_PATH % [colour, i]) as Texture2D)
		_frames[colour] = frames
	add_child(GameFlow.make_vignette())
	# The winner flash tints the forest; the coin and banner stay on top.
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(COLOR_PLAYER, 0.0)
	add_child(_flash)
	_stage = PixelStage.new()
	add_child(_stage)
	_coin = _stage.add_image(_frames.blue[0])
	_coin.pivot_offset = Vector2(COIN_PX, COIN_PX) * 0.5
	_prompt = _stage.add_label("Swipe up to flip", PixelStage.WHITE, &"Mono2")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	_prompt.add_theme_constant_override(&"shadow_offset_x", 0)
	_prompt.add_theme_constant_override(&"shadow_offset_y", 2)
	_banner = NinePatchRect.new()
	_banner.texture = UiKit.texture(&"banner")
	var m: Array = UiKit.MARGINS[&"banner"]
	_banner.patch_margin_left = m[0]
	_banner.patch_margin_top = m[1]
	_banner.patch_margin_right = m[2]
	_banner.patch_margin_bottom = m[3]
	_banner.size = BANNER_SIZE
	_banner.pivot_offset = BANNER_SIZE * 0.5
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_stage.canvas.add_child(_banner)
	_banner_label = _stage.add_label("", PixelStage.WHITE, &"Mono2", _banner)
	_banner_label.size = BANNER_SIZE
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	_banner_label.add_theme_constant_override(&"shadow_offset_x", 0)
	_banner_label.add_theme_constant_override(&"shadow_offset_y", 2)
	_stage.relayout.connect(_layout)
	_pop_in()


func _layout() -> void:
	var centre := (_stage.game_size * 0.5).floor()
	_rest = centre - Vector2(COIN_PX, COIN_PX) * 0.5
	if not tossed:
		_coin.position = _rest
	_prompt.size = Vector2(_stage.game_size.x, 32)
	_prompt.position = Vector2(0, centre.y + PROMPT_GAP)
	_banner.position = Vector2(floorf((_stage.game_size.x - BANNER_SIZE.x) * 0.5), centre.y + BANNER_GAP)


func _pop_in() -> void:
	_coin.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(_coin, "scale", Vector2.ONE * COIN_SCALE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _ready_for_toss = true)
	if GameFlow.auto_flip_coin:
		tween.tween_interval(AUTO_FLIP_SEC)
		tween.tween_callback(func() -> void: toss(TAP_STRENGTH))


## Strength of a release: a tap is gentle; an upward swipe scales with its
## length, plus a bonus if it started on the coin.
static func strength_for(press: Vector2, release: Vector2, on_coin: bool) -> float:
	var up := press.y - release.y
	if up < SWIPE_MIN_PX:
		return TAP_STRENGTH
	var strength := clampf(up / SWIPE_FULL_PX, 0.25, 1.0)
	if on_coin:
		strength += COIN_BONUS
	return minf(strength, 1.0)


func _input(event: InputEvent) -> void:
	if tossed or GameFlow.is_fading():
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_pressed = true
			_press_pos = event.position
			_press_on_coin = _coin.get_global_rect().has_point(event.position)
		elif _pressed:
			_pressed = false
			if _ready_for_toss:
				toss(strength_for(_press_pos, event.position, _press_on_coin))
	elif not event is InputEventMouse and event.is_action_pressed("ui_accept") and _ready_for_toss:
		toss(TAP_STRENGTH)


## Decides the winner (50/50) and plays the toss → rest → result.
func toss(strength: float) -> void:
	if tossed:
		return
	tossed = true
	player_first = rng.randi() % 2 == 0
	GameFlow.player_moves_first = player_first
	strength = clampf(strength, 0.0, 1.0)
	half_turns = MIN_HALF_TURNS + roundi(strength * EXTRA_HALF_TURNS)
	# Starts blue face up: an even number of half turns lands blue.
	if (half_turns % 2 == 0) != player_first:
		half_turns += 1
	arc_px = MIN_ARC_PX + strength * EXTRA_ARC_PX
	_coin.scale = Vector2.ONE * COIN_SCALE
	_coin.position = _rest
	GameFlow.sfx.play(&"coin_swipe")
	GameFlow.sfx.play(&"coin_whirr", false, 0.85 + strength * 0.4)
	create_tween().tween_property(_prompt, "modulate:a", 0.0, 0.15)
	var tween := create_tween()
	tween.tween_method(_toss_step, 0.0, 1.0, TOSS_SEC)
	tween.tween_callback(_land)
	tween.tween_property(_coin, "position:y", _rest.y - LAND_HOP_PX, 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(_coin, "position:y", _rest.y, 0.06).set_ease(Tween.EASE_IN)
	tween.tween_interval(REST_SEC - 0.12)
	tween.tween_callback(_show_result)
	tween.tween_interval(RESULT_SEC)
	tween.tween_callback(GameFlow.go_to.bind(GameFlow.SceneKey.SCENARIO, GameFlow.Transition.FOREST))


## t in 0..1 over the toss: a parabola up and down, spinning half turns.
func _toss_step(t: float) -> void:
	_coin.position = Vector2(_rest.x, roundf(_rest.y - arc_px * 4.0 * t * (1.0 - t)))
	_coin.texture = frame_at(t, half_turns)


## The coin face/edge frame at toss time t (0..1) for `turns` half turns.
func frame_at(t: float, turns: int) -> Texture2D:
	if t >= 1.0:
		return _frames["blue" if turns % 2 == 0 else "red"][0]
	var phase := t * turns
	var half := floori(phase)
	var from := "blue" if half % 2 == 0 else "red"
	var to := "red" if from == "blue" else "blue"
	var step := floori((phase - half) * 5.0) # 0..4 across [out 0,1,2 | in 6,7]
	if step < HALF_TURN_OUT.size():
		return _frames[from][HALF_TURN_OUT[step]]
	return _frames[to][HALF_TURN_IN[step - HALF_TURN_OUT.size()]]


func _land() -> void:
	_coin.texture = frame_at(1.0, half_turns)
	GameFlow.sfx.play(&"coin_land")


func _show_result() -> void:
	var colour := COLOR_PLAYER if player_first else COLOR_OPPONENT
	_flash.color = Color(colour, 0.0)
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", FLASH_PEAK, 0.08)
	flash.tween_property(_flash, "color:a", FLASH_HOLD, 0.4)
	_banner_label.text = "You go first" if player_first else "Opponent goes first"
	_banner.self_modulate = Color.WHITE
	_banner.visible = true
	_banner.scale = Vector2(1.0, 0.0)
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameFlow.sfx.play(&"first_sting")
