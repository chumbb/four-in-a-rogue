extends Node3D
## Upright 3D Connect 4 board. Display only — owns no game rules or input.
## The scenario reads BoardState and calls sync_from_board(), and hit-tests
## touches against column_rect(). Replaced by the 2D pixel board in M3.6.
##
## Layout: the board stands on the XY plane like the real game. Column 0..6 →
## -x..+x, row 0 is the bottom (just above the floor at y = 0), discs sit on
## z = 0 between a front panel (with holes) and a back panel. The camera looks
## straight on, so each column projects to an axis-aligned screen rectangle.
##
## The frame (floor, dividers, panels) is solid on the board_frame physics
## layer, so RigidBody Goobs can fall into the columns later. Row pitch equals
## disc diameter, so physically stacked discs land exactly on grid_to_world().

const COLUMNS := BoardState.COLUMNS
const ROWS := BoardState.ROWS

const FRAME_LAYER := 2 ## project.godot 3d_physics/layer_2 = "board_frame"

const COLUMN_PITCH := 1.0
const DISC_RADIUS := 0.45
const DISC_THICKNESS := 0.2
const ROW_PITCH := DISC_RADIUS * 2.0 ## discs touch when stacked
const HOLE_RADIUS := 0.38 ## smaller than the disc, so the panel holds it in
const SLOT_DEPTH := 0.24 ## gap between front and back panel
const PANEL_THICKNESS := 0.08
const DIVIDER_THICKNESS := 0.06
const FLOOR_HEIGHT := 0.2
const FRAME_MARGIN := 0.2

## Region the camera keeps in view (world units, centred on the camera):
## the board plus its frame. Horizontal FOV when the zone is narrow.
const VIEW_WIDTH := 7.8
const VIEW_HEIGHT := 6.07
const VIEW_FOV := 30.0

const COLOR_FRAME := Color(0.15, 0.22, 0.42)
const COLOR_PLAYER := Color(0.2, 0.42, 0.95) ## blue — player
const COLOR_OPPONENT := Color(0.9, 0.18, 0.2) ## red — enemy (red is the bad guy)

@onready var _camera: Camera3D = $Camera3D

## Everything that should shake lives under this pivot; the camera does not.
var _pivot: Node3D
var _tokens: Dictionary = {} ## Vector2i(column, row) -> MeshInstance3D
var _token_owner: Dictionary = {} ## Vector2i -> BoardState.CellOwner
var _shake_tween: Tween
var _frame_mat: StandardMaterial3D
var _player_mat: StandardMaterial3D
var _opponent_mat: StandardMaterial3D
var _disc_mesh: CylinderMesh

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "BoardPivot"
	add_child(_pivot)
	_build_materials()
	_build_frame()
	_build_front_panel()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


# --- Public API ------------------------------------------------------------

## Rebuilds tokens so the view matches `board` exactly. Cheap at 42 cells.
## Handles add, remove (destroy) and owner change (flip).
func sync_from_board(board: BoardState) -> void:
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var side := board.get_owner(column, row)
			var had: BoardState.CellOwner = _token_owner.get(cell, BoardState.CellOwner.EMPTY)
			if side == had:
				continue
			if _tokens.has(cell):
				_tokens[cell].queue_free()
				_tokens.erase(cell)
				_token_owner.erase(cell)
			if side != BoardState.CellOwner.EMPTY:
				_spawn_token(cell, side)
	clear_highlight()


