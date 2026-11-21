extends Control
## Strange Man intro (slice §2B, Art pass C mock): he stands centred on an
## oval pool of light, the forest barely visible behind him; a dialogue box at
## the bottom types the locked text one sentence per page. Tap finishes the
## typing, the next tap turns the page (▼ blinks when a page is done). On
## "This is a land of Goobs." his blue and red Goobs pop in beside him. After
## the last page (or Skip) the forest fades into focus and the coin flip starts.

const OPENING_DIALOGUE := (
	"Hey, you must not be from around here. This is a land of Goobs. "
	+ "If you want to progress, you'll need to get 4 goobs in a row before your opponent does. "
	+ "You'll collect more Goobs as you progress. Once you get all the Goobs, well, I think you know..."
)
## One page per sentence, words unchanged (joined with spaces = OPENING_DIALOGUE).
const PAGES: Array[String] = [
	"Hey, you must not be from around here.",
	"This is a land of Goobs.",
	"If you want to progress, you'll need to get 4 goobs in a row before your opponent does.",
	"You'll collect more Goobs as you progress.",
	"Once you get all the Goobs, well, I think you know...",
]
const GOOBS_PAGE := 1

const FIGURE := preload("res://assets/strange_man/full_body.png")
const POOL := preload("res://assets/strange_man/light_pool.png")
const GOOB_BLUE := preload("res://assets/strange_man/intro_goob_blue.png")
const GOOB_RED := preload("res://assets/strange_man/intro_goob_red.png")
const ARROW := preload("res://assets/ui/dialogue_arrow.png")

## Layout in game px on the 270×480 mock (art/strange_man/make_strange_man.py).
const DESIGN_HEIGHT := 480.0
const POOL_CENTRE := Vector2(135, 300)
const FIGURE_FEET := 151 ## bottom of his opaque pixels in full_body.png
const GOOB_SPOTS := {"blue": Vector2(48, 264), "red": Vector2(174, 264)}
const BOX := Rect2(6, 340, 258, 96)
const TEXT_INSET := Vector2(14, 16)
const SKIP_WIDTH := 64.0
const EDGE := 6.0
const SKIP_TOP := 10.0

## Black over the forest (mock: 225 / 255).
const DIM_ALPHA := 0.88
const CHARS_PER_SEC := 40.0
const ARROW_BLINK_SEC := 0.4
const POP_SEC := 0.3
const POP_STAGGER_SEC := 0.12
const POP_DROP_PX := 10.0
## Outro (Sean 2026-11-20: slow enough to register): he fades out, the forest
## comes into focus, a beat on the empty forest, then the coin flip.
const OUTRO_SEC := 0.5
const FOREST_IN_SEC := 1.0
const FOREST_HOLD_SEC := 0.4

@onready var _dim: ColorRect = %Dim

var _stage: PixelStage
var _scene: Control ## pool, figure and Goobs (moves with the dialogue box)
var _box: NinePatchRect
var _text: Label
var _arrow: TextureRect
var _skip: Button
var _goobs: Dictionary = {} ## "blue" / "red" -> TextureRect
var page := -1
var _shown := 0.0 ## characters typed so far on this page
var _blink := 0.0
var _done := false


func _ready() -> void:
	_dim.color.a = DIM_ALPHA
	add_child(GameFlow.make_vignette())
	_stage = PixelStage.new()
	add_child(_stage)
	_build()
	_stage.relayout.connect(_layout)
	_show_page(0)


