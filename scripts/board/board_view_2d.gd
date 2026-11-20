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
## Layers back to front: board back → Goobs → board front (holes). Goobs above
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

const TEX_BACK := preload("res://assets/board/board_back.png")
const TEX_FRONT := preload("res://assets/board/board_front.png")
const TEX_PLAYER := preload("res://assets/goobs/vanilla/blue_yaw/frame_00.png")
const TEX_OPPONENT := preload("res://assets/goobs/vanilla/red_yaw/frame_00.png")
const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")

## M5 impact animations (placeholders until each type has its own art).
## Convincing flip: the target spins about its vertical axis (baked yaw frames)
## and comes round in the new colour.
const YAW_DIR := {
	BoardState.CellOwner.PLAYER: "res://assets/goobs/vanilla/blue_yaw/frame_%02d.png",
	BoardState.CellOwner.OPPONENT: "res://assets/goobs/vanilla/red_yaw/frame_%02d.png",
}
const FLIP_OLD_FRAMES: Array[int] = [0, 1, 2] ## face → edge-on
const FLIP_NEW_FRAMES: Array[int] = [6, 7, 0] ## edge-on → face
const FLIP_FRAME_SEC := 0.06
const HOP_PX := 4
const HOP_SEC := 0.16
## The effect's Goob leans toward its target before it acts.
const NUDGE_PX := 3
const NUDGE_SEC := 0.12
## Fat destroy: the target flashes white, then bursts into pixel debris.
const DESTROY_FLASH_SEC := 0.1
const DEBRIS_COUNT := 8
const DEBRIS_SEC := 0.4
const DEBRIS_GRAVITY := 400.0
const COLOR_DEBRIS := {
	BoardState.CellOwner.PLAYER: Color("4d9be6"),
	BoardState.CellOwner.OPPONENT: Color("e83b3b"),
}
## Plentiful: ghost Goobs rise off it and fade, one per Goob drawn (visible
## even though the opponent's hand is hidden).
const GHOST_RISE_PX := 24
const GHOST_SEC := 0.4
const GHOST_STAGGER_SEC := 0.12
## Fizzle (no target, Sean 2026-11-19): a little shake while it greys out.
const FIZZLE_PX: Array[int] = [1, -1, 1, -1, 0]
const FIZZLE_STEP_SEC := 0.05
const FIZZLE_MODULATE := Color(0.6, 0.6, 0.65)

## Sound cues during play_drop(): &"rest" (on top of the board), &"roll" (each
## column rolled over), &"bounce" (off the edge), &"fall". The landing itself
## is the caller's (play_drop() returns then). Effects (M5) add &"flip",
## &"crunch", &"popular", &"draw_pop", &"fizzle", and &"fall" + &"land" for
## Goobs falling after a destroy.
signal drop_sound(kind: StringName, side: BoardState.CellOwner)

## Tests set false: drops land at once and play_drop() returns immediately.
var animate := true

## Physical pixels per game pixel (whole number) and logical px per game px.
var pixel_scale := 1
var _k := 1.0

var _pixel: Node2D
var _goobs: Node2D
var _origin := Vector2.ZERO ## _pixel position without shake (local, logical px)
var _shake_px := 0
var _shake_tween: Tween
var _tokens: Dictionary = {} ## Vector2i(column, row) -> Sprite2D
var _token_owner: Dictionary = {} ## Vector2i -> BoardState.CellOwner
var _highlight_tweens: Dictionary = {} ## Vector2i -> Tween
var _outline: ShaderMaterial
var _preview: Sprite2D
var _preview_tween: Tween
var _yaw: Dictionary = {} ## side -> Array of the 8 yaw frame textures


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_pixel = Node2D.new()
	_pixel.name = "PixelLayer"
	_pixel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_pixel)
	_pixel.add_child(_make_sprite(TEX_BACK, "Back"))
	_goobs = Node2D.new()
	_goobs.name = "Goobs"
	_pixel.add_child(_goobs)
	_preview = _make_sprite(TEX_PLAYER, "Preview")
	_preview.material = _outline
	_preview.visible = false
	_goobs.add_child(_preview)
	_pixel.add_child(_make_sprite(TEX_FRONT, "Front"))
	for side: BoardState.CellOwner in YAW_DIR:
		var frames: Array[Texture2D] = []
		for i in 8:
			frames.append(load(YAW_DIR[side] % i) as Texture2D)
		_yaw[side] = frames
	get_viewport().size_changed.connect(_update_scale)
	item_rect_changed.connect(_place_layer)
	_update_scale()


