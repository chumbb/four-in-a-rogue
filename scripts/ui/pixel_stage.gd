class_name PixelStage
extends Control
## Full-screen game-pixel canvas for the flow screens (title, Strange Man, coin
## flip). Children of `canvas` are laid out in game px, like the approved Art B
## mocks (art/ui/mocks/, 270 game px wide): the canvas is shown at the same
## whole-number pixel scale as the board (BoardView2D.CANVAS_WIDTH; 4× at
## 1080 wide), centred, nearest filtering, so every game pixel is a crisp
## block. Text inside uses Monogram at its native 16 px per multiple.
##
## `safe` is the SafeArea inset rectangle in game px; screens re-place their
## pieces in a `relayout` handler (fired on resize and on the F3 inset toggle).

signal relayout

const CANVAS_WIDTH := 270.0
## Kit colours (Resurrect 64; art/ui/make_ui_kit.py).
const INK0 := Color("2e222f")
const CREAM := Color("fdcbb0")
const WHITE := Color("ffffff")
## Pixel-bold Monogram for buttons (art/fonts/make_monogram_bold.py).
const BUTTON_FONT: Font = preload("res://resources/fonts/monogram-bold.fnt")

## Logical (720-base) units per game px.
var k := 1.0
## Canvas size in game px (270 × screen height).
var game_size := Vector2(CANVAS_WIDTH, 480.0)
## Inside of the safe area, in game px.
var safe := Rect2(0, 0, CANVAS_WIDTH, 480.0)
var canvas: Control

static var _theme: Theme


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.theme = _canvas_theme()
	add_child(canvas)


func _ready() -> void:
	add_to_group(SafeArea.GROUP)
	get_viewport().size_changed.connect(apply)
	apply.call_deferred()


## Re-measures (also called by GameFlow's F3 toggle via the SafeArea group).
func apply() -> void:
	var view := get_viewport_rect().size
	var physical := float(get_window().size.x)
	if view.x <= 0.0 or physical <= 0.0:
		return
	var ui_scale := physical / view.x
	var pixel_scale := maxi(1, floori(physical / CANVAS_WIDTH))
	k = pixel_scale / ui_scale
	game_size = Vector2(CANVAS_WIDTH, floorf(view.y / k))
	canvas.scale = Vector2(k, k)
	canvas.size = game_size
	# Centre, snapped to whole physical pixels.
	var offset := Vector2((view.x - CANVAS_WIDTH * k) * 0.5, (view.y - game_size.y * k) * 0.5)
	canvas.position = (offset * ui_scale).round() / ui_scale
	var insets := SafeArea.insets_for(get_viewport())
	var top := ceilf(insets.top / k)
	var bottom := ceilf(insets.bottom / k)
	var left := ceilf(insets.left / k)
	var right := ceilf(insets.right / k)
	safe = Rect2(left, top, game_size.x - left - right, game_size.y - top - bottom)
	relayout.emit()


## A Sprite-like TextureRect at game px `pos` (top-left).
func add_image(texture: Texture2D, pos := Vector2.ZERO, parent: Node = null) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = pos
	rect.size = texture.get_size()
	(parent if parent else canvas).add_child(rect)
	return rect


## A Monogram label (`variation`: &"" 1×, &"Mono2", &"Mono3") in game px.
func add_label(text: String, colour := CREAM, variation := &"", parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else canvas).add_child(label)
	return label


## A kit button (honey 9-slice, dark text), ≥ 36 game px tall = 96 px at 720.
func add_button(text: String, width: float, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	(parent if parent else canvas).add_child(button)
	# Size after adding: before the canvas theme applies, the default font's
	# larger minimum size would stretch it.
	button.size = Vector2(width, 36)
	return button


## True if a touch at viewport position `pos` lands on a visible button.
static func touches_button(root: Node, pos: Vector2) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pos):
			return true
	return false


static func _canvas_theme() -> Theme:
	if _theme:
		return _theme
	var theme := Theme.new()
	theme.default_font = UiTheme.FONT
	theme.default_font_size = UiTheme.NATIVE_SIZE
	for variation: StringName in UiTheme.VARIATIONS:
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size(&"font_size", variation, UiTheme.NATIVE_SIZE * UiTheme.VARIATIONS[variation])
	theme.set_font(&"font", &"Mono1Italic", UiTheme.FONT_ITALIC)
	var normal := UiKit.stylebox(&"button_normal")
	var pressed := UiKit.stylebox(&"button_pressed")
	theme.set_stylebox(&"normal", &"Button", normal)
	theme.set_stylebox(&"hover", &"Button", normal)
	theme.set_stylebox(&"pressed", &"Button", pressed)
	theme.set_stylebox(&"hover_pressed", &"Button", pressed)
	theme.set_stylebox(&"disabled", &"Button", UiKit.stylebox(&"button_disabled"))
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	# Button text in pixel-bold Monogram (Sean, M6c playtest: thicker, crisper).
	theme.set_font(&"font", &"Button", BUTTON_FONT)
	theme.set_font_size(&"font_size", &"Button", UiTheme.NATIVE_SIZE)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		theme.set_color(state, &"Button", INK0)
	_theme = theme
	return theme
