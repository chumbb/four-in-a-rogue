class_name Deck
extends RefCounted
## One side's Goobs in a scenario: a shuffled draw pile and a hand (slice §4
## Decks). Shuffled once when built; never reshuffled. No rendering.

const HAND_MAX := 5
const START_HAND := 3

## Draw pile; the top of the deck is the END of the array.
var draw_pile: Array[GoobDefinition] = []
## Hand in draw order (oldest first); the player's fan shows it left to right.
var hand: Array[GoobDefinition] = []


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
		hand.append(goob)
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
	return hand.pop_at(index)


## True while this side still has a Goob to play now or later.
func has_goobs() -> bool:
	return not hand.is_empty() or not draw_pile.is_empty()