# --- Public API ------------------------------------------------------------

## Rebuilds Goobs so the view matches `board` exactly. Cheap at 42 cells.
## Handles add, remove (destroy) and owner change (flip).
func sync_from_board(board: BoardState) -> void:
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var side := board.get_owner(column, row)
			var had: BoardState.CellOwner = _token_owner.get(cell, BoardState.CellOwner.EMPTY)
			if side == had:
				continue
			_remove_token(cell)
			if side != BoardState.CellOwner.EMPTY:
				_add_token(cell, side).position = cell_position(column, row)
	clear_highlight()


## Drops a new Goob into (column, row): it appears on top of the board over
## its column, pauses, then falls in. With a `roll_path` (timeout into a full
## column) it appears over roll_path[0], rolls along the path and falls into
## its last column. An off-board entry in the path (-1 or COLUMNS) is a bounce
## off that edge. The Goob counts as on the board at once, so a sync during
## the animation does not duplicate it. Await this to know when it has landed.
func play_drop(column: int, row: int, side: BoardState.CellOwner, roll_path: Array[int] = []) -> void:
	hide_preview()
	var cell := Vector2i(column, row)
	_remove_token(cell)
	var token := _add_token(cell, side)
	var target := cell_position(column, row)
	if not animate:
		token.position = target
		return
	var start := roll_path[0] if roll_path.size() > 1 else column
	token.position = Vector2(_column_x(start), TOP_Y)
	var tween := create_tween()
	tween.tween_callback(drop_sound.emit.bind(&"rest", side))
	tween.tween_interval(TOP_PAUSE_SEC)
	if roll_path.size() > 1:
		_queue_roll(tween, token, roll_path, side)
	tween.tween_callback(drop_sound.emit.bind(&"fall", side))
	_queue_fall(tween, token, TOP_Y, target)
	await tween.finished


# --- Effects (M5) -------------------------------------------------------------
# Each awaits its animation; with animate off it only updates the view state.

