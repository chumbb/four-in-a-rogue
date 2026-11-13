class_name HandView
extends Control
## The player's hand: up to 5 Goob faces in a shallow fan on the table (slice
## §2B). Display only: the scenario owns the rules and the touch input, and
## hit-tests with goob_at().
##
## Cards are kept in the same order as Deck.hand. Hand Goobs are one whole
## pixel step bigger than board Goobs (set_pixel_size()).

const TEX_GOOB := preload("res://assets/goobs/vanilla/blue_yaw/frame_00.png")
const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")
const GOOB_PX := 32 ## game px
const FAN_STEP_DEG := 4.0 ## tilt per card away from the centre
const FAN_SINK_PX := 4.0 ## edge cards sit lower (logical px per step²)
const GAP_MIN := 16.0 ## logical px between Goobs
const SIDE_INSET := 24.0 ## keep clear of the Android back swipe
const LIFT_PX := 4 ## hand px a selected Goob rises (slice §2B)
const LAYOUT_SEC := 0.18
## Drawn Goob: pops in big at the screen centre, holds, flies to the fan.
const REVEAL_POP_SEC := 0.15
const REVEAL_HOLD_SEC := 0.55
const REVEAL_FLY_SEC := 0.25
const REVEAL_SCALE := 2.0
const COLOR_OUTLINE := Color(0.08, 0.05, 0.1, 1.0)
const COLOR_OUTLINE_SELECTED := Color(0.85, 0.95, 1.0, 1.0)

## Sound cues: &"draw_pop" (drawn Goob pops in), &"fly" (it flies to the fan).
signal hand_sound(kind: StringName)

## Tests set false: everything snaps into place at once.
var animate := true

var _cards: Array[Node2D] = []
var _px := 1.0 ## logical px per game px
var _selected := -1
var _dragged := -1
var _revealing: Node2D ## the drawn Goob still flying in (layout skips it)
var _outline: ShaderMaterial
var _outline_selected: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outline = _make_outline(COLOR_OUTLINE)
	_outline_selected = _make_outline(COLOR_OUTLINE_SELECTED)
	item_rect_changed.connect(layout.bind(false))


# --- Public API ------------------------------------------------------------

func set_pixel_size(px: float) -> void:
	_px = px
	for card in _cards:
		(card.get_node("Sprite") as Sprite2D).scale = Vector2(_px, _px)
		_place_label(card)
	layout(false)


## Replaces all cards with `goobs` (no animation).
func rebuild(goobs: Array[GoobDefinition]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_selected = -1
	_dragged = -1
	for goob in goobs:
		_cards.append(_make_card(goob))
	layout(false)


func count() -> int:
	return _cards.size()


## Index of the hand Goob under a viewport position, or -1.
func goob_at(pos: Vector2) -> int:
	var half := GOOB_PX * _px * 0.5
	# Last card wins: later cards draw on top.
	for i in range(_cards.size() - 1, -1, -1):
		var centre := get_global_transform() * _slot(i).origin
		if Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0).has_point(pos):
			return i
	return -1


## Viewport centre of a card's resting place (for tests and fly-ins).
func slot_center(index: int) -> Vector2:
	return get_global_transform() * _slot(index).origin


## Lifts the Goob at `index` with a white/blue outline; -1 lowers all.
func select(index: int) -> void:
	_selected = index
	for i in _cards.size():
		var sprite: Sprite2D = _cards[i].get_node("Sprite")
		sprite.material = _outline_selected if i == index else _outline
	layout(true)


func selected() -> int:
	return _selected


## The selected Goob leaves the fan and follows the finger.
func begin_drag(index: int) -> void:
	_dragged = index
	var card := _cards[index]
	card.z_index = 10
	_kill_tween(card)
	card.rotation = 0.0


func drag_to(pos: Vector2) -> void:
	if _dragged == -1:
		return
	_cards[_dragged].position = get_global_transform().affine_inverse() * pos


## Hidden while the aim float shows the same Goob on top of the board.
func set_drag_visible(on: bool) -> void:
	if _dragged != -1:
		_cards[_dragged].visible = on


func is_dragging() -> bool:
	return _dragged != -1


