class_name TurnLoop
extends RefCounted
## Alternating-turn rules for one scenario. Owns the BoardState and both
## decks; no rendering.
##
## Each turn starts by drawing 1 Goob (if the deck has one and the hand has
## room), then the side plays exactly 1 Goob from its hand (slice §4). A side
## with no Goobs left (hand + deck) takes no more turns; the other side plays
## on. Neither side able to play, with no four, is a draw (stalemate).

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

var board: BoardState
var phase: Phase = Phase.PLAYER_TURN
var result: Result = Result.NONE
var player_deck := Deck.new()
var opponent_deck := Deck.new()

## The start-of-turn draw of the turn now in progress (empty if nothing was
## drawn), and whether it was skipped because the hand was full.
var last_draw: Array[GoobDefinition] = []
var last_draw_hand_full := false

## Vector2i(column, row) -> GoobDefinition of the Goob sitting there.
var _cell_goobs: Dictionary = {}


func _init() -> void:
	board = BoardState.new()


## New scenario (or draw replay): empty board, both starter decks shuffled,
## starting hands of 3, then the first side's turn begins (with its draw).
func start(player_first: bool, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	board.reset()
	_cell_goobs.clear()
	result = Result.NONE
	player_deck = Deck.shuffled(StarterDeck.build(), rng)
	opponent_deck = Deck.shuffled(StarterDeck.build(), rng)
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
## Order (slice §4): land → effect (M5) → win check last.
func play(column: int, hand_index: int = 0) -> int:
	if not can_play(column):
		return -1
	var deck := current_deck()
	if hand_index < 0 or hand_index >= deck.hand.size():
		return -1
	var goob := deck.take(hand_index)
	var row := board.drop(column, current_side())
	_cell_goobs[Vector2i(column, row)] = goob
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