## Convincing: the Goob at `source` leans toward `target`, which spins round
## into `side`'s colour.
func play_flip(source: Vector2i, target: Vector2i, side: BoardState.CellOwner) -> void:
	var token: Sprite2D = _tokens.get(target)
	if token == null:
		return
	var old: BoardState.CellOwner = _token_owner[target]
	_token_owner[target] = side
	if not animate:
		token.texture = _tex(side)
		return
	await _nudge(source, target)
	drop_sound.emit(&"flip", side)
	var base_y := cell_position(target.x, target.y).y
	var hop := create_tween()
	hop.tween_method(_set_y.bind(token), base_y, base_y - HOP_PX, FLIP_FRAME_SEC * 3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_method(_set_y.bind(token), base_y - HOP_PX, base_y, FLIP_FRAME_SEC * 3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var frames := create_tween()
	for i in FLIP_OLD_FRAMES:
		frames.tween_callback(_set_texture.bind(token, (_yaw[old] as Array)[i]))
		frames.tween_interval(FLIP_FRAME_SEC)
	for i in FLIP_NEW_FRAMES:
		frames.tween_callback(_set_texture.bind(token, (_yaw[side] as Array)[i]))
		frames.tween_interval(FLIP_FRAME_SEC)
	await frames.finished


## Fat: the Goob at `source` leans toward `target`, which flashes and bursts;
## the Goobs above it fall one row (BoardState.destroy_cell).
func play_destroy(source: Vector2i, target: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(target)
	if token == null:
		return
	var side: BoardState.CellOwner = _token_owner[target]
	if animate:
		await _nudge(source, target)
	# Re-key: the target leaves, everything above moves down a row.
	_tokens.erase(target)
	_token_owner.erase(target)
	var falling: Array[Sprite2D] = []
	for r in range(target.y + 1, ROWS):
		var cell := Vector2i(target.x, r)
		if not _tokens.has(cell):
			continue
		var below := Vector2i(target.x, r - 1)
		_tokens[below] = _tokens[cell]
		_token_owner[below] = _token_owner[cell]
		_tokens.erase(cell)
		_token_owner.erase(cell)
		falling.append(_tokens[below])
	if not animate:
		token.queue_free()
		for t in falling:
			t.position.y += CELL
		return
	drop_sound.emit(&"crunch", side)
	token.modulate = Color(4.0, 4.0, 4.0)
	var flash := create_tween()
	flash.tween_interval(DESTROY_FLASH_SEC)
	await flash.finished
	_burst(token.position + Vector2(CELL, CELL) * 0.5, COLOR_DEBRIS[side])
	token.queue_free()
	if falling.is_empty():
		var wait := create_tween()
		wait.tween_interval(DEBRIS_SEC * 0.5)
		await wait.finished
		return
	drop_sound.emit(&"fall", side)
	# Every falling Goob drops the same distance, so they land together.
	var last: Tween
	for t in falling:
		last = create_tween()
		_queue_fall(last, t, t.position.y, t.position + Vector2(0, CELL))
	await last.finished
	drop_sound.emit(&"land", side)


## Popular / Plentiful cue: the Goob at `cell` hops, with `sound`.
func play_hop(cell: Vector2i, sound: StringName) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null or not animate:
		return
	drop_sound.emit(sound, _token_owner[cell])
	var base_y := cell_position(cell.x, cell.y).y
	var tween := create_tween()
	tween.tween_method(_set_y.bind(token), base_y, base_y - HOP_PX, HOP_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_y.bind(token), base_y - HOP_PX, base_y, HOP_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


## Plentiful: `count` ghost Goobs rise off `cell` and fade, one pop each.
func play_draw_cue(cell: Vector2i, side: BoardState.CellOwner, count: int) -> void:
	if not animate or count <= 0:
		return
	var start := cell_position(cell.x, cell.y)
	var tween := create_tween().set_parallel()
	for i in count:
		var ghost := _make_sprite(_tex(side), "Ghost")
		ghost.position = start
		ghost.modulate.a = 0.0
		_goobs.add_child(ghost)
		var delay := i * GHOST_STAGGER_SEC
		tween.tween_callback(drop_sound.emit.bind(&"draw_pop", side)).set_delay(delay)
		tween.tween_property(ghost, "modulate:a", 0.8, 0.05).set_delay(delay)
		tween.tween_method(_set_y.bind(ghost), start.y, start.y - GHOST_RISE_PX, GHOST_SEC).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "modulate:a", 0.0, GHOST_SEC * 0.6).set_delay(delay + GHOST_SEC * 0.4)
		tween.tween_callback(ghost.queue_free).set_delay(delay + GHOST_SEC)
	await tween.finished


## No target (Sean, 2026-11-19): the Goob at `cell` shakes a little and greys
## out for a moment.
func play_fizzle(cell: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null or not animate:
		return
	drop_sound.emit(&"fizzle", _token_owner[cell])
	var base_x := cell_position(cell.x, cell.y).x
	token.modulate = FIZZLE_MODULATE
	var tween := create_tween()
	for px in FIZZLE_PX:
		tween.tween_callback(_set_x.bind(base_x + px, token))
		tween.tween_interval(FIZZLE_STEP_SEC)
	tween.tween_property(token, "modulate", Color.WHITE, 0.15)
	await tween.finished


## Scoring reveal: the Goob at `cell` bounces once (not awaited).
func bounce_cell(cell: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(cell)
	if token == null or not animate:
		return
	var base_y := cell_position(cell.x, cell.y).y
	var tween := create_tween()
	tween.tween_method(_set_y.bind(token), base_y, base_y - HOP_PX * 2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_y.bind(token), base_y - HOP_PX * 2, base_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Centre of the Goob in `cell`, in viewport coordinates (logical px).
func cell_center(cell: Vector2i) -> Vector2:
	return _to_global(cell_position(cell.x, cell.y) + Vector2(CELL, CELL) * 0.5)


## Centre of the grid, in viewport coordinates (logical px).
func grid_center() -> Vector2:
	return _to_global(Vector2(GRID_ORIGIN) + Vector2(COLUMNS, ROWS) * CELL * 0.5)


## Floats a `side` Goob on top of the board over `column` (aim feedback). The
## drop that follows starts from the same spot, so the Goob seems to fall from
## here.
func show_preview(column: int, side: BoardState.CellOwner) -> void:
	_preview.texture = TEX_PLAYER if side == BoardState.CellOwner.PLAYER else TEX_OPPONENT
	_preview.position = Vector2(_column_x(column), TOP_Y)
	if _preview.visible:
		return
	_preview.visible = true
	if not animate:
		return
	_preview_tween = create_tween().set_loops()
	_preview_tween.tween_method(_set_y.bind(_preview), TOP_Y, TOP_Y - FLOAT_BOB_PX, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE)
	_preview_tween.tween_method(_set_y.bind(_preview), TOP_Y - FLOAT_BOB_PX, TOP_Y, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE)


func hide_preview() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview.visible = false


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


func is_highlighted(cell: Vector2i) -> bool:
	return _highlight_tweens.has(cell)


func clear_highlight() -> void:
	for cell in _highlight_tweens:
		(_highlight_tweens[cell] as Tween).kill()
		if _tokens.has(cell):
			_tokens[cell].modulate = Color.WHITE
	_highlight_tweens.clear()


## Invalid-placement shake: whole game pixels left and right, dying out.
func shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for px in [3, -3, 2, -2, 1, -1, 0]:
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

func _add_token(cell: Vector2i, side: BoardState.CellOwner) -> Sprite2D:
	var token := _make_sprite(TEX_PLAYER if side == BoardState.CellOwner.PLAYER else TEX_OPPONENT, "Goob")
	token.material = _outline
	_goobs.add_child(token)
	_tokens[cell] = token
	_token_owner[cell] = side
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


## The Goob at `source` leans NUDGE_PX toward `target` and back.
func _nudge(source: Vector2i, target: Vector2i) -> void:
	var token: Sprite2D = _tokens.get(source)
	if token == null:
		return
	var base := cell_position(source.x, source.y)
	var lean := base + Vector2(target - source) * Vector2(1, -1) * NUDGE_PX
	var tween := create_tween()
	tween.tween_method(_set_pos.bind(token), base, lean, NUDGE_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_pos.bind(token), lean, base, NUDGE_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


## Pixel debris flying out of `at` (game px) under gravity, then gone.
func _burst(at: Vector2, color: Color) -> void:
	for i in DEBRIS_COUNT:
		var bit := ColorRect.new()
		bit.color = color if i % 2 == 0 else Color.WHITE
		bit.size = Vector2(2, 2)
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_goobs.add_child(bit)
		var angle := TAU * i / DEBRIS_COUNT + randf_range(-0.3, 0.3)
		var velocity := Vector2(cos(angle), sin(angle) - 0.6) * randf_range(60.0, 110.0)
		var tween := bit.create_tween()
		tween.tween_method(_set_debris.bind(bit, at, velocity), 0.0, DEBRIS_SEC, DEBRIS_SEC)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, DEBRIS_SEC).set_ease(Tween.EASE_IN)
		tween.tween_callback(bit.queue_free)


func _set_debris(t: float, bit: ColorRect, from: Vector2, velocity: Vector2) -> void:
	if is_instance_valid(bit):
		bit.position = (from + velocity * t + Vector2(0, 0.5 * DEBRIS_GRAVITY * t * t)).round()


func _set_pos(pos: Vector2, token: Sprite2D) -> void:
	if is_instance_valid(token):
		token.position = pos.round()


func _set_texture(token: Sprite2D, texture: Texture2D) -> void:
	if is_instance_valid(token):
		token.texture = texture


func _tex(side: BoardState.CellOwner) -> Texture2D:
	return TEX_PLAYER if side == BoardState.CellOwner.PLAYER else TEX_OPPONENT


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
