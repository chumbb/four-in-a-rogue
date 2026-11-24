class_name TurnLoop
extends RefCounted
## Alternating-turn rules for one scenario. Owns the BoardState and both
## decks; no rendering.
##
## Each turn starts by drawing 1 Goob (if the deck has one and the hand has
## room), then the side plays exactly 1 Goob from its hand (slice §4). A side
## with no Goobs left (hand + deck) takes no more turns; the other side plays
## on. Neither side able to play, with no four, is a draw (stalemate).
##
## A played Goob lands, then its special effect resolves, then the win check
## runs (slice §4). Random effect targets are picked here, before the view
## animates them; last_effect tells the view what happened.

enum Phase {
	PLAYER_TURN,
	OPPONENT_TURN,
	OVER,
}

## DRAW covers a mutual four, a full board with no four, and a stalemate.
enum Result {
	NONE,
	PLAYER_WIN,
	OPPONENT_WIN,
	DRAW,
}

const TURN_DRAW := 1
const PLENTIFUL_DRAW := 2
const VANILLA := preload("res://resources/goobs/vanilla_goob.tres")
## 8-way adjacency from the landed cell (slice §4 roster).
const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var board: BoardState
var phase: Phase = Phase.PLAYER_TURN
var result: Result = Result.NONE
var player_deck := Deck.new()
var opponent_deck := Deck.new()
## The unshuffled lists the two decks were built from (a draw replay passes
## them back to start() to reshuffle the same decks).
var player_goobs: Array[GoobDefinition] = []
var opponent_goobs: Array[GoobDefinition] = []

## The start-of-turn draw of the turn now in progress (empty if nothing was
## drawn), and whether it was skipped because the hand was full.
var last_draw: Array[GoobDefinition] = []
var last_draw_hand_full := false
## Sides whose turn was skipped (empty hand) in the latest turn change, in
## order, for the view's "Turn skipped" toast.
var last_skipped: Array[BoardState.CellOwner] = []
## Side -> whether its latest turn was skipped; that side's next turn draw
## always happens, so no side is skipped twice in a row.
var _skipped_last: Dictionary = {}

## What the last play's special effect did (M5), for the view:
##   kind: GoobDefinition.EffectType of the played Goob
##   cell: Vector2i where it landed; side: BoardState.CellOwner
##   fizzled: true when it had nothing to act on (Sean, 2026-11-19)
##   target: Vector2i flipped (Convincing) or destroyed (Fat) cell, and
##   target_owner: who owned it before
##   extra: Vector2i where Popular's Vanilla landed
##   drawn: Array[GoobDefinition] and hand_full: bool (Plentiful)
var last_effect: Dictionary = {}

## Every effect step of the current play(), in order (reset by play()): the
## same keys as last_effect, plus {"discarded": GoobDefinition, "index": int}
## (its hand index) for a discard from discard_from(). last_effect is the
## played Goob's own step (a Bouncy / Slippery landing step can come before
## it); a discard sets it only when it is still {}.
var effect_steps: Array[Dictionary] = []

## Active statuses: {id: StringName, side: BoardState.CellOwner, label: String,
## text: String, turns_left: int}; turns_left -1 = until removed. Ticked in
## _begin_turn, cleared by start().
var statuses: Array[Dictionary] = []

## Vector2i(column, row) -> GoobDefinition of the Goob sitting there.
var _cell_goobs: Dictionary = {}
var _rng := RandomNumberGenerator.new()

## Move effects (M6e): the motion list of the step being resolved, the id of
## the latest gravity pass (its falls play together), and the direction the
## latest hop left a Goob going.
var _motions: Array = []
var _group := 0
var _last_dir := 0
## The effect type behind the latest chain move (names a destroy's chain step).
var _chain_kind := GoobDefinition.EffectType.NONE
## Outcome enumeration (play_outcomes, for the AI): random picks follow
## _script, then take 0; every pick is logged as [value, choices].
var _scripted := false
var _script: Array[int] = []
var _picks: Array = []


func _init() -> void:
	board = BoardState.new()


