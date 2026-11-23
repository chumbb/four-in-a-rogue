class_name HandView
extends Control
## The player's hand: up to 5 Goob faces in a shallow fan on the table (slice
## §2B). Display only: the scenario owns the rules and the touch input, and
## hit-tests with goob_at().
##
## Cards are kept in the same order as Deck.hand. Hand Goobs are one whole
## pixel step bigger than board Goobs (set_pixel_size()).

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
## Discarded Goob (M6e): the same pop, a longer hold, then off the screen;
## never sped up by Fast.
const DISCARD_HOLD_SEC := 0.8
const DISCARD_SEC := REVEAL_POP_SEC + DISCARD_HOLD_SEC + REVEAL_FLY_SEC
const COLOR_OUTLINE := Color(0.08, 0.05, 0.1, 1.0)
const COLOR_OUTLINE_SELECTED := Color(0.85, 0.95, 1.0, 1.0)
## Testing aid (Sean, 2026-11-23): specials still on the plain Goob art (M6e,
## until Art pass F) show their name below them in the hand.
const NAME_WIDTH := 200.0
const NAME_GAP := 2.0
const COLOR_NAME := Color(1.0, 0.93, 0.7)
const COLOR_NAME_OUTLINE := Color(0.08, 0.05, 0.1)

## Sound cues: &"draw_pop" (drawn Goob pops in), &"fly" (it flies to the fan).
signal hand_sound(kind: StringName)

## Tests set false: everything snaps into place at once.
var animate := true
## Play-animation speed (Settings: Fast = 2): draw reveal, fly-in, re-layout.
var speed_scale := 1.0

var _cards: Array[Node2D] = []
var _px := 1.0 ## logical px per game px
var _fan_width := 0.0 ## logical px; 0 = whole zone (set_fan_width)
var _selected := -1
var _dragged := -1
var _revealing: Node2D ## the drawn Goob still flying in (layout skips it)
var _outline: ShaderMaterial
var _outline_selected: ShaderMaterial
## M6c faces: giggle while selected or dragged, worried during the low-time
## fuse, idle (blinking) otherwise.
var _worried := false
## End of the scenario: &"happy" (you won) / &"sad" (you lost); &"" = none.
var _mood := &""
var _face_clock := 0.0
var _face_frames: Dictionary = {}


func _process(delta: float) -> void:
	_face_clock += delta
	for i in _cards.size():
		var card := _cards[i]
		if not is_instance_valid(card):
			continue
		var face := &"idle"
		if _mood != &"":
			face = _mood
		elif i == _selected or i == _dragged:
			face = &"giggle"
		elif _worried:
			face = &"worried"
		if card.get_meta(&"face", &"") != face:
			card.set_meta(&"face", face)
			card.set_meta(&"face_t0", _face_clock - (randf() * 3.0 if face == &"idle" else 0.0))
		var goob: GoobDefinition = card.get_meta("goob")
		if not _face_frames.has(goob.art_id):
			_face_frames[goob.art_id] = goob.sprite_frames(BoardState.CellOwner.PLAYER)
		var texture := GoobDefinition.face_frame(_face_frames[goob.art_id], face, _face_clock - float(card.get_meta(&"face_t0")))
		if texture:
			(card.get_node("Sprite") as Sprite2D).texture = texture


## Low-time fuse on/off: hand Goobs look worried (slice §2B, Sean 2026-11-20).
func set_worried(on: bool) -> void:
	_worried = on


## Hand Goobs react to the result (Sean, M6c playtest): &"happy" / &"sad".
func set_mood(face: StringName) -> void:
	_mood = face


## The face the hand Goob at `index` shows (tests).
func face_of(index: int) -> StringName:
	if index < 0 or index >= _cards.size():
		return &""
	return _cards[index].get_meta(&"face", &"idle")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outline = _make_outline(COLOR_OUTLINE)
	_outline_selected = _make_outline(COLOR_OUTLINE_SELECTED)
	item_rect_changed.connect(layout.bind(false))


# --- Public API ------------------------------------------------------------

## Widest span (logical px) the fan may use, e.g. the top of the biome's hand
## prop; 0 = the whole zone minus the side insets.
func set_fan_width(width: float) -> void:
	_fan_width = width
	layout(false)


func set_pixel_size(px: float) -> void:
	_px = px
	for card in _cards:
		(card.get_node("Sprite") as Sprite2D).scale = Vector2(_px, _px)
		_place_name(card)
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


