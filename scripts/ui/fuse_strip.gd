class_name FuseStrip
extends Control
## Low-time warning (slice §2B; Art B fuse, M6c): for the last FUSE_SEC of the
## player's turn a fuse burns along the 24 px strip between the board and the
## hand, left to right; the burning end reaching the right end = timeout.
## Drawn on the board's game-pixel grid (UI pixel unit = one board game pixel).
## Display only: the scenario feeds set_left() each frame.

const FUSE_SEC := 10.0
const ROPE := preload("res://assets/ui/fuse_rope.png") ## 8×5 tile
const BURNT := preload("res://assets/ui/fuse_burnt.png") ## 8×5 tile
const SPARK := preload("res://assets/ui/fuse_spark.png") ## 4 × 11×11 frames
const SPARK_FRAMES := 4
const SPARK_FRAME_SEC := 0.08
const STRIP_PX := 9 ## game px tall (24 px on the 720 base at 2.67×)
const SIDE_INSET_PX := 6 ## game px from the screen edges

## Logical px per game px (the board's).
var _k := 1.0
## Fraction of the fuse still unburnt, 1 → 0.
var _left := 1.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


## Places the strip centred on `centre_y` across `width` logical px of
## screen, on the board's pixel grid (`k` logical px per game px).
func place(centre_y: float, width: float, k: float) -> void:
	_k = k
	var inset := SIDE_INSET_PX * k
	position = Vector2(inset, centre_y - STRIP_PX * k * 0.5)
	size = Vector2(width - inset * 2.0, STRIP_PX * k)
	queue_redraw()


## Seconds left in the turn: shows the fuse only for the last FUSE_SEC.
func set_seconds_left(seconds: float) -> void:
	var on := seconds <= FUSE_SEC and seconds >= 0.0
	visible = on
	if on:
		_left = clampf(seconds / FUSE_SEC, 0.0, 1.0)
		queue_redraw()


func fraction_left() -> float:
	return _left


func _process(delta: float) -> void:
	if visible:
		_clock += delta
		queue_redraw()


func _draw() -> void:
	var width_px := floorf(size.x / _k)
	var burn_px := floorf(width_px * (1.0 - _left))
	var rope_y := floorf((STRIP_PX - ROPE.get_height()) * 0.5)
	var tile := float(ROPE.get_width())
	var x := 0.0
	while x < width_px:
		var w := minf(tile, width_px - x)
		var texture := BURNT if x + w <= burn_px else ROPE
		if x < burn_px and x + w > burn_px:
			# Split tile: burnt part, then rope part.
			var cut := burn_px - x
			_tile(BURNT, x, rope_y, cut, 0.0)
			_tile(ROPE, burn_px, rope_y, w - cut, cut)
		else:
			_tile(texture, x, rope_y, w, 0.0)
		x += tile
	var frame := int(_clock / SPARK_FRAME_SEC) % SPARK_FRAMES
	var fw := float(SPARK.get_width()) / SPARK_FRAMES
	var spark_pos := Vector2(burn_px - floorf(fw * 0.5), floorf((STRIP_PX - SPARK.get_height()) * 0.5))
	draw_texture_rect_region(SPARK, Rect2(spark_pos * _k, Vector2(fw, SPARK.get_height()) * _k), Rect2(fw * frame, 0, fw, SPARK.get_height()))


## Draws `w` game px of `texture` at game px (x, y), from `src_x` in the tile.
func _tile(texture: Texture2D, x: float, y: float, w: float, src_x: float) -> void:
	if w <= 0.0:
		return
	var h := float(texture.get_height())
	draw_texture_rect_region(texture, Rect2(Vector2(x, y) * _k, Vector2(w, h) * _k), Rect2(src_x, 0, w, h))
