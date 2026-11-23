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

## What the last play's special effect did (M5), for the view:
##   kind: GoobDefinition.EffectType of the played Goob
##   cell: Vector2i where it landed; side: BoardState.CellOwner
##   fizzled: true when it had nothing to act on (Sean, 2026-11-19)
##   target: Vector2i flipped (Convincing) or destroyed (Fat) cell
##   extra: Vector2i where Popular's Vanilla landed
##   drawn: Array[GoobDefinition] and hand_full: bool (Plentiful)
var last_effect: Dictionary = {}

## Every effect step of the current play(), in order (reset by play()): the
## same keys as last_effect, plus {"discarded": GoobDefinition} for a discard
## from discard_from(). last_effect is effect_steps[0], or {} when empty.
var effect_steps: Array[Dictionary] = []

## Active statuses: {id: StringName, side: BoardState.CellOwner, label: String,
## text: String, turns_left: int}; turns_left -1 = until removed. Ticked in
## _begin_turn, cleared by start().
var statuses: Array[Dictionary] = []

## Vector2i(column, row) -> GoobDefinition of the Goob sitting there.
var _cell_goobs: Dictionary = {}
var _rng := RandomNumberGenerator.new()


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
## Order (slice §4): land → effect → win check last.
func play(column: int, hand_index: int = 0) -> int:
	if not can_play(column):
		return -1
	var deck := current_deck()
	if hand_index < 0 or hand_index >= deck.hand.size():
		return -1
	effect_steps = []
	last_effect = {}
	var goob := deck.take(hand_index)
	var side := current_side()
	var row := board.drop(column, side)
	_cell_goobs[Vector2i(column, row)] = goob
	_resolve_effect(goob, Vector2i(column, row), side)
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


## The played Goob's special effect (slice §4 roster). Random targets come
## from the scenario rng; with nothing to act on the effect fizzles.
func _resolve_effect(goob: GoobDefinition, cell: Vector2i, side: BoardState.CellOwner) -> void:
	var step := {"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false}
	effect_steps.append(step)
	last_effect = effect_steps[0]
	match goob.effect_type:
		GoobDefinition.EffectType.FLIP_ADJACENT:
			var targets := neighbours(board, cell, enemy_of(side))
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_rng.randi_range(0, targets.size() - 1)]
			board.set_owner(target.x, target.y, side)
			step["target"] = target
		GoobDefinition.EffectType.DESTROY_ADJACENT:
			var targets := neighbours(board, cell, BoardState.CellOwner.EMPTY)
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_rng.randi_range(0, targets.size() - 1)]
			destroy_at(target)
			step["target"] = target
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			var open := open_columns(board)
			if open.is_empty():
				step["fizzled"] = true
				return
			var column := open[_rng.randi_range(0, open.size() - 1)]
			var row := board.drop(column, side)
			_cell_goobs[Vector2i(column, row)] = VANILLA
			step["extra"] = Vector2i(column, row)
		GoobDefinition.EffectType.DRAW_TWO:
			var deck := deck_of(side)
			var hand_full := deck.draw_blocked_by_hand(PLENTIFUL_DRAW)
			var drawn := deck.draw(PLENTIFUL_DRAW)
			step["drawn"] = drawn
			step["hand_full"] = hand_full
			# Nothing drawn and not a full hand = an empty deck: fizzle.
			step["fizzled"] = drawn.is_empty() and not hand_full


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


## Rolls the Goob at `cell` sideways (`dir` -1 or +1) while the next column is
## strictly lower than the row it rests on, falling to the top of that column. Returns the cells it passed
## through after leaving `cell` (empty = didn't move). Keeps owner and
## definition; the Goobs above its old cell fall.
func roll_goob(cell: Vector2i, dir: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var owner := board.get_owner(cell.x, cell.y)
	var goob: GoobDefinition = _cell_goobs.get(cell)
	while true:
		var next := cell.x + dir
		if not board.is_valid_column(next):
			break
		var height := board.lowest_empty_row(next)
		if height < 0 or height >= cell.y:
			break
		board.destroy_cell(cell.x, cell.y)
		_collapse_goobs(cell.x, cell.y)
		var row := board.drop(next, owner)
		cell = Vector2i(next, row)
		_cell_goobs[cell] = goob
		path.append(cell)
	return path


## Discards `side`'s hand Goob at `index`; returns it (null if out of range).
func discard_from(side: BoardState.CellOwner, index: int) -> GoobDefinition:
	var goob := deck_of(side).discard(index)
	if goob != null:
		effect_steps.append({"kind": GoobDefinition.EffectType.NONE, "discarded": goob, "side": side, "cell": Vector2i(-1, -1), "fizzled": false})
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
func _begin_turn(next: Phase) -> void:
	last_draw = []
	last_draw_hand_full = false
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
	last_draw_hand_full = deck.draw_blocked_by_hand(TURN_DRAW)
	last_draw = deck.draw(TURN_DRAW)


func _deck_for_phase(p: Phase) -> Deck:
	return player_deck if p == Phase.PLAYER_TURN else opponent_deck


func _finish(r: Result) -> void:
	result = r
	phase = Phase.OVER
