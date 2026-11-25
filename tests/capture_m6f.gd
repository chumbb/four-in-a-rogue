extends SceneTree
## Dev tool: screenshots of the M6f looks (special tint, family rings,
## legendary glint, sparkles) on a staged board. Run windowed:
##   godot -s res://tests/capture_m6f.gd -- <out_dir>

const P := BoardState.CellOwner.PLAYER
const O := BoardState.CellOwner.OPPONENT
const G := "res://resources/goobs/%s_goob.tres"

## (type, side) per column, bottom row first.
const ROWS := [
	[["fat", P], ["sinister", O], ["fickle", P], ["generous", O], ["stalwart", P], ["seismic", O], ["bouncy", P]],
	[["lopsided", O], ["spiteful", P], ["popular", O], ["convincing", P], ["vanilla", O], ["tipsy", P], ["plentiful", O]],
]


func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("%s.png" % name))
	print("saved ", name)


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1080, 1920)
	var settings := root.get_node("Settings")
	settings.path = "user://capture_settings.cfg"
	settings.reset()
	root.get_node("GameFlow").player_moves_first = true
	var scenario: Control = load("res://scenes/scenario/scenario.tscn").instantiate()
	root.add_child(scenario)
	current_scene = scenario
	var deadline := Time.get_ticks_msec() + 8000
	while not scenario._input_enabled and Time.get_ticks_msec() < deadline:
		await process_frame
	var loop: TurnLoop = scenario._loop
	for row in ROWS:
		for c in row.size():
			var side: BoardState.CellOwner = row[c][1]
			var r := loop.board.drop(c, side)
			var goob: GoobDefinition = load(G % row[c][0]).duplicate()
			if row[c][0] == "spiteful":
				goob.set_meta(&"armed_by", side)
			loop._cell_goobs[Vector2i(c, r)] = goob
	scenario.get_node("%BoardView").sync_from_board(loop.board)
	var view: BoardView2D = scenario.get_node("%BoardView")
	await create_timer(0.5).timeout
	for row in 2:
		var line := ""
		for c in 7:
			line += "%s " % view.sparkle_at(Vector2i(c, row))
		print(line)
	print("sparks: ", view._sparks.size(), " animate ", view.animate)
	for i in 28:
		await create_timer(0.1).timeout
		await _shot(dir, "m6f_%d" % i)
	# Hands of 6 and 7 (Goobs one pixel step smaller, fan widened if needed).
	for n in [6, 7]:
		var hand: Array[GoobDefinition] = []
		for id in ["fat", "sinister", "fickle", "generous", "stalwart", "seismic", "bouncy"].slice(0, n):
			hand.append(load(G % id))
		loop.player_deck.hand.assign(hand)
		scenario._hand.rebuild(hand)
		await create_timer(0.3).timeout
		await _shot(dir, "hand_%d" % n)
	quit()