## New scenario (or draw replay): empty board, both starter decks shuffled,
## starting hands of Deck.START_HAND, then the first side's turn begins (with its draw).
## `deck` alone replaces the decks of both sides (tests); `deck` and
## `opponent_deck_goobs` give one each; neither rolls a deck per side
## (DeckBuilder, `forced` as in DeckBuilder.roll).
func start(player_first: bool, rng: RandomNumberGenerator = null, deck: Array[GoobDefinition] = [], opponent_deck_goobs: Array[GoobDefinition] = [], forced := {}) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_rng = rng
	last_effect = {}
	effect_steps = []
	statuses = []
	board.reset()
	_cell_goobs.clear()
	_skipped_last.clear()
	result = Result.NONE
	if deck.is_empty():
		player_goobs = DeckBuilder.roll(rng, forced)
		opponent_goobs = DeckBuilder.roll(rng, forced)
	else:
		player_goobs = deck
		opponent_goobs = opponent_deck_goobs if not opponent_deck_goobs.is_empty() else deck
	player_deck = Deck.shuffled(player_goobs, rng)
	opponent_deck = Deck.shuffled(opponent_goobs, rng)
	player_deck.draw(Deck.START_HAND)
	opponent_deck.draw(Deck.START_HAND)
	_begin_turn(Phase.PLAYER_TURN if player_first else Phase.OPPONENT_TURN)


func current_side() -> BoardState.CellOwner:
	match phase:
		Phase.PLAYER_TURN:
			return BoardState.CellOwner.PLAYER
		Phase.OPPONENT_TURN:
			return BoardState.CellOwner.OPPONENT
	return BoardState.CellOwner.EMPTY


func deck_of(side: BoardState.CellOwner) -> Deck:
	return player_deck if side == BoardState.CellOwner.PLAYER else opponent_deck


func current_deck() -> Deck:
	return deck_of(current_side())


func can_play(column: int) -> bool:
	return phase != Phase.OVER and board.is_valid_column(column) and not board.column_full(column)


## The Goob in (column, row), or null if empty.
func goob_at(column: int, row: int) -> GoobDefinition:
	return _cell_goobs.get(Vector2i(column, row))


## Plays the current side's hand Goob at `hand_index` into `column`. Returns
## the landed row, or -1 with no state change if the move is not allowed.
## Order (slice §4): land → effect → win check last. `rolled_dir`: the
## direction (-1 / +1) of the timeout roll that brought it here (0 = none),
## so a Bouncy under it sends it on that way.
func play(column: int, hand_index: int = 0, rolled_dir: int = 0) -> int:
	if not can_play(column):
		return -1
	var deck := current_deck()
	if hand_index < 0 or hand_index >= deck.hand.size():
		return -1
	effect_steps = []
	last_effect = {}
	var goob := deck.take(hand_index)
	var side := current_side()
	var row := _land_and_resolve(goob, column, side, rolled_dir)
	_on_turn_end(side)
	match board.get_outcome():
		BoardState.Outcome.PLAYER_WIN:
			_finish(Result.PLAYER_WIN)
		BoardState.Outcome.OPPONENT_WIN:
			_finish(Result.OPPONENT_WIN)
		BoardState.Outcome.DRAW:
			_finish(Result.DRAW)
		_:
			if board.is_board_full():
				_finish(Result.DRAW)
			else:
				_begin_turn(Phase.OPPONENT_TURN if phase == Phase.PLAYER_TURN else Phase.PLAYER_TURN)
	return row


## Drops `goob` for `side` into `column`; a Bouncy or Slippery Goob under it
## moves it first (M6e), then its effect resolves where it ended up. Returns
## the row it first landed in.
func _land_and_resolve(goob: GoobDefinition, column: int, side: BoardState.CellOwner, rolled_dir: int = 0) -> int:
	var row := board.drop(column, side)
	var cell := Vector2i(column, row)
	_cell_goobs[cell] = goob
	cell = _landing_step(cell, rolled_dir)
	_resolve_effect(goob, cell, side)
	return row


## A Goob that just landed in `cell` on a Bouncy or Slippery is moved by it
## straight away, as its own "instant" step (no wind-up), then gravity and
## chains settle. Returns where it ended up.
func _landing_step(cell: Vector2i, rolled_dir: int = 0) -> Vector2i:
	if not _on_mover(cell):
		return cell
	var under := cell + Vector2i(0, -1)
	var step := _move_step(_effect_at(under), under, board.get_owner(under.x, under.y))
	step["instant"] = true
	cell = _landing_move(cell, rolled_dir)
	_settle()
	if step["motions"].is_empty():
		effect_steps.erase(step)
	return cell


