extends Node3D
## Isometric 3D board view. Display + column picking only — owns no game rules.
## The scenario reads BoardState and calls sync_from_board(); clicks come back
## out through column_clicked.
##
## Layout: board lies flat on XZ. Column 0..6 → -x..+x. Row 0 (bottom) is the
## edge nearest the camera (+z), so the grid reads like an upright board.

signal column_clicked(column: int, button_index: int)
signal column_hovered(column: int) ## -1 when the mouse leaves the board

const COLUMNS := BoardState.COLUMNS
const ROWS := BoardState.ROWS
const CELL_SIZE := 1.0
const COLUMN_PICK_LAYER := 1 ## project.godot 3d_physics/layer_1 = "board_columns"

const COLOR_CELL := Color(0.15, 0.2, 0.35)
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.18)
const COLOR_PLAYER := Color(0.9, 0.18, 0.2) ## red (§4.8)
const COLOR_OPPONENT := Color(0.2, 0.42, 0.95) ## blue (§4.8)

@onready var _camera: Camera3D = $Camera3D

## Everything that should shake lives under this pivot; the camera does not.
var _pivot: Node3D
var _tokens: Dictionary = {} ## Vector2i(column, row) -> MeshInstance3D
var _token_owner: Dictionary = {} ## Vector2i -> BoardState.CellOwner
var _hover_bar: MeshInstance3D
var _hovered_column := -1
var _shake_tween: Tween
var _player_mat: StandardMaterial3D
var _opponent_mat: StandardMaterial3D
var _token_mesh: CylinderMesh

var input_enabled := true:
	set(value):
		input_enabled = value
		if not value:
			_set_hover(-1)


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "BoardPivot"
	add_child(_pivot)
	_build_materials()
	_build_cells()
	_build_column_colliders()
	_build_hover_bar()


# --- Public API ------------------------------------------------------------

## Rebuilds tokens so the view matches `board` exactly. Cheap at 42 cells.
## Handles add, remove (destroy) and owner change (flip).
func sync_from_board(board: BoardState) -> void:
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var owner := board.get_owner(column, row)
			var had: BoardState.CellOwner = _token_owner.get(cell, BoardState.CellOwner.EMPTY)
			if owner == had:
				continue
			if _tokens.has(cell):
				_tokens[cell].queue_free()
				_tokens.erase(cell)
				_token_owner.erase(cell)
			if owner != BoardState.CellOwner.EMPTY:
				_spawn_token(cell, owner)
	clear_highlight()


## Raises and brightens the given cells (winning four).
func highlight_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var token: MeshInstance3D = _tokens.get(cell)
		if token == null:
			continue
		var mat := (token.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.5
		token.material_override = mat
		token.scale = Vector3(1.15, 2.0, 1.15)


func clear_highlight() -> void:
	for cell in _tokens:
		var token: MeshInstance3D = _tokens[cell]
		token.material_override = _material_for(_token_owner[cell])
		token.scale = Vector3.ONE


## Invalid-placement shake (§4.6). Shakes the board, not the camera.
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


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick_column(event.position))
	elif event is InputEventMouseButton and event.pressed:
		var column := _pick_column(event.position)
		if column != -1:
			column_clicked.emit(column, event.button_index)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_set_hover(-1)


## Raycast from the camera through the mouse to the column colliders.
func _pick_column(screen_pos: Vector2) -> int:
	if _camera == null:
		return -1
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to, COLUMN_PICK_LAYER)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return int(hit.collider.get_meta("column", -1))


func _set_hover(column: int) -> void:
	if column == _hovered_column:
		return
	_hovered_column = column
	if column == -1:
		_hover_bar.visible = false
	else:
		_hover_bar.visible = true
		_hover_bar.position = Vector3(_column_x(column), 0.06, 0.0)
	column_hovered.emit(column)


# --- Build -----------------------------------------------------------------

func _build_materials() -> void:
	_player_mat = StandardMaterial3D.new()
	_player_mat.albedo_color = COLOR_PLAYER
	_opponent_mat = StandardMaterial3D.new()
	_opponent_mat.albedo_color = COLOR_OPPONENT
	_token_mesh = CylinderMesh.new()
	_token_mesh.top_radius = CELL_SIZE * 0.38
	_token_mesh.bottom_radius = CELL_SIZE * 0.38
	_token_mesh.height = 0.14
	_token_mesh.radial_segments = 32


func _build_cells() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.92, 0.08, CELL_SIZE * 0.92)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CELL
	for row in ROWS:
		for column in COLUMNS:
			var cell := MeshInstance3D.new()
			cell.mesh = mesh
			cell.material_override = mat
			cell.position = grid_to_world(column, row)
			_pivot.add_child(cell)


## One tall box per column on layer board_columns, tagged with its index.
func _build_column_colliders() -> void:
	for column in COLUMNS:
		var body := StaticBody3D.new()
		body.name = "Column%d" % column
		body.collision_layer = 1 << (COLUMN_PICK_LAYER - 1)
		body.collision_mask = 0
		body.set_meta("column", column)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(CELL_SIZE, 0.6, CELL_SIZE * ROWS)
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(_column_x(column), 0.2, 0.0)
		_pivot.add_child(body)


func _build_hover_bar() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.98, 0.02, CELL_SIZE * ROWS)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_HOVER
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_bar = MeshInstance3D.new()
	_hover_bar.mesh = mesh
	_hover_bar.material_override = mat
	_hover_bar.visible = false
	_pivot.add_child(_hover_bar)


func _spawn_token(cell: Vector2i, owner: BoardState.CellOwner) -> void:
	var token := MeshInstance3D.new()
	token.mesh = _token_mesh
	token.material_override = _material_for(owner)
	token.position = grid_to_world(cell.x, cell.y) + Vector3(0.0, 0.11, 0.0)
	_pivot.add_child(token)
	_tokens[cell] = token
	_token_owner[cell] = owner


func _material_for(owner: BoardState.CellOwner) -> StandardMaterial3D:
	return _player_mat if owner == BoardState.CellOwner.PLAYER else _opponent_mat


# --- Coordinates -----------------------------------------------------------

func grid_to_world(column: int, row: int) -> Vector3:
	# Row 0 (bottom) nearest the camera at +z.
	var z := ((ROWS - 1) * 0.5 - row) * CELL_SIZE
	return Vector3(_column_x(column), 0.0, z)


func _column_x(column: int) -> float:
	return (column - (COLUMNS - 1) * 0.5) * CELL_SIZE
