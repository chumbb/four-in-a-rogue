extends Node
## Scene flow: title → Strange Man → coin flip → scenario (slice §4 / §2B).
##
## Scene changes fade (~0.3 s, not affected by animation speed):
##   BLACK   through black (title, Strange Man, back to title)
##   FOREST  through the Forest background: the current screen fades out
##           leaving the forest, the next one fades in over it (coin flip →
##           board, and the draw replay's board → coin flip)
##   CUT     no fade (Strange Man fades his own forest in before the coin flip)

enum SceneKey {
	BOOT,
	TITLE,
	STRANGE_MAN,
	COIN_FLIP,
	SCENARIO,
}

enum Transition { BLACK, FOREST, CUT }

const SCENE_PATHS: Dictionary = {
	SceneKey.BOOT: "res://scenes/app/boot.tscn",
	SceneKey.TITLE: "res://scenes/app/title.tscn",
	SceneKey.STRANGE_MAN: "res://scenes/app/strange_man.tscn",
	SceneKey.COIN_FLIP: "res://scenes/ui/coin_flip.tscn",
	SceneKey.SCENARIO: "res://scenes/scenario/scenario.tscn",
}

## Each half of a fade (out, then in).
const FADE_SEC := 0.3
const FOREST := preload("res://assets/backgrounds/forest.png")
const VIGNETTE := preload("res://shaders/vignette.gdshader")

## Set by the coin flip; true = player moves first.
var player_moves_first: bool = true
## The two rolled decks of this game ({"player": Array, "opponent": Array,
## "player_name" / "opponent_name": their decklist names}), kept across draw replays; empty = roll new ones. Cleared on a new game.
var rolled_decks: Dictionary = {}
## Debug builds: forces the deck roll ({"player" / "opponent": a decklist name
## or DeckBuilder.RANDOM}; see DeckBuilder.roll_pair).
var debug_forced_categories: Dictionary = {}
## Tests force an auto-flip; players use Options "Auto-flip coin" (Settings).
var auto_flip_coin := false
## Debug auto-play (M6e, debug builds only): the AI plays your turns; kept over
## draw replays and coin flips, off at the win / lose end screen.
var autoplay := false
## Tests set 0 to change scenes at once.
var fade_sec := FADE_SEC
## Flow screens' sounds (press start, pages, coin): owned here so a sound keeps
## playing while its screen fades out (a frozen screen pauses its players).
var sfx: Sfx

var _fading := false
var _cover_layer: CanvasLayer
var _black: ColorRect
var _forest: Control


func _ready() -> void:
	var root := get_tree().root
	UiTheme.install(root)
	root.size_changed.connect(UiTheme.apply.bind(root))
	_build_covers()
	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)


## Mobile (slice §2B Sound): all audio pauses while the app is in the
## background. The engine's own settings come back on resume.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		Settings.apply_audio()


## F3 (debug builds only) toggles simulated phone safe-area insets (§2A).
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		SafeArea.simulate_insets = not SafeArea.simulate_insets
		get_tree().call_group(SafeArea.GROUP, "apply")
		get_viewport().set_input_as_handled()


func is_fading() -> bool:
	return _fading


## `sec` overrides the length of each fade half (e.g. the coin flip's slower
## fade to the board); tests' fade_sec = 0 still wins.
func go_to(key: SceneKey, transition := Transition.BLACK, sec := -1.0) -> void:
	var path: String = SCENE_PATHS.get(key, "")
	if path.is_empty():
		push_error("GameFlow: unknown scene key %s" % str(key))
		return
	if _fading:
		return
	Telemetry.track(&"screen", {"name": str(SceneKey.find_key(key)).to_lower()})
	if fade_sec <= 0.0:
		get_tree().change_scene_to_file(path)
		return
	if transition == Transition.CUT:
		_cut_under_forest(path)
		return
	var half := fade_sec if sec < 0.0 else sec
	_fading = true
	var cover: Control = _black if transition == Transition.BLACK else _forest
	cover.modulate.a = 0.0
	cover.visible = true
	# The old screen freezes under the cover: no input, timers or tweens.
	var old := get_tree().current_scene
	if old:
		old.process_mode = Node.PROCESS_MODE_DISABLED
	var out := create_tween()
	out.tween_property(cover, "modulate:a", 1.0, half)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	var back := create_tween()
	back.tween_property(cover, "modulate:a", 0.0, half)
	await back.finished
	cover.visible = false
	_fading = false


## A cut between two forest screens (Strange Man → coin flip). Godot draws a
## frame with no scene between the old and the new one (the clear colour
## flickered through; Sean 2026-11-21), so the forest cover, drawn exactly like
## both screens' background, holds the picture until the new scene has drawn.
func _cut_under_forest(path: String) -> void:
	_fading = true
	_forest.modulate.a = 1.0
	_forest.visible = true
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	_forest.visible = false
	_fading = false


func begin_play_flow_from_title() -> void:
	rolled_decks = {}
	go_to(SceneKey.STRANGE_MAN)


## Draw replay skips Title and Strange Man: the board fades out leaving the
## forest, and the coin flip happens there.
func replay_after_draw() -> void:
	go_to(SceneKey.COIN_FLIP, Transition.FOREST)


func return_to_title() -> void:
	rolled_decks = {}
	autoplay = false # leaving the game ends debug auto-play
	go_to(SceneKey.TITLE)


## Full-screen covers above every scene. The forest cover is drawn exactly like
## the scenes' Forest background (+ vignette), so fading it looks like the
## screen's contents fading over a fixed forest.
func _build_covers() -> void:
	_cover_layer = CanvasLayer.new()
	_cover_layer.layer = 100
	add_child(_cover_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_forest = Control.new()
	var bg := TextureRect.new()
	bg.texture = FOREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_forest.add_child(bg)
	_forest.add_child(make_vignette())
	for cover: Control in [_black, _forest]:
		_cover_layer.add_child(cover)
		cover.visible = false
	for node: Control in [_black, _forest, bg]:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_STOP if node != bg else Control.MOUSE_FILTER_IGNORE


## The Art B vignette: a full-screen rect above the canvas, below the UI.
static func make_vignette() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Vignette"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	rect.material = material
	return rect