## Whether the Goob in `cell` sits on a Bouncy or Slippery.
func _on_mover(cell: Vector2i) -> bool:
	var below := _effect_at(cell + Vector2i(0, -1))
	return below == GoobDefinition.EffectType.BOUNCY or below == GoobDefinition.EffectType.SLIPPERY


## A Goob landing on a Bouncy bounces to the next column (`dir` when it was
## rolling, else a random side); on a Slippery it rolls a random way it can
## (boxed in = stays). Sean, 2026-11-23. Records into the current motions;
## returns where it ended up.
func _landing_move(cell: Vector2i, dir: int = 0) -> Vector2i:
	if _effect_at(cell + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
		if dir == 0:
			var sides := _open_sides(cell)
			dir = sides[_pick(sides.size())]
		var carried := _lift(cell)
		var points: Array = []
		var to := _bounce(cell, dir, points)
		_put(to, carried)
		_record(cell, to, points)
		return to
	var dirs := _roll_dirs(cell)
	if dirs.is_empty():
		return cell
	return _roll(cell, dirs[_pick(dirs.size())])


## The played Goob's special effect (slice §4 roster). Random targets come
## from the scenario rng; with nothing to act on the effect fizzles.
func _resolve_effect(goob: GoobDefinition, cell: Vector2i, side: BoardState.CellOwner) -> void:
	var step := {"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false}
	effect_steps.append(step)
	last_effect = step
	if goob.effect_type in GoobDefinition.PASSIVE_EFFECTS:
		step["passive"] = true # acts later, while on the board
	match goob.effect_type:
		GoobDefinition.EffectType.FLIP_ADJACENT:
			var targets := neighbours(board, cell, enemy_of(side))
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_pick(targets.size())]
			step["target_owner"] = board.get_owner(target.x, target.y)
			board.set_owner(target.x, target.y, side)
			step["target"] = target
		GoobDefinition.EffectType.DESTROY_ADJACENT:
			var targets := neighbours(board, cell, BoardState.CellOwner.EMPTY)
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_pick(targets.size())]
			var height := _column_height(target.x)
			step["target_owner"] = board.get_owner(target.x, target.y)
			destroy_at(target)
			step["target"] = target
			# The Goobs above it fell: chains (Lopsided / Tipsy, landing on a
			# Bouncy / Slippery) follow as their own step.
			var fell: Array[Vector2i] = []
			for r in range(target.y, height - 1):
				fell.append(Vector2i(target.x, r))
			_roll_fallen(fell)
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			var open := open_columns(board)
			if open.is_empty():
				step["fizzled"] = true
				return
			var column := open[_pick(open.size())]
			var row := board.drop(column, side)
			_cell_goobs[Vector2i(column, row)] = VANILLA
			step["extra"] = Vector2i(column, row)
			# Landing on a Bouncy / Slippery moves it too (Sean, 2026-11-23).
			_landing_step(Vector2i(column, row))
		GoobDefinition.EffectType.DRAW_TWO:
			var deck := deck_of(side)
			var hand_full := deck.draw_blocked_by_hand(PLENTIFUL_DRAW)
			var drawn := deck.draw(PLENTIFUL_DRAW)
			step["drawn"] = drawn
			step["hand_full"] = hand_full
			# Nothing drawn and not a full hand = an empty deck: fizzle.
			step["fizzled"] = drawn.is_empty() and not hand_full
		GoobDefinition.EffectType.PUSH_LEFT, GoobDefinition.EffectType.PUSH_RIGHT:
			step["motions"] = []
			_motions = step["motions"]
			var dir := -1 if goob.effect_type == GoobDefinition.EffectType.PUSH_LEFT else 1
			# Only its side of the row, edge-nearest first so the row packs
			# toward the edge; the row moves, then the Goobs above fall.
			var columns: Array = range(0, cell.x) if dir < 0 else range(BoardState.COLUMNS - 1, cell.x, -1)
			for c: int in columns:
				var at := Vector2i(c, cell.y)
				if not board.is_empty(at.x, at.y) and _can_roll(at, dir):
					_roll(at, dir)
			step["fizzled"] = _motions.is_empty()
			_settle()
		GoobDefinition.EffectType.ROLL_LEFT, GoobDefinition.EffectType.ROLL_RIGHT:
			step["motions"] = []
			_motions = step["motions"]
			var dir := -1 if goob.effect_type == GoobDefinition.EffectType.ROLL_LEFT else 1
			if not _can_roll(cell, dir):
				step["fizzled"] = true
				return
			_roll(cell, dir)
			_settle()
		GoobDefinition.EffectType.ROLL_HIGHEST, GoobDefinition.EffectType.ROLL_IN_ROW:
			step["motions"] = []
			_motions = step["motions"]
			var targets: Array[Vector2i] = []
			if goob.effect_type == GoobDefinition.EffectType.ROLL_HIGHEST:
				# The top Goob of the highest row, Blustery included; random
				# among the ones there that can roll (Sean, 2026-11-23).
				var top := 0
				for c in BoardState.COLUMNS:
					top = maxi(top, _column_height(c))
				targets = _rollable_in_row(top - 1, Vector2i(-1, -1))
			else:
				targets = _rollable_in_row(cell.y, cell) # never Fidgety itself
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_pick(targets.size())]
			var dirs := _roll_dirs(target)
			step["rolled"] = target
			_roll(target, dirs[_pick(dirs.size())])
			_settle()


