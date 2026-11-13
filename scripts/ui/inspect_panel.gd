class_name InspectPanel
extends Control
## Goob inspect view (slice §2B UI grill): the board dims; a panel shows the
## Goob big on the left, its name (accent colour) and card text on the right,
## and a flavour line in italics across the bottom. Vanilla: name + flavour
## only. The scenario opens it on a double tap and closes it on the next tap.

## M4 placeholder until the writing session (CLAUDE.md).
const FLAVOUR_PLACEHOLDER := "Flavour text coming soon."
const COLOR_NAME := Color(1.0, 0.85, 0.3)
const TEX_PLAYER := preload("res://assets/goobs/vanilla/blue_yaw/frame_00.png")
const TEX_OPPONENT := preload("res://assets/goobs/vanilla/red_yaw/frame_00.png")

var _goob_rect: TextureRect
var _name_label: Label
var _effect_label: Label
var _flavour_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_color = COLOR_NAME
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 20)
	panel.add_child(rows)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	rows.add_child(top)
	_goob_rect = TextureRect.new()
	_goob_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_goob_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_goob_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_goob_rect.custom_minimum_size = Vector2(200, 200)
	top.add_child(_goob_rect)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 16)
	top.add_child(text)
	_name_label = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.add_theme_color_override("font_color", COLOR_NAME)
	text.add_child(_name_label)
	_effect_label = _make_label(28, HORIZONTAL_ALIGNMENT_CENTER)
	text.add_child(_effect_label)
	_flavour_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_flavour_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	var italic := FontVariation.new()
	italic.base_font = ThemeDB.fallback_font
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	_flavour_label.add_theme_font_override("font", italic)
	rows.add_child(_flavour_label)


## Shows `goob` in its side's colour. `size_px`: the big Goob's edge length
## (2× the hand Goob, slice §2B).
func open(goob: GoobDefinition, side: BoardState.CellOwner, size_px: float) -> void:
	_goob_rect.texture = TEX_PLAYER if side == BoardState.CellOwner.PLAYER else TEX_OPPONENT
	_goob_rect.custom_minimum_size = Vector2(size_px, size_px)
	_name_label.text = goob.display_name
	_effect_label.text = goob.effect_description
	_effect_label.visible = not goob.effect_description.is_empty()
	_flavour_label.text = FLAVOUR_PLACEHOLDER
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func name_text() -> String:
	return _name_label.text


func effect_text() -> String:
	return _effect_label.text if _effect_label.visible else ""


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
