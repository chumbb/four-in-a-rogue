class_name BoardView2D
extends Control
## Upright 2D pixel board (slice §2A). Display only: owns no game rules or
## input. The scenario reads BoardState, calls sync_from_board() / play_drop(),
## and hit-tests touches against column_rect().
##
## Everything here is drawn in game pixels under one Node2D (`_pixel`) scaled
## to the largest whole number of physical pixels per game pixel that fits a
## 270-game-px-wide canvas across the window (4× at 1080 wide). Its origin is
## snapped to a whole physical pixel and every child sits on whole game
## pixels, so all pixels on the board are the same size.
##
## Layers back to front: board back → Goobs → board front (holes) → effects. Goobs above
## the board (falling in, rolling on top) pass behind the front panel's rail.

const COLUMNS := BoardState.COLUMNS
const ROWS := BoardState.ROWS

const CANVAS_WIDTH := 270 ## game px; sets the pixel scale (slice §2A)
const CELL := 32
const GRID_ORIGIN := Vector2i(8, 8) ## top-left of cell (0, top row) in the board art
const BOARD_SIZE := Vector2i(240, 216) ## board art canvas (panel + an empty 8 px strip; no feet)
const PANEL_HEIGHT := 208 ## the board panel itself
## The Goob disc sits 1 px low in its 32 px frame; this centres it in a hole.
const GOOB_OFFSET := Vector2i(0, -1)

## Every played Goob first appears resting on top of the board over its column
## for a moment (Sean, 2026-11-12; the M6 flip lands here), then falls in.
const TOP_Y := -31 ## Goob resting on the top rail
const TOP_PAUSE_SEC := 0.2
## Shorter rest after a flip into place (the flip already held the Goob on
## top; Sean, M6c playtest: it lingered too long before dropping).
const FLIPPED_PAUSE_SEC := 0.06
## Drop: gravity in game px/s², tuned so a fall from the top of the board to
## the bottom row takes ~0.32 s; then a small settle bounce.
const GRAVITY := 3800.0
const BOUNCE_PX := 3
const BOUNCE_SEC := 0.1
## Roll (timeout into a full column): from the top, column by column.
const ROLL_SEC_PER_COLUMN := 0.11
const ROLL_BUMP_PX := 6 ## nudge into the board edge on a bounce
const HIGHLIGHT_MODULATE := Color(1.5, 1.5, 1.5)
## Aim preview: while the player holds a legal column, their Goob floats on top
## of the board over it (Sean, 2026-11-13), bobbing gently.
const FLOAT_BOB_PX := 2
const FLOAT_BOB_SEC := 0.4
## M6c play animations (slice §2B): the player's Goob flips up from the hand
## to its float spot on top of the board; the opponent's rises with a flip
## from behind the board's top edge to the same spot, then drops.
const HAND_FLIP_SEC := 0.22
## Aim ghost (Sean, M6c playtest): the float over the aimed column is a faint
## copy of the Goob, arriving with a horizontal flip. When the drop commits it
## disappears and the Goob itself flips into place vertically, then drops.
const GHOST_ALPHA := 0.45
const FLIP_IN_SEC := 0.24
const FLIP_IN_HOP_PX := 6
const HAND_FLIP_ARC_PX := 16
const BEHIND_START_Y := 2 ## game px: hidden behind the top of the panel
const BEHIND_RISE_PX := 10 ## rises this far above the rest spot, then settles
const BEHIND_RISE_SEC := 0.22
const BEHIND_SETTLE_SEC := 0.1

const TEX_BACK := preload("res://assets/board/board_back.png")
const TEX_FRONT := preload("res://assets/board/board_front.png")
const VANILLA := preload("res://resources/goobs/vanilla_goob.tres")
const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")

## M5 impact animations (placeholders until each type has its own art). Every
## effect has its moment (Sean, 2026-11-19): wind-up → marked target → impact
## → settle.
## Wind-up: the effect's Goob rises and glows, then shivers.
const CHARGE_PX := 4
const CHARGE_SEC := 0.3
const CHARGE_GLOW := Color(1.8, 1.8, 1.8)
const CHARGE_SHIVER: Array[int] = [1, -1, 1, -1, 0]
const CHARGE_SHIVER_SEC := 0.035
## Marked target: blinks white twice.
const TELEGRAPH_BLINKS := 2
const TELEGRAPH_SEC := 0.09
const TELEGRAPH_MODULATE := Color(3.0, 3.0, 3.0)
## Impact: the Goob lunges at its target.
const LUNGE_PX := 6
const LUNGE_SEC := 0.06
const SETTLE_SEC := 0.12
## Board shakes (game px per step).
const SHAKE_INVALID: Array[int] = [3, -3, 2, -2, 1, -1, 0]
const SHAKE_SMALL: Array[int] = [2, -2, 1, -1, 0]
const SHAKE_BIG: Array[int] = [6, -6, 5, -5, 3, -3, 2, -2, 1, -1, 0]
## Convincing flip: the target is knocked up and spins about its vertical
## axis (baked yaw frames, back face included) into the new colour.
const FLIP_OLD_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5] ## face → edge → back → edge
const FLIP_NEW_FRAMES: Array[int] = [6, 7, 0] ## edge → face, new colour
const FLIP_FRAME_SEC := 0.06
const FLIP_HOP_PX := 12
const SCORE_FLIP_HOP_PX := 4
const HOP_PX := 4 ## scoring bounce (doubled)
## Fat: slower, higher wind-up, harder lunge, hit-stop on the white target.
const FAT_CHARGE_PX := 7
const FAT_CHARGE_SEC := 0.45
const FAT_LUNGE_PX := 9
const HIT_STOP_SEC := 0.14
const AFTER_IMPACT_SEC := 0.3
const DEBRIS_COUNT := 18
const DEBRIS_SPEED := 130.0
const DEBRIS_SEC := 0.55
const DEBRIS_GRAVITY := 420.0
const COLOR_DEBRIS := {
	BoardState.CellOwner.PLAYER: Color("4d9be6"),
	BoardState.CellOwner.OPPONENT: Color("e83b3b"),
}
## Sparkles (flip landing, Popular's summon and landing).
const SPARKLE_COUNT := 10
const SPARKLE_SPEED := 70.0
const SPARKLE_GRAVITY := 120.0
## Popular: two cheering hops, then the Vanilla arcs out to the top rail.
const CHEER_PX := 6
const CHEER_SEC := 0.2
const SUMMON_ARC_SEC := 0.5
const SUMMON_ARC_PX := 28
## Plentiful: ghost Goobs pop out, hang, then shoot to their hand (visible even
## though the opponent's hand is hidden).
const GHOST_RISE_PX := 30
const GHOST_RISE_SEC := 0.25
const GHOST_HANG_SEC := 0.3
const GHOST_FLY_PX := 220
const GHOST_FLY_SEC := 0.3
const GHOST_STAGGER_SEC := 0.18
## Fizzle (no target, Sean 2026-11-19): the wind-up falters; grey, head shake,
## a puff of smoke.
const FIZZLE_PX: Array[int] = [2, -2, 2, -2, 1, -1, 0]
const FIZZLE_STEP_SEC := 0.06
const FIZZLE_HOLD_SEC := 0.25
const FIZZLE_MODULATE := Color(0.55, 0.55, 0.6)
const COLOR_SMOKE := Color("9babb2")
const SMOKE_COUNT := 6
const SMOKE_SPEED := 25.0
const SMOKE_GRAVITY := -40.0
## Scoring recognition: gold outline + a hop on the scored Goobs.
const COLOR_GOLD := Color("f9c22b")
const RECOGNISE_HOP_PX := 6
## M6c expressions: every Goob token plays its face loop (idle by default,
## blinking now and then); reactions (surprised) last REACTION_SEC.
const REACTION_SEC := 1.2

