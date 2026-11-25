class_name Deck
extends RefCounted
## One side's Goobs in a scenario: a shuffled draw pile and a hand (slice §4
## Decks). Shuffled once when built; never reshuffled. No rendering.

## Hand max 7 (Sean, M6f 2026-11-24; was 5): every extra draw stays in the
## hand for good (play 1 + draw 1 a turn), so 5 left room for only 2.
const HAND_MAX := 7
## Starting hand; the first turn draw makes 3 (Sean, 2026-11-19; was 3).
const START_HAND := 2

## Draw pile; the top of the deck is the END of the array.
var draw_pile: Array[GoobDefinition] = []
## Hand in draw order (oldest first); the player's fan shows it left to right.
var hand: Array[GoobDefinition] = []
## Goobs discarded from the hand (M6e).
var discard_pile: Array[GoobDefinition] = []
## This side's Goobs destroyed on the board (M6e).
var destroyed_pile: Array[GoobDefinition] = []
## Play data (M6g): this side's turn count (TurnLoop bumps it at each turn
## start) and, in step with `hand`, the turn each hand Goob was drawn on.
## Starting-hand Goobs count as drawn on turn 1. Bookkeeping only.
var turns := 0
var hand_drawn_at: Array[int] = []


## A shuffled copy of `goobs` as the draw pile, empty hand.
static func shuffled(goobs: Array[GoobDefinition], rng: RandomNumberGenerator) -> Deck:
	var deck := Deck.new()
	deck.draw_pile = goobs.duplicate()
	# Fisher–Yates with the injected rng so tests are deterministic.
	for i in range(deck.draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := deck.draw_pile[i]
		deck.draw_pile[i] = deck.draw_pile[j]
		deck.draw_pile[j] = swap
	return deck


## Draws up to `count` Goobs from the top into the hand. Stops when the pile
## is empty, or when the next Goob would make the hand bigger than HAND_MAX:
## those Goobs stay on top of the deck (slice §4). Returns the Goobs drawn.
func draw(count: int) -> Array[GoobDefinition]:
	var drawn: Array[GoobDefinition] = []
	for i in count:
		if draw_pile.is_empty() or hand.size() >= HAND_MAX:
			break
		var goob: GoobDefinition = draw_pile.pop_back()
		add(goob)
		drawn.append(goob)
	return drawn


## True when a draw of `count` would be cut short by the hand cap (not by an
## empty pile): the "Hand full" case.
func draw_blocked_by_hand(count: int) -> bool:
	return mini(count, draw_pile.size()) > HAND_MAX - hand.size()


## Removes and returns the hand Goob at `index`, or null if out of range.
func take(index: int) -> GoobDefinition:
	if index < 0 or index >= hand.size():
		return null
	if index < hand_drawn_at.size():
		hand_drawn_at.remove_at(index)
	return hand.pop_at(index)


## Puts `goob` at the end of the hand, drawn this turn (no hand cap check).
func add(goob: GoobDefinition) -> void:
	hand.append(goob)
	hand_drawn_at.append(maxi(turns, 1))


## How many of this side's turns the hand Goob at `index` has waited (0 =
## drawn this turn: played at once), or -1 if unknown (an AI simulation's
## hand).
func held_turns(index: int) -> int:
	if hand_drawn_at.size() != hand.size() or index < 0 or index >= hand.size():
		return -1
	return turns - hand_drawn_at[index]


## Moves the hand Goob at `index` to the discard pile and returns it, or null
## if out of range.
func discard(index: int) -> GoobDefinition:
	var goob := take(index)
	if goob != null:
		discard_pile.append(goob)
	return goob


## True while this side still has a Goob to play now or later.
func has_goobs() -> bool:
	return not hand.is_empty() or not draw_pile.is_empty()