## Viewport centre of the Goob at `index` where it is now (lifted, or under
## the finger while dragged). Vector2.INF if out of range.
func card_center(index: int) -> Vector2:
	if index < 0 or index >= _cards.size():
		return Vector2.INF
	var card := _cards[index]
	var sprite: Sprite2D = card.get_node("Sprite")
	return sprite.get_global_transform() * Vector2.ZERO if sprite.centered else sprite.get_global_transform() * (sprite.texture.get_size() * 0.5)


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
	if not animate:
		layout(false)
		return
	_revealing = card
	card.visible = false
	# The first turn's draw runs from the scenario's _ready(), before the
	# deferred table layout has sized the hand: wait a frame so the centre and
	# the fan slots are measured on the real layout.
	await get_tree().process_frame
	if not is_instance_valid(card):
		_revealing = null
		return
	card.visible = true
	layout(true) # make room for it
	card.z_index = 20
	card.position = get_global_transform().affine_inverse() * (get_viewport_rect().size * 0.5)
	card.rotation = 0.0
	card.scale = Vector2(0.4, 0.4)
	var pop := card.create_tween().set_speed_scale(speed_scale)
	pop.tween_callback(hand_sound.emit.bind(&"draw_pop"))
	pop.tween_property(card, "scale", Vector2.ONE * REVEAL_SCALE, REVEAL_POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(REVEAL_HOLD_SEC)
	card.set_meta("tween", pop)
	await pop.finished
	if not is_instance_valid(card):
		_revealing = null
		return
	# Target measured now, not at pop time, in case the zone resized meanwhile.
	hand_sound.emit(&"fly")
	var target := _slot(_cards.find(card))
	var fly := card.create_tween().set_speed_scale(speed_scale).set_parallel()
	fly.tween_property(card, "scale", Vector2.ONE, REVEAL_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(card, "position", target.origin, REVEAL_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(card, "rotation", target.get_rotation(), REVEAL_FLY_SEC)
	card.set_meta("tween", fly)
	await fly.finished
	_revealing = null
	if is_instance_valid(card):
		card.z_index = 0
	layout(false) # settle every card on the current layout


## A discarded Goob (TurnLoop.discard_from) pops in big at the screen centre
## like a drawn one, holds, then flies off the bottom (yours) or the top (his)
## and is freed. Yours first leaves the fan at hand `index` (the fan follows
## Deck.hand order). Its timing ignores speed_scale (never faster on Fast):
## DISCARD_SEC in all. Await to know when it has gone.
func play_discard(goob: GoobDefinition, side: BoardState.CellOwner, index: int = -1) -> void:
	if side == BoardState.CellOwner.PLAYER and index >= 0 and index < _cards.size():
		_take_card(index)
	if not animate or not is_inside_tree():
		return
	var card := _make_card(goob, side)
	card.z_index = 20
	var view := get_viewport_rect().size
	card.position = get_global_transform().affine_inverse() * (view * 0.5)
	card.scale = Vector2(0.4, 0.4)
	var pop := card.create_tween()
	pop.tween_callback(hand_sound.emit.bind(&"draw_pop"))
	pop.tween_property(card, "scale", Vector2.ONE * REVEAL_SCALE, REVEAL_POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(DISCARD_HOLD_SEC)
	pop.tween_callback(hand_sound.emit.bind(&"fly"))
	var off := GOOB_PX * _px * REVEAL_SCALE
	var exit_y := view.y + off if side == BoardState.CellOwner.PLAYER else -off
	var target := get_global_transform().affine_inverse() * Vector2(view.x * 0.5, exit_y)
	pop.tween_property(card, "position", target, REVEAL_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pop.finished
	if is_instance_valid(card):
		card.queue_free()


## Takes card `index` out of the fan, keeping the selection and the dragged
## card on the same Goobs (indices above it shift down).
func _take_card(index: int) -> void:
	var card := _cards[index]
	if card == _revealing:
		_revealing = null
	card.queue_free()
	_cards.remove_at(index)
	for which in [&"_selected", &"_dragged"]:
		var at: int = get(which)
		if at == index:
			set(which, -1)
		elif at > index:
			set(which, at - 1)
	select(_selected) # outlines follow the shifted selection; re-lays out


## The Goobs in the fan, in order (tests).
func goobs() -> Array[GoobDefinition]:
	var list: Array[GoobDefinition] = []
	for card in _cards:
		list.append(card.get_meta("goob"))
	return list


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
			var tween := card.create_tween().set_speed_scale(speed_scale).set_parallel()
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
		var span := size.x - SIDE_INSET * 2.0
		if _fan_width > 0.0:
			span = minf(span, _fan_width)
		step = minf(step, (span - goob) / (n - 1))
	var offset := index - mid
	var x := size.x * 0.5 + offset * step
	var y := LIFT_PX * _px + 8.0 + goob * 0.5 + offset * offset * FAN_SINK_PX
	if index == _selected:
		y -= LIFT_PX * _px
	return Transform2D(deg_to_rad(offset * FAN_STEP_DEG), Vector2(x, y))


# --- Cards -------------------------------------------------------------------

func _make_card(goob: GoobDefinition, side := BoardState.CellOwner.PLAYER) -> Node2D:
	var card := Node2D.new()
	card.name = "Goob"
	card.set_meta("goob", goob)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = goob.still(side)
	sprite.material = _outline
	sprite.scale = Vector2(_px, _px)
	card.add_child(sprite)
	if goob.art_id == "vanilla" and goob.effect_type != GoobDefinition.EffectType.NONE:
		var label := Label.new()
		label.name = "Name"
		label.text = goob.display_name.trim_suffix(" Goob")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UiTheme.FONT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", COLOR_NAME)
		label.add_theme_color_override("font_outline_color", COLOR_NAME_OUTLINE)
		label.add_theme_constant_override("outline_size", 6)
		card.add_child(label)
		_place_name(card)
	add_child(card)
	return card


## Puts a card's name label (if any) centred just below its Goob.
func _place_name(card: Node2D) -> void:
	var label := card.get_node_or_null("Name") as Label
	if label != null:
		# Monogram on the UI pixel unit (the root theme doesn't reach Controls
		# under the card's Node2D).
		label.add_theme_font_size_override("font_size", UiTheme.font_size(get_window(), 1) if is_inside_tree() else UiTheme.NATIVE_SIZE)
		label.size = Vector2(NAME_WIDTH, 0.0)
		label.position = Vector2(-NAME_WIDTH * 0.5, GOOB_PX * _px * 0.5 + NAME_GAP)


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