## Sound cues during play_drop(): &"rest" (on top of the board), &"roll" (each
## column rolled over), &"bounce" (off the edge), &"fall". The landing itself
## is the caller's (play_drop() returns then). Effects (M5) add &"flip",
## &"crunch", &"popular", &"draw_pop", &"fizzle", and &"fall" + &"land" for
## Goobs falling after a destroy.
signal drop_sound(kind: StringName, side: BoardState.CellOwner)

## Tests set false: drops land at once and
## play_drop() returns immediately; effects only play their impact sound.
var animate := true
## Play-animation speed (Settings: Fast = 2). Idle loops and shakes ignore it.
var speed_scale := 1.0
## Options "Screen shake" (the scenario sets it from Settings).
var shake_enabled := true

## Physical pixels per game pixel (whole number) and logical px per game px.
var pixel_scale := 1
var _k := 1.0

var _pixel: Node2D
var _goobs: Node2D
var _fx: Node2D ## effects layer above the board front (slice §2A layers)
var _origin := Vector2.ZERO ## _pixel position without shake (local, logical px)
var _shake_px := 0
var _shake_tween: Tween
var _tokens: Dictionary = {} ## Vector2i(column, row) -> Sprite2D
var _token_owner: Dictionary = {} ## Vector2i -> BoardState.CellOwner
var _highlight_tweens: Dictionary = {} ## Vector2i -> Tween
var _outline: ShaderMaterial
var _outline_gold: ShaderMaterial
var _preview: Sprite2D
var _preview_tween: Tween
var _preview_flight: Tween
var _preview_frames: Tween
## Clips the opponent's Goob rising from behind the board to above its top edge.
var _behind: Control
var _token_goob: Dictionary = {} ## Vector2i -> GoobDefinition (its art)
## Which Goob sits in a cell, for sync_from_board: (column, row) -> GoobDefinition
## or null (Vanilla). The scenario sets TurnLoop.goob_at.
var goob_lookup: Callable
## SpriteFrames per "art_id/team" (expression loops).
var _face_frames: Dictionary = {}
var _face_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline_gold = ShaderMaterial.new()
	_outline_gold.shader = OUTLINE_SHADER
	_outline_gold.set_shader_parameter("outline_color", COLOR_GOLD)
	_pixel = Node2D.new()
	_pixel.name = "PixelLayer"
	_pixel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_pixel)
	_pixel.add_child(_make_sprite(TEX_BACK, "Back"))
	_behind = Control.new()
	_behind.name = "BehindBoard"
	_behind.clip_contents = true
	_behind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_behind.position = Vector2(0, -64)
	_behind.size = Vector2(BOARD_SIZE.x, 64)
	_pixel.add_child(_behind)
	_goobs = Node2D.new()
	_goobs.name = "Goobs"
	_pixel.add_child(_goobs)
	_preview = _make_sprite(VANILLA.still(BoardState.CellOwner.PLAYER), "Preview")
	_preview.modulate.a = GHOST_ALPHA
	_preview.material = _outline
	_preview.visible = false
	_goobs.add_child(_preview)
	_pixel.add_child(_make_sprite(TEX_FRONT, "Front"))
	_fx = Node2D.new()
	_fx.name = "Effects"
	_pixel.add_child(_fx)
	get_viewport().size_changed.connect(_update_scale)
	item_rect_changed.connect(_place_layer)
	_update_scale()


# --- Expressions (M6c) -----------------------------------------------------

func _process(delta: float) -> void:
	_face_clock += delta
	for cell: Vector2i in _tokens:
		var token: Sprite2D = _tokens[cell]
		if is_instance_valid(token):
			_show_face(token, _token_goob.get(cell, VANILLA), _token_owner[cell])
	if _preview.visible:
		_show_face(_preview, _preview.get_meta(&"goob", VANILLA), BoardState.CellOwner.PLAYER)


