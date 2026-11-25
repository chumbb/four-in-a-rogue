class_name GoobLook
extends RefCounted

## How special Goobs stand apart (M6f, Sean 2026-11-24): every special is
## tinted darker (the outline shader's `tint`), wears its family's ring over
## its rim (a child sprite on the same 32 px frame), and a legendary one
## (Uniquely powerful) also glints. Shared by the board, the hand and inspect.

const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")
const SPECIAL_TINT := 0.9
const RING_NODE := &"Ring"

static var _materials: Dictionary = {}


## The outline material for `goob` with `outline` as its outline colour
## (shared per look, so the scoring gold and the hand's selected outline keep
## working by swapping materials).
static func material(goob: GoobDefinition, outline: Color = Color(0.08, 0.05, 0.1, 1.0)) -> ShaderMaterial:
	var special := goob != null and goob.is_special()
	var legendary := goob != null and goob.is_legendary()
	return _material(outline, SPECIAL_TINT if special else 1.0, legendary)


static func _material(outline: Color, tint: float, glint: bool, grow := true) -> ShaderMaterial:
	var key := "%s/%s/%s/%s" % [outline.to_html(), tint, glint, grow]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = OUTLINE_SHADER
		m.set_shader_parameter("outline_color", outline)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("glint", glint)
		m.set_shader_parameter("grow", grow)
		_materials[key] = m
	return _materials[key]


## Gives `sprite` (a Sprite2D or TextureRect showing `goob`'s 32 px art) its
## look: tint + glint material, and the ring overlay as a child (removed for
## a plain Goob). Call again when the Goob, its side or its outline changes.
static func dress(sprite: CanvasItem, goob: GoobDefinition, side: BoardState.CellOwner, outline: Color = Color(0.08, 0.05, 0.1, 1.0)) -> void:
	var rect := sprite is TextureRect
	if rect:
		# Control rects (inspect) have no outline and can't grow the quad.
		sprite.material = _material(Color(0, 0, 0, 0), SPECIAL_TINT if goob != null and goob.is_special() else 1.0, goob != null and goob.is_legendary(), false)
	else:
		sprite.material = material(goob, outline)
	var ring_tex: Texture2D = goob.ring_texture(side) if goob != null else null
	var ring := sprite.get_node_or_null(NodePath(RING_NODE))
	if ring_tex == null:
		if ring != null:
			ring.queue_free()
			sprite.remove_child(ring)
		return
	if ring == null:
		if rect:
			var r := TextureRect.new()
			r.set_anchors_preset(Control.PRESET_FULL_RECT)
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = (sprite as TextureRect).stretch_mode
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring = r
		else:
			var s := Sprite2D.new()
			s.centered = (sprite as Sprite2D).centered
			ring = s
		ring.name = RING_NODE
		sprite.add_child(ring)
	ring.texture = ring_tex
	# The ring itself isn't darkened or outlined, but glints with its Goob.
	ring.material = _material(Color(0, 0, 0, 0), 1.0, goob.is_legendary(), not rect)


## Shows or hides `sprite`'s ring (hidden while spin frames own the texture).
static func show_ring(sprite: CanvasItem, on: bool) -> void:
	var ring := sprite.get_node_or_null(NodePath(RING_NODE)) as CanvasItem
	if ring != null:
		ring.visible = on
