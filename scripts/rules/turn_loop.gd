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

## Vector2i(column, row) -> GoobDefinition of the Goob sitting there.
var _cell_goobs: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	board = BoardState.new()


## New scenario (or draw replay): empty board, both starter decks shuffled,
## starting hands of 3, then the first side's turn begins (with its draw).
## `deck` replaces the starter deck for both sides (tests).
func start(player_first: bool, rng: RandomNumberGenerator = null, deck: Array[GoobDefinition] = []) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_rng = rng
	last_effect = {}
	board.reset()
	_cell_goobs.clear()
	result = Result.NONE
	var goobs := deck if not deck.is_empty() else StarterDeck.build()
	player_deck = Deck.shuffled(goobs, rng)
	opponent_deck = Deck.shuffled(goobs, rng)
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
	var goob := deck.take(hand_index)
	var side := current_side()
	var row := board.drop(column, side)
	_cell_goobs[Vector2i(column, row)] = goob
	_resolve_effect(goob, Vector2i(column, row), side)
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
	last_effect = {"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false}
	match goob.effect_type:
		GoobDefinition.EffectType.FLIP_ADJACENT:
			var enemy := BoardState.CellOwner.OPPONENT if side == BoardState.CellOwner.PLAYER else BoardState.CellOwner.PLAYER
			var targets := _neighbours(cell, enemy)
			if targets.is_empty():
				last_effect["fizzled"] = true
				return
			var target := targets[_rng.randi_range(0, targets.size() - 1)]
			board.set_owner(target.x, target.y, side)
			last_effect["target"] = target
		GoobDefinition.EffectType.DESTROY_ADJACENT:
			var targets := _neighbours(cell, BoardState.CellOwner.EMPTY)
			if targets.is_empty():
				last_effect["fizzled"] = true
				return
			var target := targets[_rng.randi_range(0, targets.size() - 1)]
			board.destroy_cell(target.x, target.y)
			# Goobs above fall one row (BoardState.destroy_cell); move their defs too.
			for r in range(target.y, BoardState.ROWS):
				var above := Vector2i(target.x, r + 1)
				if _cell_goobs.has(above):
					_cell_goobs[Vector2i(target.x, r)] = _cell_goobs[above]
				else:
					_cell_goobs.erase(Vector2i(target.x, r))
			last_effect["target"] = target
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			var open: Array[int] = []
			for c in BoardState.COLUMNS:
				if not board.column_full(c):
					open.append(c)
			if open.is_empty():
				last_effect["fizzled"] = true
				return
			var column := open[_rng.randi_range(0, open.size() - 1)]
			var row := board.drop(column, side)
			_cell_goobs[Vector2i(column, row)] = VANILLA
			last_effect["extra"] = Vector2i(column, row)
		GoobDefinition.EffectType.DRAW_TWO:
			var deck := deck_of(side)
			var hand_full := deck.draw_blocked_by_hand(PLENTIFUL_DRAW)
			var drawn := deck.draw(PLENTIFUL_DRAW)
			last_effect["drawn"] = drawn
			last_effect["hand_full"] = hand_full
			# Nothing drawn and not a full hand = an empty deck: fizzle.
			last_effect["fizzled"] = drawn.is_empty() and not hand_full


## Occupied neighbours of `cell` (8-way). `only` = that side's Goobs; EMPTY =
## any Goob.
func _neighbours(cell: Vector2i, only: BoardState.CellOwner) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for offset in _NEIGHBOURS:
		var at := cell + offset
		var owner := board.get_owner(at.x, at.y)
		if owner == BoardState.CellOwner.EMPTY:
			continue
		if only == BoardState.CellOwner.EMPTY or owner == only:
			found.append(at)
	return found


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
	var deck := current_deck()
	last_draw_hand_full = deck.draw_blocked_by_hand(TURN_DRAW)
	last_draw = deck.draw(TURN_DRAW)


func _deck_for_phase(p: Phase) -> Deck:
	return player_deck if p == Phase.PLAYER_TURN else opponent_deck


func _finish(r: Result) -> void:
	result = r
	phase = Phase.OVER