## Makes the given cells glow (winning four).
func highlight_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var token: MeshInstance3D = _tokens.get(cell)
		if token == null:
			continue
		var mat := (token.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.0
		token.material_override = mat


func clear_highlight() -> void:
	for cell in _tokens:
		var token: MeshInstance3D = _tokens[cell]
		token.material_override = _material_for(_token_owner[cell])


## Invalid-placement shake. Shakes the board, not the camera.
func shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_pivot.position = Vector3.ZERO
	_shake_tween = create_tween()
	var amp := 0.18
	for i in 6:
		var dir := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(_pivot, "position:x", amp * dir, 0.035)
		amp *= 0.75
	_shake_tween.tween_property(_pivot, "position:x", 0.0, 0.035)


## Screen rectangle (this view's viewport pixels) of a column's slot, from the
## floor to the top row. Valid because the camera faces the board head-on.
func column_rect(column: int) -> Rect2:
	var bottom_left := Vector3(_column_x(column) - COLUMN_PITCH * 0.5, 0.0, 0.0)
	var top_right := Vector3(_column_x(column) + COLUMN_PITCH * 0.5, _board_height(), 0.0)
	var a := _camera.unproject_position(bottom_left)
	var b := _camera.unproject_position(top_right)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## Screen y (this view's viewport pixels) of the underside of the board's
## floor: where it rests on the table.
func floor_bottom_y() -> float:
	return _camera.unproject_position(Vector3(0.0, -FLOOR_HEIGHT, 0.0)).y


## Keeps the whole board in view whatever the zone's shape: fit the width in
## tall zones (portrait phones), the height in wide ones.
func _fit_camera() -> void:
	var size := Vector2(get_viewport().size)
	if size.y <= 0.0:
		return
	if size.x / size.y <= VIEW_WIDTH / VIEW_HEIGHT:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = VIEW_FOV
	else:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		var half := tan(deg_to_rad(VIEW_FOV * 0.5)) * VIEW_HEIGHT / VIEW_WIDTH
		_camera.fov = rad_to_deg(atan(half)) * 2.0


# --- Build -----------------------------------------------------------------

func _build_materials() -> void:
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.albedo_color = COLOR_FRAME
	_frame_mat.roughness = 0.6
	_player_mat = StandardMaterial3D.new()
	_player_mat.albedo_color = COLOR_PLAYER
	_opponent_mat = StandardMaterial3D.new()
	_opponent_mat.albedo_color = COLOR_OPPONENT
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = DISC_RADIUS
	_disc_mesh.bottom_radius = DISC_RADIUS
	_disc_mesh.height = DISC_THICKNESS
	_disc_mesh.radial_segments = 32


## Floor, back panel, column dividers and feet — one static body on the
## board_frame layer. The front panel (with holes) is built separately.
func _build_frame() -> void:
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	frame.collision_layer = _layer_bit(FRAME_LAYER)
	frame.collision_mask = 0
	_pivot.add_child(frame)

	var width := _board_width() + FRAME_MARGIN * 2.0
	var height := _board_height()
	var panel_z := SLOT_DEPTH * 0.5 + PANEL_THICKNESS * 0.5

	# Floor: top face at y = 0, spans the slot.
	_add_box(frame, Vector3(width, FLOOR_HEIGHT, SLOT_DEPTH + PANEL_THICKNESS * 2.0),
		Vector3(0.0, -FLOOR_HEIGHT * 0.5, 0.0), true)
	# Back panel.
	var panel_size := Vector3(width, height + FLOOR_HEIGHT + FRAME_MARGIN, PANEL_THICKNESS)
	var panel_y := (height - FLOOR_HEIGHT + FRAME_MARGIN) * 0.5
	_add_box(frame, panel_size, Vector3(0.0, panel_y, -panel_z), true)
	# Front panel collision: a plain box. Discs are bigger than the holes, so
	# they only ever touch the flat face — and a box is far more stable for
	# physics than the holed CSG mesh (which is visual only).
	var front := CollisionShape3D.new()
	var front_box := BoxShape3D.new()
	front_box.size = panel_size
	front.shape = front_box
	front.position = Vector3(0.0, panel_y, panel_z)
	frame.add_child(front)
	# Dividers between (and at the edges of) the columns.
	for i in COLUMNS + 1:
		var x := (i - COLUMNS * 0.5) * COLUMN_PITCH
		_add_box(frame, Vector3(DIVIDER_THICKNESS, height, SLOT_DEPTH),
			Vector3(x, height * 0.5, 0.0), true)
	# Feet (visual only), like the real stand.
	for sx in [-1.0, 1.0]:
		_add_box(frame, Vector3(0.3, 0.5, 1.6),
			Vector3(sx * (width * 0.5 - 0.15), -FLOOR_HEIGHT - 0.25, 0.0), false)


## Front panel with one hole per cell (CSG), visual only — its collision is a
## box in _build_frame(). Holes are smaller than the discs.
func _build_front_panel() -> void:
	var width := _board_width() + FRAME_MARGIN * 2.0
	var height := _board_height()
	var panel := CSGBox3D.new()
	panel.name = "FrontPanel"
	panel.size = Vector3(width, height + FLOOR_HEIGHT + FRAME_MARGIN, PANEL_THICKNESS)
	panel.position = Vector3(0.0, (height - FLOOR_HEIGHT + FRAME_MARGIN) * 0.5,
		SLOT_DEPTH * 0.5 + PANEL_THICKNESS * 0.5)
	panel.material = _frame_mat
	# Don't shade the discs behind it.
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(panel)
	for row in ROWS:
		for column in COLUMNS:
			var hole := CSGCylinder3D.new()
			hole.operation = CSGShape3D.OPERATION_SUBTRACTION
			hole.radius = HOLE_RADIUS
			hole.height = PANEL_THICKNESS * 2.0
			hole.sides = 32
			hole.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			# Hole position is relative to the panel's centre.
			hole.position = grid_to_world(column, row) - panel.position + Vector3(0.0, 0.0, panel.position.z)
			panel.add_child(hole)


func _spawn_token(cell: Vector2i, side: BoardState.CellOwner) -> void:
	var token := MeshInstance3D.new()
	token.mesh = _disc_mesh
	token.material_override = _material_for(side)
	token.rotation_degrees = Vector3(90.0, 0.0, 0.0) # face the camera (+z)
	token.position = grid_to_world(cell.x, cell.y)
	_pivot.add_child(token)
	_tokens[cell] = token
	_token_owner[cell] = side


func _material_for(side: BoardState.CellOwner) -> StandardMaterial3D:
	return _player_mat if side == BoardState.CellOwner.PLAYER else _opponent_mat


## Adds a box mesh (+ collision shape if `solid`) to `body`.
func _add_box(body: StaticBody3D, size: Vector3, pos: Vector3, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _frame_mat
	inst.position = pos
	body.add_child(inst)
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = pos
		body.add_child(shape)


# --- Coordinates -----------------------------------------------------------

## Centre of a cell's disc. Row 0 rests on the floor (y = 0).
func grid_to_world(column: int, row: int) -> Vector3:
	return Vector3(_column_x(column), DISC_RADIUS + row * ROW_PITCH, 0.0)


func _column_x(column: int) -> float:
	return (column - (COLUMNS - 1) * 0.5) * COLUMN_PITCH


func _board_width() -> float:
	return COLUMNS * COLUMN_PITCH


func _board_height() -> float:
	return ROWS * ROW_PITCH


static func _layer_bit(layer: int) -> int:
	return 1 << (layer - 1)
