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
const BOARD_SIZE := Vector2i(240, 216) ## board art incl. feet
const PANEL_HEIGHT := 208 ## board art without the feet
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

const TEX_BACK := preload("res://assets/board/board_back.png")
const TEX_FRONT := preload("res://assets/board/board_front.png")
const TEX_PLAYER := preload("res://assets/goobs/vanilla/blue_yaw/frame_00.png")
const TEX_OPPONENT := preload("res://assets/goobs/vanilla/red_yaw/frame_00.png")
const OUTLINE_SHADER := preload("res://shaders/pixel_outline.gdshader")

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
	_pixel.add_child(_make_sprite(TEX_FRONT, "Front"))
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
	tween.tween_interval(TOP_PAUSE_SEC)
	if roll_path.size() > 1:
		_queue_roll(tween, token, roll_path)
	_queue_fall(tween, token, TOP_Y, target)
	await tween.finished


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


## Viewport y (logical px) of the bottom of the board panel: where its feet
## stand on the table.
func floor_bottom_y() -> float:
	return _to_global(Vector2(0, PANEL_HEIGHT)).y


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
func _queue_roll(tween: Tween, token: Sprite2D, path: Array[int]) -> void:
	var at := path[0]
	for i in range(1, path.size()):
		var next := path[i]
		if next < 0 or next >= COLUMNS:
			var wall := _column_x(at) + signf(next - at) * ROLL_BUMP_PX
			tween.tween_method(_set_x.bind(token), _column_x(at), wall, ROLL_SEC_PER_COLUMN * 0.4)
			tween.tween_method(_set_x.bind(token), wall, _column_x(at), ROLL_SEC_PER_COLUMN * 0.4)
			continue
		tween.tween_method(_set_x.bind(token), _column_x(at), _column_x(next), ROLL_SEC_PER_COLUMN)
		at = next


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
