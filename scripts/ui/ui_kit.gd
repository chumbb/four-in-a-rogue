class_name UiKit
extends RefCounted
## Pixel UI kit pieces (Art pass B; art in assets/ui/, made by
## art/ui/make_ui_kit.py). 9-slice margins are in game px and mirror `MARGINS`
## in that script; keep both in sync.
##
## `stylebox(name, texel)` builds a StyleBoxTexture whose texture is the piece
## scaled up by a whole number `texel` (nearest), so each game pixel stays a
## crisp block; the caller picks `texel` for the layer it draws on.

const DIR := "res://assets/ui/"
## Scrim behind pause / options / inspect: ink 2e222f at ~70 %.
const SCRIM := Color(0.18, 0.133, 0.184, 0.7)
const MARGINS: Dictionary = {
	&"panel": [4, 4, 4, 4],
	&"window": [6, 6, 6, 6],
	&"dialogue": [6, 6, 6, 6],
	&"button_normal": [4, 4, 4, 6],
	&"button_pressed": [4, 6, 4, 4],
	&"button_disabled": [4, 4, 4, 6],
	&"toast": [5, 5, 5, 5],
	&"toast_error": [5, 5, 5, 5],
	&"banner": [8, 8, 8, 8],
	&"slider_track": [3, 3, 3, 3],
	&"slider_fill": [3, 3, 3, 3],
	&"segment_normal": [3, 3, 3, 5],
	&"segment_selected": [3, 3, 3, 5],
	&"segment_pressed": [3, 5, 3, 3],
}


static func texture(name: StringName, texel: int = 1) -> Texture2D:
	var tex: Texture2D = load(DIR + name + ".png")
	if texel <= 1:
		return tex
	var img := tex.get_image()
	img.resize(img.get_width() * texel, img.get_height() * texel, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


static func stylebox(name: StringName, texel: int = 1) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(name, texel)
	var m: Array = MARGINS[name]
	box.texture_margin_left = m[0] * texel
	box.texture_margin_top = m[1] * texel
	box.texture_margin_right = m[2] * texel
	box.texture_margin_bottom = m[3] * texel
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box
