class_name UiTheme
extends RefCounted
## Project-wide UI theme (Art pass A, GDD §Art direction): Monogram for all
## text, sized on the board's game-pixel unit (slice §2B: UI pixel = one board
## game pixel), so each font pixel is a whole number of physical pixels.
##
## Text uses theme type variations (of Label) instead of raw font sizes:
##   (none)       1× — body text, buttons, HUD (the default font size)
##   Mono2        2× — headings, names, prompts
##   Mono3        3× — title, end banner, big numbers
##   Mono1Italic  1× italic — flavour text
## GameFlow installs it on the root window and re-applies it on resize.

const FONT: FontFile = preload("res://resources/fonts/monogram-extended.ttf")
const FONT_ITALIC: FontFile = preload("res://resources/fonts/monogram-extended-italic.ttf")
## Monogram's crisp size: one font pixel per screen pixel at 16 px.
const NATIVE_SIZE := 16
## Same width the board's pixel layer fits (BoardView2D.CANVAS_WIDTH).
const CANVAS_WIDTH := 270.0
const VARIATIONS: Dictionary = {&"Mono2": 2, &"Mono3": 3, &"Mono1Italic": 1}

static var _theme: Theme


static func install(root: Window) -> void:
	if _theme == null:
		_theme = _build()
	root.theme = _theme
	apply(root)


## Font size (in 720-base units) for `multiple`× Monogram on this window.
static func font_size(root: Window, multiple: int) -> int:
	var logical := root.get_visible_rect().size.x
	var physical := float(root.size.x)
	if logical <= 0.0 or physical <= 0.0:
		return NATIVE_SIZE * multiple
	var pixel_scale := maxi(1, floori(physical / CANVAS_WIDTH))
	var ui_scale := physical / logical
	return maxi(1, roundi(NATIVE_SIZE * multiple * pixel_scale / ui_scale))


static func apply(root: Window) -> void:
	if _theme == null:
		return
	_theme.default_font_size = font_size(root, 1)
	# Controls outside a Control/Window chain (e.g. hand labels under a Node2D)
	# don't inherit the root theme; the fallback catches them.
	ThemeDB.fallback_font = FONT
	ThemeDB.fallback_font_size = _theme.default_font_size
	for variation: StringName in VARIATIONS:
		_theme.set_font_size(&"font_size", variation, font_size(root, VARIATIONS[variation]))


static func _build() -> Theme:
	# Import settings are not tracked in git, so the pixel-font flags are set here.
	for font: FontFile in [FONT, FONT_ITALIC]:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
	var theme := Theme.new()
	theme.default_font = FONT
	for variation: StringName in VARIATIONS:
		theme.set_type_variation(variation, &"Label")
	theme.set_font(&"font", &"Mono1Italic", FONT_ITALIC)
	return theme
