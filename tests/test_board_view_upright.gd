extends SceneTree
## Headless tests for the upright BoardView3D: layout, token facing, and that
## the frame is solid enough for physics Goobs (future work) to fall into.
## Run: godot --headless -s res://tests/test_board_view_upright.gd

var _failures := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view: Node3D = load("res://scenes/board/board_view_3d.tscn").instantiate()
	root.add_child(view)
	await physics_frame
	await physics_frame

	_test_upright_layout(view)
	_test_token_facing(view)
	await _test_physics_disc_settles(view)

	view.queue_free()
	await process_frame
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_upright_layout(view: Node3D) -> void:
	var a: Vector3 = view.grid_to_world(0, 0)
	var right: Vector3 = view.grid_to_world(1, 0)
	var up: Vector3 = view.grid_to_world(0, 1)
	_check(right.x > a.x and is_equal_approx(right.y, a.y), "columns run along +x")
	_check(up.y > a.y and is_equal_approx(up.x, a.x), "rows run up +y (board is upright)")
	_check(is_zero_approx(a.z) and is_zero_approx(up.z), "all cells on the z=0 plane")
	_check(a.y > 0.0, "row 0 sits above the floor")


func _test_token_facing(view: Node3D) -> void:
	var b := BoardState.new()
	b.drop(2, BoardState.CellOwner.PLAYER)
	view.sync_from_board(b)
	var token: MeshInstance3D = view._tokens[Vector2i(2, 0)]
	var face_axis := token.global_transform.basis.y.normalized()
	_check(absf(face_axis.z) > 0.99, "disc face points at the camera (axis %s)" % face_axis)
	view.sync_from_board(BoardState.new())


## A real RigidBody disc dropped into the top of a column must fall, stay in
## its column, and rest where the grid says the cell is. Two discs stack.
func _test_physics_disc_settles(view: Node3D) -> void:
	var column := 3
	var first := _spawn_physics_disc(view, column)
	for i in 180:
		await physics_frame
	var rest0: Vector3 = view.grid_to_world(column, 0)
	_check(first.global_position.distance_to(rest0) < 0.06,
		"disc settles at row 0 (got %s, want %s)" % [first.global_position, rest0])

	var second := _spawn_physics_disc(view, column)
	for i in 180:
		await physics_frame
	var rest1: Vector3 = view.grid_to_world(column, 1)
	_check(second.global_position.distance_to(rest1) < 0.06,
		"second disc stacks at row 1 (got %s, want %s)" % [second.global_position, rest1])
	_check(absf(first.global_position.z) < 0.05 and absf(second.global_position.z) < 0.05,
		"discs stay between front and back panels")
	first.queue_free()
	second.queue_free()


func _spawn_physics_disc(view: Node3D, column: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = view.DISC_RADIUS
	cyl.height = view.DISC_THICKNESS
	shape.shape = cyl
	shape.rotation_degrees = Vector3(90, 0, 0)
	body.add_child(shape)
	body.collision_layer = 1 << 2 # not board_columns, so picking ignores it
	body.collision_mask = (1 << 1) | (1 << 2) # board_frame + other discs
	view.add_child(body)
	var top: Vector3 = view.grid_to_world(column, BoardState.ROWS - 1)
	body.global_position = top + Vector3(0, view.ROW_PITCH * 1.5, 0)
	return body