## Sets the face of the Goob in `cell` (&"idle", &"happy", &"sad",
## &"celebrating", &"surprised", …). `sec` > 0 = a reaction that returns to idle.
func set_face(cell: Vector2i, face: StringName, sec: float = 0.0) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return
	token.set_meta(&"face", face)
	token.set_meta(&"face_until", _face_clock + sec if sec > 0.0 else 0.0)
	token.set_meta(&"face_t0", _face_clock)


## Every Goob of `side` gets `face` (end lead-in: winner happy, loser sad).
func set_side_face(side: BoardState.CellOwner, face: StringName) -> void:
	for cell: Vector2i in _tokens:
		if _token_owner[cell] == side:
			set_face(cell, face)


## The face the Goob in `cell` is showing (tests); &"" if empty.
func face_at(cell: Vector2i) -> StringName:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return &""
	return _current_face(token)


## True when the Goob in `cell` shows `goob`'s art for `side` (its still or
## any frame of its expression loops). For tests.
func shows_goob(cell: Vector2i, goob: GoobDefinition, side: BoardState.CellOwner) -> bool:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return false
	if token.texture == goob.still(side):
		return true
	var frames := goob.sprite_frames(side)
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			if frames.get_frame_texture(anim, i) == token.texture:
				return true
	return false


func _current_face(token: Sprite2D) -> StringName:
	var until: float = token.get_meta(&"face_until", 0.0)
	if until > 0.0 and _face_clock >= until:
		token.set_meta(&"face", &"idle")
		token.set_meta(&"face_until", 0.0)
	return token.get_meta(&"face", &"idle")