## Destroys the Goob at `cell`: it goes to the destroyed pile of the side that
## owned it, and the Goobs above fall one row (BoardState.destroy_cell).
func destroy_at(cell: Vector2i) -> void:
	var owner := board.get_owner(cell.x, cell.y)
	var goob: GoobDefinition = _cell_goobs.get(cell)
	board.destroy_cell(cell.x, cell.y)
	if goob != null and owner != BoardState.CellOwner.EMPTY:
		deck_of(owner).destroyed_pile.append(goob)
	_collapse_goobs(cell.x, cell.y)


## Moves the cell Goob definitions above `from_row` in `column` down one row.
func _collapse_goobs(column: int, from_row: int) -> void:
	for r in range(from_row, BoardState.ROWS):
		var above := Vector2i(column, r + 1)
		if _cell_goobs.has(above):
			_cell_goobs[Vector2i(column, r)] = _cell_goobs[above]
		else:
			_cell_goobs.erase(Vector2i(column, r))


## Rolls the Goob at `cell` sideways (`dir` -1 or +1) while the cell beside it
## in the next column is free, falling to the top of that column; a column
## level with it or higher, or the edge, stops it. Returns the cells it passed
## through after leaving `cell` (empty = didn't move). Keeps owner and
## definition; the Goobs above its old cell fall. An empty `cell` doesn't move.
## Bouncy and Springy Goobs act on it (M6e).
func roll_goob(cell: Vector2i, dir: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if board.is_empty(cell.x, cell.y):
		return path # nothing to roll
	_motions = []
	_roll(cell, dir)
	# The cell it ended up in for each column it passed through.
	if not _motions.is_empty():
		for point: Dictionary in _motions[0]["points"]:
			var at: Vector2i = point["at"]
			if at.y >= BoardState.ROWS or not board.is_valid_column(at.x):
				continue
			if not path.is_empty() and path[-1].x == at.x:
				path[-1] = at
			else:
				path.append(at)
	_apply_gravity()
	return path


# --- Move effects (M6e; Sean, 2026-11-23: vault Special Goobs "M6e Move rules")
# A motion is {"from": Vector2i, "to": Vector2i, "points": Array, "group": int};
# each point is {"at": Vector2i, "how": &"slide" | &"fall" | &"hop" | &"edge"}.
# Row BoardState.ROWS is the top of the board; an "edge" point is off the
# board (the Goob bumps the edge and comes back). Motions play in order; ones
# sharing a group > 0 (one gravity pass) play together.

const _MAX_BOUNCES := 16
const _MAX_CHAIN := 32


## A new move step (kind, cell, side) whose motions are recorded from now on.
func _move_step(kind: GoobDefinition.EffectType, cell: Vector2i, side: BoardState.CellOwner) -> Dictionary:
	var step := {"kind": kind, "cell": cell, "side": side, "fizzled": false, "motions": []}
	effect_steps.append(step)
	_motions = step["motions"]
	return step


func _record(from: Vector2i, to: Vector2i, points: Array, group: int = 0) -> void:
	if from != to or not points.is_empty():
		_motions.append({"from": from, "to": to, "points": points, "group": group})


## A random index below `count` (scripted while enumerating outcomes).
func _pick(count: int) -> int:
	if not _scripted:
		return _rng.randi_range(0, count - 1)
	var value := _script[_picks.size()] if _picks.size() < _script.size() else 0
	_picks.append([value, count])
	return value


func _effect_at(cell: Vector2i) -> GoobDefinition.EffectType:
	var goob: GoobDefinition = _cell_goobs.get(cell)
	if goob == null or board.is_empty(cell.x, cell.y):
		return GoobDefinition.EffectType.NONE
	return goob.effect_type


## Height of `column` up to its highest Goob (holes included).
func _column_height(column: int) -> int:
	for r in range(BoardState.ROWS - 1, -1, -1):
		if not board.is_empty(column, r):
			return r + 1
	return 0


## Takes the Goob off `cell` without gravity: {owner, goob}.
func _lift(cell: Vector2i) -> Dictionary:
	var carried := {"owner": board.get_owner(cell.x, cell.y), "goob": _cell_goobs.get(cell)}
	board.set_owner(cell.x, cell.y, BoardState.CellOwner.EMPTY)
	_cell_goobs.erase(cell)
	return carried


func _put(cell: Vector2i, carried: Dictionary) -> void:
	board.set_owner(cell.x, cell.y, carried["owner"])
	if carried["goob"] != null:
		_cell_goobs[cell] = carried["goob"]


## Whether the Goob in `cell` can roll `dir`: the cell beside it is free, or
## holds a Springy it would bounce off.
func _can_roll(cell: Vector2i, dir: int) -> bool:
	var next := cell + Vector2i(dir, 0)
	if not board.in_bounds(next.x, next.y):
		return false
	return board.is_empty(next.x, next.y) or _effect_at(next) == GoobDefinition.EffectType.SPRINGY


## Directions the Goob in `cell` can roll (random rolls pick one of these).
func _roll_dirs(cell: Vector2i) -> Array[int]:
	var dirs: Array[int] = []
	for dir: int in [-1, 1]:
		if _can_roll(cell, dir):
			dirs.append(dir)
	return dirs


## Sides of `cell` that have a column (a played Goob's Bouncy bounce).
func _open_sides(cell: Vector2i) -> Array[int]:
	var sides: Array[int] = []
	for dir: int in [-1, 1]:
		if board.is_valid_column(cell.x + dir):
			sides.append(dir)
	return sides


## Goobs in `row` (except `skip`) that can roll somewhere.
func _rollable_in_row(row: int, skip: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if row < 0:
		return found
	for c in BoardState.COLUMNS:
		var at := Vector2i(c, row)
		if at != skip and not board.is_empty(c, row) and not _roll_dirs(at).is_empty():
			found.append(at)
	return found


## Rolls the Goob at `cell` `dir` by the roll rule and records the motion. A
## Springy beside it bounces it onto the top of the Springy's column; landing
## on a Bouncy bounces it on; a bounce ends the roll (Sean, 2026-11-23). The
## Goobs above its old cell wait for the next gravity pass. Returns where it
## ended up.
func _roll(cell: Vector2i, dir: int) -> Vector2i:
	var carried := _lift(cell)
	var points: Array = []
	var at := cell
	while true:
		var next := at.x + dir
		if not board.is_valid_column(next):
			break
		if board.is_empty(next, at.y):
			points.append({"at": Vector2i(next, at.y), "how": &"slide"})
			var y := at.y
			while y > 0 and board.is_empty(next, y - 1):
				y -= 1
			if y != at.y:
				points.append({"at": Vector2i(next, y), "how": &"fall"})
			at = Vector2i(next, y)
			if _effect_at(at + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
				at = _bounce(at, dir, points, cell)
				break
			continue
		if _effect_at(Vector2i(next, at.y)) == GoobDefinition.EffectType.SPRINGY:
			at = _hop(at, next, dir, points, cell)
			if _effect_at(at + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
				at = _bounce(at, _last_dir, points, cell)
		break
	_put(at, carried)
	_record(cell, at, points)
	return at


## On top of a Bouncy at `at`: jumps onto the next column `dir` whatever its
## height (no column there → the other way), again while it lands on a
## Bouncy. `origin`: where it goes back to if nothing is open.
func _bounce(at: Vector2i, dir: int, points: Array, origin: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if origin.x < 0:
		origin = at
	for i in _MAX_BOUNCES:
		var column := at.x + dir
		if not board.is_valid_column(column):
			dir = -dir
			column = at.x + dir
		at = _hop(at, column, dir, points, origin)
		dir = _last_dir
		if _effect_at(at + Vector2i(0, -1)) != GoobDefinition.EffectType.BOUNCY:
			break
	return at


## Jumps from `at` onto the top of `column`; a full column → it rolls from the
## top (over full columns, off the edges, into the first open column). Sets
## _last_dir to the direction it ends up going.
func _hop(at: Vector2i, column: int, dir: int, points: Array, origin: Vector2i) -> Vector2i:
	_last_dir = dir
	var top := _column_height(column)
	if top < BoardState.ROWS:
		points.append({"at": Vector2i(column, top), "how": &"hop"})
		return Vector2i(column, top)
	points.append({"at": Vector2i(column, BoardState.ROWS), "how": &"hop"})
	var c := column
	for i in BoardState.COLUMNS * 2 + 2:
		if _column_height(c) < BoardState.ROWS:
			break
		if not board.is_valid_column(c + dir):
			points.append({"at": Vector2i(c + dir, BoardState.ROWS), "how": &"edge"})
			dir = -dir
		c += dir
		points.append({"at": Vector2i(c, BoardState.ROWS), "how": &"slide"})
	_last_dir = dir
	top = _column_height(c)
	if top >= BoardState.ROWS:
		points.append({"at": origin, "how": &"hop"}) # nowhere open: back
		return origin
	points.append({"at": Vector2i(c, top), "how": &"fall"})
	return Vector2i(c, top)


## Gravity: every Goob over a gap falls (one group, played together).
## Returns {from: to} for the ones that fell.
func _apply_gravity() -> Dictionary:
	var moved := {}
	_group += 1
	for c in BoardState.COLUMNS:
		var write := 0
		for r in BoardState.ROWS:
			if board.is_empty(c, r):
				continue
			if r != write:
				var from := Vector2i(c, r)
				var to := Vector2i(c, write)
				_put(to, _lift(from))
				_record(from, to, [{"at": to, "how": &"fall"}], _group)
				moved[from] = to
			write += 1
	return moved


## Gravity, then the chains, one Goob at a time with gravity after each, until
## still: a fallen Lopsided / Tipsy rolls its way, and a Goob that fell onto a
## Bouncy / Slippery (one that didn't fall with it) is moved by it (Sean,
## 2026-11-23). `pending`: {cell: landed} for Goobs that already fell
## (landed = the Goob under it didn't fall with it). A chain that brings the
## board back to a position it already had is looping (e.g. Slippery →
## Springy → over the top back onto the same Slippery) and stops there.
func _settle(pending: Dictionary = {}) -> void:
	var seen := {}
	for i in _MAX_CHAIN:
		var moved := _apply_gravity()
		var key := _position_key()
		if seen.has(key):
			return
		seen[key] = true
		var next := {}
		for at: Vector2i in pending:
			if not moved.has(at):
				next[at] = pending[at]
		var landed_on := {}
		for to: Vector2i in moved.values():
			landed_on[to] = true
		for to: Vector2i in moved.values():
			next[to] = not landed_on.has(to + Vector2i(0, -1))
		pending = next
		if not _chain_one(pending):
			return
	_apply_gravity() # never leave a Goob floating


## The board position: every cell's owner and Goob type.
func _position_key() -> String:
	var key := ""
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var goob: GoobDefinition = _cell_goobs.get(Vector2i(c, r))
			key += "%d%s," % [board.get_owner(c, r), goob.id if goob != null else ""]
	return key


## Moves the first pending Goob that acts (bottom to top, left to right) and
## drops the ones checked before it. Returns whether one moved.
func _chain_one(pending: Dictionary) -> bool:
	var cells: Array = pending.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for at: Vector2i in cells:
		var landed: bool = pending[at]
		pending.erase(at)
		if board.is_empty(at.x, at.y):
			continue
		var kind := _effect_at(at)
		var rolls := kind == GoobDefinition.EffectType.ROLL_LEFT or kind == GoobDefinition.EffectType.ROLL_RIGHT
		if landed and _on_mover(at):
			var below := _effect_at(at + Vector2i(0, -1))
			var to := _landing_move(at)
			if to == at:
				if not rolls:
					continue
			else:
				_chain_kind = below
				if rolls:
					pending[to] = false # it landed again: it rolls next
				return true
		if rolls:
			var dir := -1 if kind == GoobDefinition.EffectType.ROLL_LEFT else 1
			if _can_roll(at, dir):
				_chain_kind = kind
				_roll(at, dir)
				return true
	return false


## A destroy made the Goobs now at `fell` (bottom up) drop: their chains play
## as their own step.
func _roll_fallen(fell: Array[Vector2i]) -> void:
	if fell.is_empty():
		return
	var pending := {}
	for k in fell.size():
		pending[fell[k]] = k == 0 # only the lowest landed on something new
	var step := _move_step(GoobDefinition.EffectType.NONE, fell[0], board.get_owner(fell[0].x, fell[0].y))
	step["chain"] = true
	_settle(pending)
	if step["motions"].is_empty():
		effect_steps.erase(step)
	else:
		step["kind"] = _chain_kind


## Discards `side`'s hand Goob at `index`; returns it (null if out of range).
func discard_from(side: BoardState.CellOwner, index: int) -> GoobDefinition:
	var goob := deck_of(side).discard(index)
	if goob != null:
		effect_steps.append({"kind": GoobDefinition.EffectType.NONE, "discarded": goob, "index": index, "side": side, "cell": Vector2i(-1, -1), "fizzled": false})
		if last_effect.is_empty():
			last_effect = effect_steps[0]
	return goob


## Adds a status (replacing one with the same id and side).
func add_status(id: StringName, side: BoardState.CellOwner, label: String, text: String, turns_left: int) -> void:
	remove_status(id, side)
	statuses.append({"id": id, "side": side, "label": label, "text": text, "turns_left": turns_left})


func remove_status(id: StringName, side: BoardState.CellOwner) -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i]["id"] == id and statuses[i]["side"] == side:
			statuses.remove_at(i)


func has_status(id: StringName, side: BoardState.CellOwner) -> bool:
	for st in statuses:
		if st["id"] == id and st["side"] == side:
			return true
	return false


## Hook for category sessions: called at the start of `side`'s turn, after
## the status tick and before the draw.
func _on_turn_start(_side: BoardState.CellOwner) -> void:
	pass


## Hook for category sessions: called in play() after the effect, before the win check.
func _on_turn_end(_side: BoardState.CellOwner) -> void:
	pass


## Occupied neighbours of `cell` on `board` (8-way). `only` = that side's
## Goobs; EMPTY = any Goob.
static func neighbours(on: BoardState, cell: Vector2i, only: BoardState.CellOwner) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for offset in _NEIGHBOURS:
		var at := cell + offset
		var owner := on.get_owner(at.x, at.y)
		if owner == BoardState.CellOwner.EMPTY:
			continue
		if only == BoardState.CellOwner.EMPTY or owner == only:
			found.append(at)
	return found


static func open_columns(on: BoardState) -> Array[int]:
	var open: Array[int] = []
	for c in BoardState.COLUMNS:
		if not on.column_full(c):
			open.append(c)
	return open


static func enemy_of(side: BoardState.CellOwner) -> BoardState.CellOwner:
	return BoardState.CellOwner.OPPONENT if side == BoardState.CellOwner.PLAYER else BoardState.CellOwner.PLAYER


## Every equally likely board after `effect` resolves for a Goob of `side`
## that landed in `cell` on `after_land` (same targets as _resolve_effect;
## for the AI, M6c). Effects that leave the board alone, and fizzles, give
## [after_land]. Never mutates `after_land`.
static func effect_outcomes(after_land: BoardState, effect: GoobDefinition.EffectType, cell: Vector2i, side: BoardState.CellOwner) -> Array[BoardState]:
	var outcomes: Array[BoardState] = []
	match effect:
		GoobDefinition.EffectType.FLIP_ADJACENT:
			for target in neighbours(after_land, cell, enemy_of(side)):
				var b := after_land.copy()
				b.set_owner(target.x, target.y, side)
				outcomes.append(b)
		GoobDefinition.EffectType.DESTROY_ADJACENT:
			for target in neighbours(after_land, cell, BoardState.CellOwner.EMPTY):
				var b := after_land.copy()
				b.destroy_cell(target.x, target.y)
				outcomes.append(b)
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			for column in open_columns(after_land):
				var b := after_land.copy()
				b.drop(column, side)
				outcomes.append(b)
	if outcomes.is_empty():
		outcomes.append(after_land)
	return outcomes


## Every board after `side` plays `goob` into `column` on `on` (see
## play_results). Never mutates `on`.
static func play_outcomes(on: BoardState, goobs: Dictionary, goob: GoobDefinition, column: int, side: BoardState.CellOwner, limit: int = 48) -> Array[BoardState]:
	var boards: Array[BoardState] = []
	for result in play_results(on, goobs, goob, column, side, limit):
		boards.append(result["board"])
	return boards


## Every outcome of `side` playing `goob` into `column` on `on` (`goobs`:
## cell -> GoobDefinition, as from cell_goobs()): landing moves, the effect
## and its chains, every random pick enumerated (for the AI; M6e). Each is
## {board, goobs, weight}; weight = its chance (the picks along the way can
## differ in count, so outcomes are not equally likely). At most `limit`
## outcomes (then the weights sum to less than 1). Never mutates `on`.
static func play_results(on: BoardState, goobs: Dictionary, goob: GoobDefinition, column: int, side: BoardState.CellOwner, limit: int = 48) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var script: Array[int] = []
	for run in limit:
		var sim := TurnLoop.new()
		sim.board = on.copy()
		sim._cell_goobs = goobs.duplicate()
		sim._scripted = true
		sim._script = script
		sim._land_and_resolve(goob, column, side)
		var weight := 1.0
		for pick: Array in sim._picks:
			weight /= pick[1]
		results.append({"board": sim.board, "goobs": sim._cell_goobs, "weight": weight})
		# Next pick sequence: bump the last pick that has choices left.
		var i := sim._picks.size() - 1
		while i >= 0 and sim._picks[i][0] + 1 >= sim._picks[i][1]:
			i -= 1
		if i < 0:
			break
		script = []
		for j in i:
			script.append(sim._picks[j][0])
		script.append(sim._picks[i][0] + 1)
	return results


## A copy of the cell -> GoobDefinition map (for play_outcomes).
func cell_goobs() -> Dictionary:
	return _cell_goobs.duplicate()


## Every Goob in any of `side`'s winning lines, each once, in scoring reveal
## order: lowest column to highest, bottom to top (slice §4; all lines count,
## Sean 2026-11-19).
func scoring_cells(side: BoardState.CellOwner) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for line: Array[Vector2i] in board.find_all_winning_lines(side):
		for cell in line:
			if not cells.has(cell):
				cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return cells


## Gives the turn to `next` if that side has Goobs, else back to the other
## side; if neither has any, the scenario is a draw. Then the turn's draw.
func _begin_turn(next: Phase, chained := false) -> void:
	last_draw = []
	last_draw_hand_full = false
	if not chained:
		last_skipped = []
	var other := Phase.OPPONENT_TURN if next == Phase.PLAYER_TURN else Phase.PLAYER_TURN
	if _deck_for_phase(next).has_goobs():
		phase = next
	elif _deck_for_phase(other).has_goobs():
		phase = other
	else:
		_finish(Result.DRAW)
		return
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i]["turns_left"] > 0:
			statuses[i]["turns_left"] -= 1
			if statuses[i]["turns_left"] == 0:
				statuses.remove_at(i)
	_on_turn_start(current_side())
	var deck := current_deck()
	var side := current_side()
	var count := _turn_draw_count(side)
	if _skipped_last.get(side, false):
		count = maxi(count, TURN_DRAW) # never two skipped turns in a row
	last_draw_hand_full = deck.draw_blocked_by_hand(count)
	last_draw = deck.draw(count)
	# No playable Goob (empty hand) after the draw, e.g. a discard plus a
	# prevented draw: this turn is skipped and turn order goes on as normal
	# (Sean, 2026-11-23; skips are never a draw).
	_skipped_last[side] = deck.hand.is_empty()
	if deck.hand.is_empty():
		last_skipped.append(side)
		_begin_turn(other if phase == next else next, true)


## How many Goobs `side` draws at its turn start. Draw effects (M6e draw
## session) change this.
func _turn_draw_count(_side: BoardState.CellOwner) -> int:
	return TURN_DRAW


## Whether `side`'s latest turn was skipped (its next turn can't be).
func was_skipped_last(side: BoardState.CellOwner) -> bool:
	return _skipped_last.get(side, false)


## The current side's hand ran out during its own turn (e.g. its last Goob was
## discarded): its turn is skipped and the other side's begins.
func skip_turn() -> void:
	if phase == Phase.OVER:
		return
	var side := current_side()
	_begin_turn(Phase.OPPONENT_TURN if phase == Phase.PLAYER_TURN else Phase.PLAYER_TURN)
	_skipped_last[side] = true
	last_skipped.push_front(side)


func _deck_for_phase(p: Phase) -> Deck:
	return player_deck if p == Phase.PLAYER_TURN else opponent_deck


func _finish(r: Result) -> void:
	result = r
	phase = Phase.OVER