func _build() -> void:
	_scene = Control.new()
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.canvas.add_child(_scene)
	_stage.add_image(POOL, POOL_CENTRE - Vector2(70, 18), _scene)
	_stage.add_image(FIGURE, Vector2(POOL_CENTRE.x - FIGURE.get_width() / 2.0, POOL_CENTRE.y + 4 - FIGURE_FEET), _scene)
	for colour: String in GOOB_SPOTS:
		var goob := _stage.add_image(GOOB_BLUE if colour == "blue" else GOOB_RED, GOOB_SPOTS[colour], _scene)
		goob.pivot_offset = Vector2(goob.size.x * 0.5, goob.size.y)
		goob.visible = false
		_goobs[colour] = goob
	_box = NinePatchRect.new()
	_box.texture = UiKit.texture(&"dialogue")
	var m: Array = UiKit.MARGINS[&"dialogue"]
	_box.patch_margin_left = m[0]
	_box.patch_margin_top = m[1]
	_box.patch_margin_right = m[2]
	_box.patch_margin_bottom = m[3]
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size = BOX.size
	_stage.canvas.add_child(_box)
	_text = _stage.add_label("", PixelStage.WHITE, &"", _box)
	_text.position = TEXT_INSET
	_text.size = BOX.size - TEXT_INSET * 2.0
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrap the whole sentence first, then reveal it: a word being typed starts
	# on the line it will end on (the default re-wraps per character, so long
	# words jumped down mid-word; Sean 2026-11-20).
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	_text.add_theme_constant_override(&"shadow_offset_x", 0)
	_text.add_theme_constant_override(&"shadow_offset_y", 1)
	_arrow = _stage.add_image(ARROW, Vector2(BOX.size.x - 22, BOX.size.y - 18), _box)
	_skip = _stage.add_button("Skip", SKIP_WIDTH)
	_skip.pressed.connect(_on_skip_pressed)


## The mock's 480-tall layout, centred on taller screens; the dialogue box
## moves up (and the scene with it) only if the safe area needs it.
func _layout() -> void:
	var safe := _stage.safe
	var top := floorf((_stage.game_size.y - DESIGN_HEIGHT) * 0.5)
	var box_bottom := minf(top + BOX.end.y, safe.end.y - 8.0)
	var dy := box_bottom - BOX.end.y
	_scene.position = Vector2(0, dy)
	_box.position = Vector2(BOX.position.x, BOX.position.y + dy)
	_skip.position = Vector2(safe.end.x - EDGE - SKIP_WIDTH, safe.position.y + SKIP_TOP)


func _process(delta: float) -> void:
	if _done:
		return
	if is_typing():
		_shown = minf(_shown + CHARS_PER_SEC * delta, PAGES[page].length())
		_text.visible_characters = int(_shown)
		_arrow.visible = false
		_blink = 0.0
	else:
		_blink += delta
		_arrow.visible = fmod(_blink, ARROW_BLINK_SEC * 2.0) < ARROW_BLINK_SEC


func is_typing() -> bool:
	return page >= 0 and _shown < PAGES[page].length()


## Tap anywhere (except Skip): finish typing, else turn the page.
func _input(event: InputEvent) -> void:
	if _done or GameFlow.is_fading():
		return
	var tap := false
	if event is InputEventScreenTouch:
		tap = event.pressed and not PixelStage.touches_button(self, event.position)
	elif not event is InputEventMouse:
		tap = event.is_action_pressed("ui_accept")
	if tap:
		get_viewport().set_input_as_handled()
		advance()


func advance() -> void:
	if _done:
		return
	if is_typing():
		_shown = PAGES[page].length()
		_text.visible_characters = -1
		return
	GameFlow.sfx.play(&"page")
	if page + 1 < PAGES.size():
		_show_page(page + 1)
	else:
		finish()


func _show_page(index: int) -> void:
	page = index
	_shown = 0.0
	_text.text = PAGES[index]
	_text.visible_characters = 0
	if index >= GOOBS_PAGE and not _goobs.blue.visible:
		_pop_goobs()


func _pop_goobs() -> void:
	var delay := 0.0
	for colour: String in ["blue", "red"]:
		var goob: TextureRect = _goobs[colour]
		var rest: Vector2 = GOOB_SPOTS[colour]
		goob.visible = true
		goob.scale = Vector2(0.3, 0.3)
		goob.position = rest - Vector2(0, POP_DROP_PX)
		var tween := create_tween().set_parallel()
		tween.tween_property(goob, "scale", Vector2.ONE, POP_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(goob, "position", rest, POP_SEC).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(GameFlow.sfx.play.bind(&"goob_pop")).set_delay(delay)
		delay += POP_STAGGER_SEC


func _on_skip_pressed() -> void:
	GameFlow.sfx.play(&"ui_tap")
	finish()


## He fades away, the forest comes into focus, then the coin flip (no black fade).
func finish() -> void:
	if _done:
		return
	_done = true
	_skip.disabled = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_stage, "modulate:a", 0.0, OUTRO_SEC)
	tween.tween_property(_dim, "color:a", 0.0, FOREST_IN_SEC).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_interval(FOREST_HOLD_SEC)
	tween.chain().tween_callback(GameFlow.go_to.bind(GameFlow.SceneKey.COIN_FLIP, GameFlow.Transition.CUT))