func _show_face(token: Sprite2D, goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	if token.get_meta(&"busy", false):
		return
	var face := _current_face(token)
	if not token.has_meta(&"face_t0"):
		# Idle blinks out of step: each Goob starts at a random point.
		token.set_meta(&"face_t0", _face_clock - randf() * 3.0)
	var key := "%s/%d" % [goob.art_id, side]
	if not _face_frames.has(key):
		_face_frames[key] = goob.sprite_frames(side)
	var t: float = _face_clock - token.get_meta(&"face_t0", 0.0)
	var texture := GoobDefinition.face_frame(_face_frames[key], face, t)
	if texture:
		token.texture = texture


# --- Public API ------------------------------------------------------------

## Rebuilds Goobs so the view matches `board` exactly. Cheap at 42 cells.
## Handles add, remove (destroy) and owner change (flip).
func sync_from_board(board: BoardState) -> void:
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var side := board.get_owner(column, row)
			var had: BoardState.CellOwner = _token_owner.get(cell, BoardState.CellOwner.EMPTY)
			var goob := _lookup(cell) if side != BoardState.CellOwner.EMPTY else null
			if side == had and (side == BoardState.CellOwner.EMPTY or goob == _token_goob.get(cell)):
				continue
			_remove_token(cell)
			if side != BoardState.CellOwner.EMPTY:
				_add_token(cell, side, goob).position = cell_position(column, row)
	clear_highlight()


## Drops a new Goob into (column, row): it appears on top of the board over
## its column, pauses, then falls in. With a `roll_path` (timeout into a full
## column) it appears over roll_path[0], rolls along the path and falls into
## its last column. An off-board entry in the path (-1 or COLUMNS) is a bounce
## off that edge. The Goob counts as on the board at once, so a sync during
## the animation does not duplicate it. `goob` picks its art (null = Vanilla).
## Await this to know when it has landed.
## `flip_in`: the Goob flips into place vertically on top of the board first
## (a player's play: the faint aim ghost has just gone).
func play_drop(column: int, row: int, side: BoardState.CellOwner, roll_path: Array[int] = [], goob: GoobDefinition = null, from_behind: bool = false, flip_in: bool = false) -> void:
	hide_preview()
	var cell := Vector2i(column, row)
	_remove_token(cell)
	var token := _add_token(cell, side, goob)
	var target := cell_position(column, row)
	if not animate:
		token.position = target
		return
	if side == BoardState.CellOwner.PLAYER:
		set_face(cell, &"giggle") # still giggling from the hand until it lands
	var start := roll_path[0] if roll_path.size() > 1 else column
	token.position = Vector2(_column_x(start), TOP_Y)
	if from_behind:
		await _rise_from_behind(token, goob if goob else VANILLA, side)
		if not is_instance_valid(token):
			return
	elif flip_in:
		await _flip_in(token, goob if goob else VANILLA, side)
		if not is_instance_valid(token):
			return
	var tween := _tween()
	tween.tween_callback(drop_sound.emit.bind(&"rest", side))
	tween.tween_interval(FLIPPED_PAUSE_SEC if from_behind or flip_in else TOP_PAUSE_SEC)
	if roll_path.size() > 1:
		_queue_roll(tween, token, roll_path, side)
	tween.tween_callback(drop_sound.emit.bind(&"fall", side))
	_queue_fall(tween, token, TOP_Y, target)
	await tween.finished
	if is_instance_valid(token) and _tokens.get(cell) == token:
		set_face(cell, &"idle")


# --- Effects (M5) -------------------------------------------------------------
# Each effect has its moment (Sean, 2026-11-19 playtest): the Goob winds up
# (rises and glows), its random target is marked (blinks), the impact lands
# hard (lunge, hit-stop, shake, burst), then everything settles. Each awaits
# its animation; with animate off it only updates the view state.

## Convincing: winds up, marks `target`, lunges; the target is knocked up,
## spins round into `side`'s colour and lands with a sparkle.
func play_flip(source: Vector2i, target: Vector2i, side: BoardState.CellOwner) -> void:
	var token: Sprite2D = _tokens.get(target)
	if token == null:
		return
	var old: BoardState.CellOwner = _token_owner[target]
	_token_owner[target] = side
	var goob: GoobDefinition = _token_goob.get(target, VANILLA)
	if not animate:
		token.texture = goob.still(side)
		drop_sound.emit(&"flip", side)
		set_face(target, &"surprised", REACTION_SEC)
		return
	await _charge(source)
	await _telegraph(target)
	_lunge(source, target, LUNGE_PX)
	await _wait(LUNGE_SEC)
	drop_sound.emit(&"flip", side)
	_settle(source)
	var base_y := cell_position(target.x, target.y).y
	var spin_sec := FLIP_FRAME_SEC * (FLIP_OLD_FRAMES.size() + FLIP_NEW_FRAMES.size())
	var hop := _tween()
	hop.tween_method(_set_y.bind(token), base_y, base_y - FLIP_HOP_PX, spin_sec * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_method(_set_y.bind(token), base_y - FLIP_HOP_PX, base_y, spin_sec * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var frames := _tween()
	var old_yaw := goob.flip_frames(old)
	var new_yaw := goob.flip_frames(side)
	for i in FLIP_OLD_FRAMES:
		frames.tween_callback(_set_texture.bind(token, old_yaw[i]))
		frames.tween_interval(FLIP_FRAME_SEC)
	for i in FLIP_NEW_FRAMES:
		frames.tween_callback(_set_texture.bind(token, new_yaw[i]))
		frames.tween_interval(FLIP_FRAME_SEC)
	token.set_meta(&"busy", true) # the spin frames own the texture
	token.reparent(_fx, false) # knocked out of its hole, in front of the board
	await hop.finished
	token.reparent(_goobs, false)
	token.position = cell_position(target.x, target.y)
	drop_sound.emit(&"rest", side)
	token.texture = goob.still(side)
	token.set_meta(&"busy", false)
	set_face(target, &"surprised", REACTION_SEC)
	shake(SHAKE_SMALL)
	_burst(_centre_px(target), COLOR_DEBRIS[side], SPARKLE_COUNT, SPARKLE_SPEED, SPARKLE_GRAVITY)
	await _glow(token)


## Fat: winds up slowly (heavy), marks `target`, slams into it: hit-stop on a
## white flash, big shake, the target bursts; the Goobs above it then fall one
## row (BoardState.destroy_cell).
func play_destroy(source: Vector2i, target: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(target)
	if token == null:
		return
	var side: BoardState.CellOwner = _token_owner[target]
	# The Fat Goob itself may fall below (target under it): keep hold of it.
	var source_token: Sprite2D = _tokens.get(source)
	var source_base := cell_position(source.x, source.y)
	if animate:
		await _charge(source, FAT_CHARGE_PX, FAT_CHARGE_SEC)
		await _telegraph(target)
		_lunge(source, target, FAT_LUNGE_PX)
		await _wait(LUNGE_SEC)
	# Re-key: the target leaves, everything above moves down a row.
	_tokens.erase(target)
	_token_owner.erase(target)
	_token_goob.erase(target)
	var falling: Array[Sprite2D] = []
	for r in range(target.y + 1, ROWS):
		var cell := Vector2i(target.x, r)
		if not _tokens.has(cell):
			continue
		var below := Vector2i(target.x, r - 1)
		_tokens[below] = _tokens[cell]
		_token_owner[below] = _token_owner[cell]
		_token_goob[below] = _token_goob[cell]
		_tokens.erase(cell)
		_token_owner.erase(cell)
		_token_goob.erase(cell)
		falling.append(_tokens[below])
		set_face(below, &"surprised", REACTION_SEC)
	if not animate:
		drop_sound.emit(&"crunch", side)
		token.queue_free()
		for t in falling:
			t.position.y += CELL
		return
	# Impact: hit-stop on the white target, then it bursts.
	drop_sound.emit(&"crunch", side)
	token.modulate = Color(4.0, 4.0, 4.0)
	shake(SHAKE_BIG)
	await _wait(HIT_STOP_SEC)
	_burst(token.position + Vector2(CELL, CELL) * 0.5, COLOR_DEBRIS[side], DEBRIS_COUNT, DEBRIS_SPEED, DEBRIS_GRAVITY)
	token.queue_free()
	_settle_token(source_token, source_base)
	await _wait(AFTER_IMPACT_SEC)
	if falling.is_empty():
		return
	drop_sound.emit(&"fall", side)
	# Every falling Goob drops the same distance, so they land together.
	var last: Tween
	for t in falling:
		last = _tween()
		_queue_fall(last, t, t.position.y, t.position + Vector2(0, CELL))
	await last.finished
	drop_sound.emit(&"land", side)
	shake(SHAKE_SMALL)


## Popular: winds up, cheers (two hops), and a Vanilla arcs out of it to rest
## on top of the board over `column`. The caller then drops it with
## play_drop(), which starts from that same spot.
func play_summon(source: Vector2i, column: int, side: BoardState.CellOwner) -> void:
	var token: Sprite2D = _tokens.get(source)
	if token == null:
		return
	if not animate:
		drop_sound.emit(&"popular", side)
		return
	await _charge(source)
	var base := cell_position(source.x, source.y)
	drop_sound.emit(&"popular", side)
	var cheer := _tween()
	for i in 2:
		cheer.tween_method(_set_y.bind(token), base.y, base.y - CHEER_PX, CHEER_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cheer.tween_method(_set_y.bind(token), base.y - CHEER_PX, base.y, CHEER_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cheer.finished
	_settle(source)
	# The new Goob pops out of it and arcs over the board.
	var ghost := _make_sprite(_tex(side), "Summoned")
	ghost.material = _outline
	ghost.position = base
	_fx.add_child(ghost)
	_burst(_centre_px(source), COLOR_DEBRIS[side], SPARKLE_COUNT, SPARKLE_SPEED, SPARKLE_GRAVITY)
	var to := Vector2(_column_x(column), TOP_Y)
	var arc := _tween()
	arc.tween_method(_set_arc.bind(ghost, base, to), 0.0, 1.0, SUMMON_ARC_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await arc.finished
	ghost.queue_free()


## A sparkle on the Goob in `cell` (e.g. Popular's Vanilla as it lands).
func sparkle(cell: Vector2i, side: BoardState.CellOwner) -> void:
	if animate and _tokens.has(cell):
		_burst(_centre_px(cell), COLOR_DEBRIS[side], SPARKLE_COUNT, SPARKLE_SPEED, SPARKLE_GRAVITY)


## Plentiful: winds up, then `count` ghost Goobs pop out one by one, hang for
## a beat, and shoot off toward their hand: down to the player's fan, up to
## the hidden opponent.
func play_draw_cue(cell: Vector2i, side: BoardState.CellOwner, count: int) -> void:
	if count <= 0:
		return
	if not animate:
		drop_sound.emit(&"draw_pop", side)
		return
	await _charge(cell)
	_settle(cell)
	var start := cell_position(cell.x, cell.y)
	var away := GHOST_FLY_PX if side == BoardState.CellOwner.PLAYER else -GHOST_FLY_PX
	var tween := _tween().set_parallel()
	for i in count:
		var ghost := _make_sprite(_tex(side), "Ghost")
		ghost.material = _outline
		ghost.position = start
		ghost.modulate.a = 0.0
		_fx.add_child(ghost)
		var t0 := i * GHOST_STAGGER_SEC
		var top := start.y - GHOST_RISE_PX - i * 6
		tween.tween_callback(drop_sound.emit.bind(&"draw_pop", side)).set_delay(t0)
		tween.tween_property(ghost, "modulate:a", 1.0, 0.05).set_delay(t0)
		tween.tween_method(_set_y.bind(ghost), start.y, top, GHOST_RISE_SEC).set_delay(t0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var t1 := t0 + GHOST_RISE_SEC + GHOST_HANG_SEC
		tween.tween_method(_set_y.bind(ghost), top, top + away, GHOST_FLY_SEC).set_delay(t1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FLY_SEC).set_delay(t1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(ghost.queue_free).set_delay(t1 + GHOST_FLY_SEC)
	await tween.finished


## No target (Sean, 2026-11-19): the Goob winds up, but it falters: drops
## back, greys out, shakes its head and puffs a little grey smoke.
func play_fizzle(cell: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return
	if not animate:
		drop_sound.emit(&"fizzle", _token_owner[cell])
		return
	await _charge(cell)
	var base := cell_position(cell.x, cell.y)
	drop_sound.emit(&"fizzle", _token_owner[cell])
	token.position = base
	token.modulate = FIZZLE_MODULATE
	_burst(_centre_px(cell) - Vector2(0, CELL * 0.5), COLOR_SMOKE, SMOKE_COUNT, SMOKE_SPEED, SMOKE_GRAVITY)
	var tween := _tween()
	for px in FIZZLE_PX:
		tween.tween_callback(_set_x.bind(base.x + px, token))
		tween.tween_interval(FIZZLE_STEP_SEC)
	tween.tween_interval(FIZZLE_HOLD_SEC)
	tween.tween_property(token, "modulate", Color.WHITE, 0.2)
	await tween.finished


## Scoring reveal: the Goob at `cell` bounces once (not awaited).
func bounce_cell(cell: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null or not animate:
		return
	var base_y := cell_position(cell.x, cell.y).y
	var tween := _tween()
	tween.tween_method(_set_y.bind(token), base_y, base_y - HOP_PX * 2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_y.bind(token), base_y - HOP_PX * 2, base_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Scoring reveal (Sean, M6c playtest): the Goob at `cell` flips over in
## place with a small hop, to its back (`to_back`) or back to its face. It
## stays on its back (busy) until flipped again. Await to know when it lands.
func flip_cell(cell: Vector2i, to_back: bool) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return
	var side: BoardState.CellOwner = _token_owner[cell]
	var goob: GoobDefinition = _token_goob.get(cell, VANILLA)
	var frames := goob.flip_frames(side)
	var steps: Array[int] = [1, 2, 3, 4]
	if not to_back:
		steps = [5, 6, 7]
	token.set_meta(&"busy", true)
	if animate:
		var base_y := cell_position(cell.x, cell.y).y
		var sec := FLIP_FRAME_SEC * steps.size()
		var hop := _tween()
		hop.tween_method(_set_y.bind(token), base_y, base_y - SCORE_FLIP_HOP_PX, sec * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_method(_set_y.bind(token), base_y - SCORE_FLIP_HOP_PX, base_y, sec * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var spin := _tween()
		for i in steps:
			spin.tween_callback(_set_texture.bind(token, frames[i]))
			spin.tween_interval(FLIP_FRAME_SEC)
		await spin.finished
	if not is_instance_valid(token):
		return
	if to_back:
		token.texture = frames[4]
	else:
		token.texture = goob.still(side)
		token.set_meta(&"busy", false)


## Whether the Goob at `cell` is showing its back (scoring reveal; tests).
func shows_back(cell: Vector2i) -> bool:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return false
	var goob: GoobDefinition = _token_goob.get(cell, VANILLA)
	return token.texture == goob.flip_frames(_token_owner[cell])[4]


## Centre of the Goob in `cell`, in viewport coordinates (logical px).
func cell_center(cell: Vector2i) -> Vector2:
	return _to_global(cell_position(cell.x, cell.y) + Vector2(CELL, CELL) * 0.5)


## Centre of the grid, in viewport coordinates (logical px).
func grid_center() -> Vector2:
	return _to_global(Vector2(GRID_ORIGIN) + Vector2(COLUMNS, ROWS) * CELL * 0.5)


## The opponent's Goob flips up from behind the board's top edge (clipped so
## it never shows through the holes), overshoots and settles on its rest spot.
## The played Goob flips end over end into place on top of the board (back
## first), with a small hop.
func _flip_in(token: Sprite2D, goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	var rest := token.position
	token.set_meta(&"busy", true)
	drop_sound.emit(&"goob_flip", side)
	var frames := goob.pitch_frames(side)
	var spin := _tween()
	for i in frames.size():
		spin.tween_callback(_set_texture.bind(token, frames[(i + 4) % frames.size()]))
		spin.tween_interval(FLIP_IN_SEC / frames.size())
	var hop := _tween()
	hop.tween_method(_set_y.bind(token), rest.y, rest.y - FLIP_IN_HOP_PX, FLIP_IN_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_method(_set_y.bind(token), rest.y - FLIP_IN_HOP_PX, rest.y, FLIP_IN_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await spin.finished
	if not is_instance_valid(token):
		return
	token.position = rest
	token.texture = goob.still(side)
	token.set_meta(&"busy", false)


func _rise_from_behind(token: Sprite2D, goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	var rest := token.position
	token.set_meta(&"busy", true)
	token.reparent(_behind, false)
	token.position = Vector2(rest.x, BEHIND_START_Y) - _behind.position
	drop_sound.emit(&"goob_flip", side)
	var yaw := goob.pitch_frames(side) # every played Goob flips in vertically
	var frames := _tween()
	for i in yaw.size():
		frames.tween_callback(_set_texture.bind(token, yaw[(i + 4) % yaw.size()])) # back first
		frames.tween_interval(BEHIND_RISE_SEC / yaw.size())
	var rise := _tween()
	var top := rest - Vector2(0, BEHIND_RISE_PX) - _behind.position
	rise.tween_property(token, "position", top.round(), BEHIND_RISE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await rise.finished
	if not is_instance_valid(token):
		return
	token.reparent(_goobs, false)
	token.position = rest - Vector2(0, BEHIND_RISE_PX)
	token.texture = goob.still(side)
	token.set_meta(&"busy", false)
	var settle := _tween()
	settle.tween_method(_set_y.bind(token), rest.y - BEHIND_RISE_PX, rest.y, BEHIND_SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await settle.finished


## Floats a `side` Goob on top of the board over `column` (aim feedback). The
## drop that follows starts from the same spot, so the Goob seems to fall from
## here. `goob` picks its art (null = Vanilla).
## `from_global` (viewport px): where the Goob comes from the first time it
## appears (its hand slot, or the finger while dragging): it flips up from
## there to the float spot (M6c), without holding up input.
func show_preview(column: int, side: BoardState.CellOwner, goob: GoobDefinition = null, from_global: Vector2 = Vector2.INF) -> void:
	var art: GoobDefinition = goob if goob else VANILLA
	_preview.texture = art.still(side)
	# Giggles while it floats (aim and timeout reveal), until it drops.
	_preview.set_meta(&"goob", art)
	_preview.set_meta(&"face", &"giggle")
	var spot := Vector2(_column_x(column), TOP_Y)
	if _preview_flight and _preview_flight.is_valid():
		# Moved to another column mid-flight: land there at once.
		_preview_flight.kill()
		_end_preview_flight(art, side)
	_preview.position = spot
	if _preview.visible:
		return
	_preview.visible = true
	if not animate:
		return
	if from_global != Vector2.INF:
		_fly_preview(spot, art, side, from_global)
		return
	_start_bob()


func _start_bob() -> void:
	_preview_tween = create_tween().set_loops()
	_preview_tween.tween_method(_set_y.bind(_preview), TOP_Y, TOP_Y - FLOAT_BOB_PX, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE)
	_preview_tween.tween_method(_set_y.bind(_preview), TOP_Y - FLOAT_BOB_PX, TOP_Y, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE)


func hide_preview() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	if _preview_flight and _preview_flight.is_valid():
		_preview_flight.kill()
	if _preview_frames and _preview_frames.is_valid():
		_preview_frames.kill()
	_preview.set_meta(&"busy", false)
	_preview.visible = false


## The float Goob flips from `from_global` (hand) up to `spot`, spinning once.
func _fly_preview(spot: Vector2, art: GoobDefinition, side: BoardState.CellOwner, from_global: Vector2) -> void:
	var from := ((from_global - global_position - _origin) / _k - Vector2(CELL, CELL) * 0.5).round()
	_preview.position = from
	_preview.set_meta(&"busy", true)
	drop_sound.emit(&"goob_flip", side)
	var yaw := art.yaw_frames(side) # the ghost flips in horizontally
	_preview_flight = _tween()
	_preview_flight.set_parallel()
	var mid := (from + spot) * 0.5 - Vector2(0, HAND_FLIP_ARC_PX)
	_preview_flight.tween_method(func(t: float) -> void:
		var a := from.lerp(mid, t)
		var b := mid.lerp(spot, t)
		_preview.position = a.lerp(b, t).round(), 0.0, 1.0, HAND_FLIP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_preview_frames = _tween()
	for i in yaw.size():
		_preview_frames.tween_callback(_set_texture.bind(_preview, yaw[i]))
		_preview_frames.tween_interval(HAND_FLIP_SEC / yaw.size())
	_preview_flight.chain().tween_callback(func() -> void:
		_end_preview_flight(art, side)
		_start_bob())


func _end_preview_flight(art: GoobDefinition, side: BoardState.CellOwner) -> void:
	if _preview_frames and _preview_frames.is_valid():
		_preview_frames.kill()
	_preview.set_meta(&"busy", false)
	_preview.texture = art.still(side)


func is_preview_visible() -> bool:
	return _preview.visible


## Makes the given cells pulse brighter (winning four).
func highlight_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var token: Sprite2D = _tokens.get(cell)
		if token == null or _highlight_tweens.has(cell):
			continue
		var tween := create_tween().set_loops()
		tween.tween_property(token, "modulate", HIGHLIGHT_MODULATE, 0.35).set_trans(Tween.TRANS_SINE)
		tween.tween_property(token, "modulate", Color(1.15, 1.15, 1.15), 0.35).set_trans(Tween.TRANS_SINE)
		_highlight_tweens[cell] = tween
		token.modulate = HIGHLIGHT_MODULATE


## Scoring, before the multipliers (Sean, 2026-11-20): the scored Goobs get
## the gold winning outline (GDD Art direction), hop together with a sparkle,
## then keep pulsing (highlight_cells). Not awaited.
func recognise_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var token: Sprite2D = _tokens.get(cell)
		if token == null:
			continue
		token.material = _outline_gold
		if not animate:
			continue
		var base_y := cell_position(cell.x, cell.y).y
		var tween := _tween()
		tween.tween_method(_set_y.bind(token), base_y, base_y - RECOGNISE_HOP_PX, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_y.bind(token), base_y - RECOGNISE_HOP_PX, base_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_burst(_centre_px(cell), COLOR_GOLD, SPARKLE_COUNT, SPARKLE_SPEED, SPARKLE_GRAVITY)
	highlight_cells(cells)
	if animate:
		shake(SHAKE_SMALL)


func has_gold_outline(cell: Vector2i) -> bool:
	return _tokens.has(cell) and _tokens[cell].material == _outline_gold


func is_highlighted(cell: Vector2i) -> bool:
	return _highlight_tweens.has(cell)


func clear_highlight() -> void:
	for cell in _highlight_tweens:
		(_highlight_tweens[cell] as Tween).kill()
		if _tokens.has(cell):
			_tokens[cell].modulate = Color.WHITE
	_highlight_tweens.clear()


## Invalid-placement shake: whole game pixels left and right, dying out.
func shake(pattern: Array[int] = SHAKE_INVALID) -> void:
	if not shake_enabled:
		return # Options: Screen shake Off turns every shake off
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for px in pattern:
		_shake_tween.tween_callback(_set_shake.bind(px))
		_shake_tween.tween_interval(0.035)


## A column's slot in viewport coordinates (logical px), from the top of the
## grid to the bottom of the lowest hole row.
func column_rect(column: int) -> Rect2:
	var top_left := Vector2(GRID_ORIGIN.x + column * CELL, GRID_ORIGIN.y)
	return Rect2(_to_global(top_left), Vector2(CELL, ROWS * CELL) * _k)


## The board cell (column, row) under a viewport position, or (-1, -1).
func cell_at(pos: Vector2) -> Vector2i:
	var local := (pos - global_position - _origin) / _k - Vector2(GRID_ORIGIN)
	var column := floori(local.x / CELL)
	var row := ROWS - 1 - floori(local.y / CELL)
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(column, row)


## Logical px per game px for hand Goobs: one whole physical step bigger than
## the board (5× when the board is 4×; GDD Art direction).
func hand_px() -> float:
	return _k * (pixel_scale + 1) / pixel_scale



## Top-left of a Goob sprite sitting in (column, row), in game px.
func cell_position(column: int, row: int) -> Vector2:
	return Vector2(_column_x(column), GRID_ORIGIN.y + (ROWS - 1 - row) * CELL + GOOB_OFFSET.y)


# --- Scale and placement ---------------------------------------------------

## Largest whole number of physical px per game px that fits CANVAS_WIDTH
## across the window; the zone's height follows it.
func _update_scale() -> void:
	var logical := get_viewport_rect().size.x
	var physical := float(get_window().size.x)
	if logical <= 0.0 or physical <= 0.0:
		return
	var ui_scale := physical / logical
	pixel_scale = maxi(1, floori(physical / CANVAS_WIDTH))
	_k = pixel_scale / ui_scale
	_pixel.scale = Vector2(_k, _k)
	custom_minimum_size = Vector2(0.0, ceilf(BOARD_SIZE.y * _k))
	_place_layer()


## Centres the board horizontally in this zone, with its origin on a whole
## physical pixel.
func _place_layer() -> void:
	if _pixel == null:
		return
	var ui_scale := pixel_scale / _k
	var global_x := global_position.x + (size.x - BOARD_SIZE.x * _k) * 0.5
	var global_y := global_position.y
	var snapped := Vector2(roundf(global_x * ui_scale), roundf(global_y * ui_scale)) / ui_scale
	_origin = snapped - global_position
	_pixel.position = _origin + Vector2(_shake_px * _k, 0.0)


func _set_shake(px: int) -> void:
	_shake_px = px
	_pixel.position = _origin + Vector2(_shake_px * _k, 0.0)


func _to_global(game_px: Vector2) -> Vector2:
	return global_position + _origin + game_px * _k


# --- Goobs -----------------------------------------------------------------

func _add_token(cell: Vector2i, side: BoardState.CellOwner, goob: GoobDefinition = null) -> Sprite2D:
	if goob == null:
		goob = VANILLA
	var token := _make_sprite(goob.still(side), "Goob")
	token.material = _outline
	_goobs.add_child(token)
	_tokens[cell] = token
	_token_owner[cell] = side
	_token_goob[cell] = goob
	return token


func _remove_token(cell: Vector2i) -> void:
	if not _tokens.has(cell):
		return
	if _highlight_tweens.has(cell):
		(_highlight_tweens[cell] as Tween).kill()
		_highlight_tweens.erase(cell)
	_tokens[cell].queue_free()
	_tokens.erase(cell)
	_token_owner.erase(cell)
	_token_goob.erase(cell)


## Gravity fall from y `from_y` to `target` (same x), snapped to whole game px,
## then a small bounce.
func _queue_fall(tween: Tween, token: Sprite2D, from_y: float, target: Vector2) -> void:
	var duration := sqrt(2.0 * maxf(1.0, target.y - from_y) / GRAVITY)
	tween.tween_method(_set_y.bind(token), from_y, target.y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_y.bind(token), target.y, target.y - BOUNCE_PX, BOUNCE_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_y.bind(token), target.y - BOUNCE_PX, target.y, BOUNCE_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Rolls along `path` on top of the board. An off-board entry (-1 or COLUMNS)
## is the board's edge: the Goob bumps into it and comes back.
func _queue_roll(tween: Tween, token: Sprite2D, path: Array[int], side: BoardState.CellOwner) -> void:
	var at := path[0]
	for i in range(1, path.size()):
		var next := path[i]
		if next < 0 or next >= COLUMNS:
			var wall := _column_x(at) + signf(next - at) * ROLL_BUMP_PX
			tween.tween_method(_set_x.bind(token), _column_x(at), wall, ROLL_SEC_PER_COLUMN * 0.4)
			tween.tween_callback(drop_sound.emit.bind(&"bounce", side))
			tween.tween_method(_set_x.bind(token), wall, _column_x(at), ROLL_SEC_PER_COLUMN * 0.4)
			continue
		tween.tween_callback(drop_sound.emit.bind(&"roll", side))
		tween.tween_method(_set_x.bind(token), _column_x(at), _column_x(next), ROLL_SEC_PER_COLUMN)
		at = next


## Wind-up: the Goob in `cell` rises `px` and glows, then shivers.
func _charge(cell: Vector2i, px: int = CHARGE_PX, sec: float = CHARGE_SEC) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return
	var base := cell_position(cell.x, cell.y)
	var tween := _tween()
	tween.tween_method(_set_y.bind(token), base.y, base.y - px, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(token, "modulate", CHARGE_GLOW, sec)
	for dx in CHARGE_SHIVER:
		tween.tween_callback(_set_x.bind(base.x + dx, token))
		tween.tween_interval(CHARGE_SHIVER_SEC)
	await tween.finished


## Back to rest (position and colour) after a wind-up.
func _settle(cell: Vector2i) -> void:
	_settle_token(_tokens.get(cell), cell_position(cell.x, cell.y))


func _settle_token(token: Sprite2D, base: Vector2) -> void:
	if token == null or not is_instance_valid(token):
		return
	var tween := _tween().set_parallel()
	tween.tween_method(_set_pos.bind(token), token.position, base, SETTLE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(token, "modulate", Color.WHITE, SETTLE_SEC)


## The random target is marked before the impact: it blinks white.
func _telegraph(cell: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null:
		return
	var tween := _tween()
	for i in TELEGRAPH_BLINKS:
		tween.tween_property(token, "modulate", TELEGRAPH_MODULATE, 0.0)
		tween.tween_interval(TELEGRAPH_SEC)
		tween.tween_property(token, "modulate", Color.WHITE, 0.0)
		tween.tween_interval(TELEGRAPH_SEC)
	await tween.finished


## The Goob in `source` lunges `px` toward `target` (from wherever it is).
func _lunge(source: Vector2i, target: Vector2i, px: int) -> void:
	var token: Sprite2D = _tokens.get(source)
	if token == null:
		return
	var to := cell_position(source.x, source.y) + Vector2(target - source) * Vector2(1, -1) * px
	_tween().tween_method(_set_pos.bind(token), token.position, to, LUNGE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A bright flash that fades back to normal.
func _glow(token: Sprite2D) -> void:
	token.modulate = CHARGE_GLOW
	var tween := _tween()
	tween.tween_property(token, "modulate", Color.WHITE, 0.3)
	await tween.finished


## A play-animation tween at the current speed.
func _tween() -> Tween:
	return create_tween().set_speed_scale(speed_scale)


func _wait(sec: float) -> void:
	var tween := _tween()
	tween.tween_interval(sec)
	await tween.finished


## Centre of the Goob in `cell`, in game px.
func _centre_px(cell: Vector2i) -> Vector2:
	return cell_position(cell.x, cell.y) + Vector2(CELL, CELL) * 0.5


## Pixel bits flying out of `at` (game px), pulled by `gravity`, fading out.
func _burst(at: Vector2, color: Color, count: int, speed: float, gravity: float) -> void:
	for i in count:
		var bit := ColorRect.new()
		bit.color = color if i % 3 else Color.WHITE
		bit.size = Vector2(2, 2)
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(bit)
		var angle := TAU * i / count + randf_range(-0.3, 0.3)
		var velocity := Vector2(cos(angle), sin(angle) - 0.5) * speed * randf_range(0.6, 1.0)
		var tween := bit.create_tween().set_speed_scale(speed_scale)
		tween.tween_method(_set_debris.bind(bit, at, velocity, gravity), 0.0, DEBRIS_SEC, DEBRIS_SEC)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, DEBRIS_SEC).set_ease(Tween.EASE_IN)
		tween.tween_callback(bit.queue_free)


func _set_debris(t: float, bit: ColorRect, from: Vector2, velocity: Vector2, gravity: float) -> void:
	if is_instance_valid(bit):
		bit.position = (from + velocity * t + Vector2(0, 0.5 * gravity * t * t)).round()


## Popular's summon: a parabola from `from` to `to`, peaking SUMMON_ARC_PX up.
func _set_arc(t: float, ghost: Sprite2D, from: Vector2, to: Vector2) -> void:
	if is_instance_valid(ghost):
		ghost.position = (from.lerp(to, t) - Vector2(0, sin(t * PI) * SUMMON_ARC_PX)).round()


func _set_pos(pos: Vector2, token: Sprite2D) -> void:
	if is_instance_valid(token):
		token.position = pos.round()


func _set_texture(token: Sprite2D, texture: Texture2D) -> void:
	if is_instance_valid(token):
		token.texture = texture


## Vanilla still (Popular's summoned Goob, Plentiful's drawn ghosts).
func _tex(side: BoardState.CellOwner) -> Texture2D:
	return VANILLA.still(side)


func _lookup(cell: Vector2i) -> GoobDefinition:
	var goob: GoobDefinition = goob_lookup.call(cell.x, cell.y) if goob_lookup.is_valid() else null
	return goob if goob else VANILLA


func _set_x(x: float, token: Sprite2D) -> void:
	if is_instance_valid(token):
		token.position.x = roundf(x)


func _set_y(y: float, token: Sprite2D) -> void:
	if is_instance_valid(token):
		token.position.y = roundf(y)


func _column_x(column: int) -> float:
	return GRID_ORIGIN.x + column * CELL + GOOB_OFFSET.x


func _make_sprite(texture: Texture2D, node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = false
	return sprite
