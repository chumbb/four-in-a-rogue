extends Node3D
## Isometric 3D board placeholder — 2D-style grid of quads until art lands.


const COLUMNS := 7
const ROWS := 6
const CELL_SIZE := 1.0


func _ready() -> void:
	_build_placeholder_grid()


func _build_placeholder_grid() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.92, 0.08, CELL_SIZE * 0.92)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.2, 0.35)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat

	for row in ROWS:
		for col in COLUMNS:
			var cell := mesh_inst.duplicate() as MeshInstance3D
			cell.position = _grid_to_world(col, row)
			add_child(cell)


func _grid_to_world(column: int, row: int) -> Vector3:
	var x := (column - (COLUMNS - 1) * 0.5) * CELL_SIZE
	var z := (row - (ROWS - 1) * 0.5) * CELL_SIZE
	return Vector3(x, 0.0, z)