## Drag cancelled: the Goob flies back into the fan.
func cancel_drag() -> void:
	if _dragged == -1:
		return
	_cards[_dragged].visible = true
	_cards[_dragged].z_index = 0
	_dragged = -1
	layout(true)


## The Goob at `index` was played: it leaves the hand and the fan closes up.
func remove(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index].queue_free()
	_cards.remove_at(index)
	_dragged = -1
	_selected = -1
	select(-1)


## A drawn Goob pops in big at the screen centre, then flies into its place
## at the right end of the fan. Await to know when it has arrived.
func reveal(goob: GoobDefinition) -> void:
	var card := _make_card(goob)
	_cards.append(card)
	var index := _cards.size() - 1
	if not animate:
		layout(false)
		return
	_revealing = card
	layout(true) # make room for it
	card.z_index = 20
	card.position = get_global_transform().affine_inverse() * (get_viewport_rect().size * 0.5)
	card.rotation = 0.0
	card.scale = Vector2(0.4, 0.4)
	var target := _slot(index)
	var tween := card.create_tween()
	tween.tween_callback(hand_sound.emit.bind(&"draw_pop"))
	tween.tween_property(card, "scale", Vector2.ONE * REVEAL_SCALE, REVEAL_POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(REVEAL_HOLD_SEC)
	tween.tween_callback(hand_sound.emit.bind(&"fly"))
	tween.set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE, REVEAL_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "position", target.origin, REVEAL_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "rotation", target.get_rotation(), REVEAL_FLY_SEC)
	card.set_meta("tween", tween)
	await tween.finished
	if is_instance_valid(card):
		card.z_index = 0
	_revealing = null


## Moves every card (except one being dragged) to its fan slot.
func layout(animated: bool) -> void:
	for i in _cards.size():
		var card := _cards[i]
		if i == _dragged or card == _revealing:
			continue
		var slot := _slot(i)
		_kill_tween(card)
		card.scale = Vector2.ONE
		if animated and animate and is_inside_tree():
			var tween := card.create_tween().set_parallel()
			tween.tween_property(card, "position", slot.origin, LAYOUT_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "rotation", slot.get_rotation(), LAYOUT_SEC)
			card.set_meta("tween", tween)
		else:
			card.position = slot.origin
			card.rotation = slot.get_rotation()


# --- Layout ------------------------------------------------------------------

## Resting transform of card `index` (local coords): spread across the zone
## without overlap, tilted outward, edge cards a little lower, lifted when
## selected.
func _slot(index: int) -> Transform2D:
	var n := _cards.size()
	var goob := GOOB_PX * _px
	var mid := (n - 1) * 0.5
	var step := goob + GAP_MIN * 2.0
	if n > 1:
		step = minf(step, (size.x - SIDE_INSET * 2.0 - goob) / (n - 1))
	var offset := index - mid
	var x := size.x * 0.5 + offset * step
	var y := LIFT_PX * _px + 8.0 + goob * 0.5 + offset * offset * FAN_SINK_PX
	if index == _selected:
		y -= LIFT_PX * _px
	return Transform2D(deg_to_rad(offset * FAN_STEP_DEG), Vector2(x, y))


# --- Cards -------------------------------------------------------------------

func _make_card(goob: GoobDefinition) -> Node2D:
	var card := Node2D.new()
	card.name = "Goob"
	card.set_meta("goob", goob)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TEX_GOOB
	sprite.material = _outline
	sprite.scale = Vector2(_px, _px)
	card.add_child(sprite)
	# Placeholder until each type has its own face: specials carry their name.
	if goob.effect_type != GoobDefinition.EffectType.NONE:
		var label := Label.new()
		label.name = "Name"
		label.text = goob.display_name.trim_suffix(" Goob")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		_place_label(card)
	add_child(card)
	return card


func _place_label(card: Node2D) -> void:
	var label: Label = card.get_node_or_null("Name")
	if label == null:
		return
	var half := GOOB_PX * _px * 0.5
	label.size = Vector2(half * 2.0 + 24.0, 24.0)
	label.position = Vector2(-half - 12.0, half - 6.0)


func _kill_tween(card: Node2D) -> void:
	if card.has_meta("tween"):
		var tween: Tween = card.get_meta("tween")
		if tween and tween.is_valid():
			tween.kill()


func _make_outline(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_color", color)
	return material
