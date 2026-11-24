class_name OpponentAI
extends RefCounted
## M6c opponent (Sean, 2026-11-22 AI grill): a fair teacher that always makes
## the strongest play it can see, one move ahead.
##
## Every (hand Goob, legal column) pair is simulated with its effect; random
## effects are averaged over all their outcomes, weighted by their chance
## (TurnLoop.play_results, M6e move Goobs included). Each resulting board is scored:
##   1. its own four wins; a player four (or a mutual four) is avoided,
##   2. leaving the player an immediate winning drop is nearly as bad
##      (this is the block, and "never play under the player's winning cell"),
##   3. its own threes/twos with room score up, the player's score down,
##   4. a small centre bias.
## Greedy earns a little for the Goobs it would draw. Among plays within
## TIE_EPSILON of the best it prefers a Vanilla (specials are saved when they
## gain nothing), then picks at random. It sees only the board, its own hand
## and its own deck count — never the player's hand or any deck order.
## Stateless; `rng` is injected for determinism.

const WIN := 1000000.0
const LOSE := -1000000.0
const MUTUAL_FOUR := -50000.0
const PLAYER_THREAT := -100000.0
const OWN_THREE := 50.0
const OWN_TWO := 5.0
const PLAYER_THREE := -60.0
const PLAYER_TWO := -5.0
const CENTRE := 3.0
const DRAW_VALUE := 4.0
## Turns of extra Goobs a Generous / Plentiful is expected to give (M6e Draw).
const DRAW_EFFECT_TURNS := 2
## Flat worth of a tech Goob's window or lock (M6e Tech); Stifling and a
## steal count as one Goob (DRAW_VALUE).
const TECH_VALUE := 2.0
const TIE_EPSILON := 0.5
## "Close" choice: the runner-up is within this much of the best (think delay).
const CLOSE_MARGIN := 10.0

const _O := BoardState.CellOwner.OPPONENT
const _P := BoardState.CellOwner.PLAYER
const _DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]


## The opponent's move: {column, hand_index, blocking, close}. column = -1 when
## the board is full or the hand is empty. `blocking` = the player had an
## immediate winning drop before this move; `close` = a near-equal runner-up.
## Does not mutate `board` or `hand`. `goobs`: the board's cell ->
## GoobDefinition map (TurnLoop.cell_goobs()), so Goobs that act while on
## the board (Bouncy, Slippery, Springy, Lopsided, Tipsy) are simulated.
static func choose_move(board: BoardState, hand: Array[GoobDefinition], deck_count: int, rng: RandomNumberGenerator, goobs: Dictionary = {}, piles: Dictionary = {}, state: Dictionary = {}) -> Dictionary:
	var move := {"column": -1, "hand_index": -1, "blocking": false, "close": false}
	var legal: Array[int] = []
	var locked: Array = state.get("locked", []) # Territorial (M6e Tech)
	for column in TurnLoop.open_columns(board):
		if not column in locked:
			legal.append(column)
	if legal.is_empty() or hand.is_empty():
		return move
	move["blocking"] = not winning_drops(board, _P, goobs).is_empty()
	var scored: Array[Dictionary] = []
	var seen_types: Dictionary = {}
	for i in hand.size():
		var goob := hand[i]
		var key := goob.id if goob.id != "" else str(goob.effect_type)
		if seen_types.has(key):
			continue
		seen_types[key] = true
		for column in legal:
			var value := _play_value(board, goob, column, hand.size(), deck_count, goobs, piles, state)
			scored.append({"column": column, "hand_index": i, "value": value,
				"vanilla": goob.effect_type == GoobDefinition.EffectType.NONE})
	var best := -INF
	for s in scored:
		best = maxf(best, s["value"])
	var top: Array[Dictionary] = []
	var top_vanilla: Array[Dictionary] = []
	var runner_up := -INF
	for s in scored:
		if s["value"] >= best - TIE_EPSILON:
			top.append(s)
			if s["vanilla"]:
				top_vanilla.append(s)
		else:
			runner_up = maxf(runner_up, s["value"])
	var pool := top_vanilla if not top_vanilla.is_empty() else top
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	move["column"] = pick["column"]
	move["hand_index"] = pick["hand_index"]
	# Close = more than one distinct column ties, or the runner-up is near.
	var columns: Dictionary = {}
	for s in top:
		columns[s["column"]] = true
	move["close"] = absf(best) < WIN * 0.5 and (columns.size() > 1 or best - runner_up <= CLOSE_MARGIN)
	return move


## Column only, for a hand of plain Goobs (M3 behaviour; tests).
static func choose_column(board: BoardState, rng: RandomNumberGenerator) -> int:
	var hand: Array[GoobDefinition] = [TurnLoop.VANILLA]
	return choose_move(board, hand, 0, rng)["column"]


## Expected score of playing `goob` into `column`. `state`: hands and discard
## piles (TurnLoop.sim_state) for the discard Goobs (M6e).
static func _play_value(board: BoardState, goob: GoobDefinition, column: int, hand_size: int, deck_count: int, goobs: Dictionary = {}, piles: Dictionary = {}, state: Dictionary = {}) -> float:
	var total := 0.0
	var weights := 0.0
	for result in TurnLoop.play_results(board, goobs, goob, column, _O, 48, piles, state):
		total += score_board(result["board"], result["goobs"]) * result["weight"]
		weights += result["weight"]
	var value := total / weights
	# Nostalgic / Mocking (M6e): flat values for the Goob it becomes.
	var as_goob := goob
	if goob.effect_type == GoobDefinition.EffectType.COPY_OWN or goob.effect_type == GoobDefinition.EffectType.COPY_ENEMY:
		as_goob = TurnLoop.copy_source(goob.effect_type, _O, state.get("last_played", {}))
	if state.get("stifles", {}).get(_O, 0) > 0:
		# Stifled (M6e Tech): no landing effect, but an ongoing one still works.
		# A stifled Nostalgic / Mocking copies nothing.
		if goob.effect_type in GoobDefinition.PASSIVE_EFFECTS:
			value += _draw_effect_value(goob, deck_count, state) + _tech_value(board, goob, goobs, state)
		return value
	if as_goob.effect_type == GoobDefinition.EffectType.DRAW_TWO:
		var room := Deck.HAND_MAX - (hand_size - 1)
		value += DRAW_VALUE * mini(mini(TurnLoop.GREEDY_DRAW, deck_count), room)
	value += _draw_effect_value(as_goob, deck_count, state)
	value += _tech_value(board, as_goob, goobs, state)
	if state.has("hands"):
		value += _hand_value(board, as_goob, hand_size - 1, deck_count, state, goobs)
	return value


## Draw Goobs (M6e Draw), flat values: Jinxing costs the player one Goob;
## Generous and Plentiful stay on the board for a few turns' worth of Goobs.
static func _draw_effect_value(goob: GoobDefinition, deck_count: int, state: Dictionary) -> float:
	match goob.effect_type:
		GoobDefinition.EffectType.JINX:
			return DRAW_VALUE if state.get("their_deck", 1) > 0 else 0.0
		GoobDefinition.EffectType.GENEROUS, GoobDefinition.EffectType.DRAW_ECHO:
			return DRAW_VALUE * mini(DRAW_EFFECT_TURNS, deck_count)
	return 0.0


## Tech Goobs (M6e Tech), flat values: Steadfast, Loyal, Territorial and
## Hoarding a little; Stifling one Goob; Thieving one Goob when an enemy
## Goob has something to steal. Stalwart and Inspiring are simulated.
static func _tech_value(board: BoardState, goob: GoobDefinition, goobs: Dictionary, _state: Dictionary) -> float:
	match goob.effect_type:
		GoobDefinition.EffectType.STEADFAST, GoobDefinition.EffectType.LOYAL, GoobDefinition.EffectType.TERRITORIAL, GoobDefinition.EffectType.HOARDING:
			return TECH_VALUE
		GoobDefinition.EffectType.STIFLE:
			return DRAW_VALUE
		GoobDefinition.EffectType.STEAL:
			for cell: Vector2i in goobs:
				var other: GoobDefinition = goobs[cell]
				if board.get_owner(cell.x, cell.y) != _P or other == null:
					continue
				var armed := other.has_meta(&"armed_by") and (other.effect_type == GoobDefinition.EffectType.DESTROY_LANDER or other.effect_type == GoobDefinition.EffectType.DESTROY_LATER)
				if armed or other.effect_type in GoobDefinition.STEALABLE_EFFECTS:
					return DRAW_VALUE
	return 0.0


## Discard Goobs (M6e): each Goob a hand gains or loses is worth DRAW_VALUE
## (destroys and Thrifty are simulated). `left`: its hand after the play.
static func _hand_value(board: BoardState, goob: GoobDefinition, left: int, deck_count: int, state: Dictionary, goobs: Dictionary = {}) -> float:
	var theirs: int = state["hands"].get(_P, []).size()
	# Hoarding (M6e Tech): a hand under it can't be discarded, so the Goob
	# fizzles (its own costs too).
	if goob.effect_type == GoobDefinition.EffectType.DISCARD_ENEMY and _owns_hoarding(board, goobs, _P):
		return 0.0
	if goob.effect_type != GoobDefinition.EffectType.DISCARD_ENEMY and _owns_hoarding(board, goobs, _O):
		return 0.0
	match goob.effect_type:
		GoobDefinition.EffectType.DISCARD_ENEMY:
			return DRAW_VALUE if theirs > 0 else 0.0
		GoobDefinition.EffectType.DISCARD_DESTROY_ENEMY:
			var enemies := false
			for c in BoardState.COLUMNS:
				for r in BoardState.ROWS:
					enemies = enemies or board.get_owner(c, r) == _P
			return -2.0 * DRAW_VALUE if left >= 2 and enemies else 0.0
		GoobDefinition.EffectType.DISCARD_DESTROY:
			return -DRAW_VALUE if left >= 1 else 0.0
		GoobDefinition.EffectType.DISCARD_HAND:
			# A weak (small) hand is worth trading for the extra draws.
			return DRAW_VALUE * (mini(TurnLoop.RECKLESS_DRAW, deck_count) - left)
	return 0.0


static func _owns_hoarding(board: BoardState, goobs: Dictionary, side: BoardState.CellOwner) -> bool:
	for cell: Vector2i in goobs:
		var goob: GoobDefinition = goobs[cell]
		if goob != null and goob.effect_type == GoobDefinition.EffectType.HOARDING and board.get_owner(cell.x, cell.y) == side:
			return true
	return false


## Score of a board after the opponent's play (win check after effects).
## `goobs`: its cell -> GoobDefinition map (Bouncy / Slippery threats).
static func score_board(board: BoardState, goobs: Dictionary = {}) -> float:
	match board.get_outcome():
		BoardState.Outcome.OPPONENT_WIN:
			return WIN
		BoardState.Outcome.PLAYER_WIN:
			return LOSE
		BoardState.Outcome.DRAW:
			return MUTUAL_FOUR
	var score := 0.0
	if not winning_drops(board, _P, goobs).is_empty():
		score += PLAYER_THREAT
	for row in BoardState.ROWS:
		for column in BoardState.COLUMNS:
			for dir in _DIRECTIONS:
				score += _window_score(board, column, row, dir)
	for row in BoardState.ROWS:
		if board.get_owner(3, row) == _O:
			score += CENTRE
	return score


static func _window_score(board: BoardState, column: int, row: int, dir: Vector2i) -> float:
	var own := 0
	var theirs := 0
	for i in BoardState.CONNECT:
		var c := column + dir.x * i
		var r := row + dir.y * i
		if not board.in_bounds(c, r):
			return 0.0
		match board.get_owner(c, r):
			_O:
				own += 1
			_P:
				theirs += 1
	if own > 0 and theirs > 0:
		return 0.0
	if own == 3:
		return OWN_THREE
	if own == 2:
		return OWN_TWO
	if theirs == 3:
		return PLAYER_THREE
	if theirs == 2:
		return PLAYER_TWO
	return 0.0


## Columns where a plain drop by `side` makes its four right now. With
## `goobs` (cell -> GoobDefinition), a drop onto a Bouncy / Slippery is
## simulated: it counts when any way it can go makes the four.
static func winning_drops(board: BoardState, side: BoardState.CellOwner, goobs: Dictionary = {}) -> Array[int]:
	var found: Array[int] = []
	for column in TurnLoop.open_columns(board):
		if _drop_moves(board, goobs, column):
			for result in TurnLoop.play_results(board, goobs, TurnLoop.VANILLA, column, side):
				var after: BoardState = result["board"]
				if not after.find_winning_line(side).is_empty():
					found.append(column)
					break
			continue
		var trial := board.copy()
		trial.drop(column, side)
		if not trial.find_winning_line(side).is_empty():
			found.append(column)
	return found


## Whether a Goob dropped into `column` lands on a Bouncy or Slippery, or on
## an armed Spiteful (which destroys it; M6e Destroy).
static func _drop_moves(board: BoardState, goobs: Dictionary, column: int) -> bool:
	if goobs.is_empty():
		return false
	var row := board.lowest_empty_row(column) - 1
	var goob: GoobDefinition = goobs.get(Vector2i(column, row))
	if goob == null or row < 0 or board.is_empty(column, row):
		return false
	if goob.effect_type == GoobDefinition.EffectType.DESTROY_LANDER and goob.has_meta(&"armed_by"):
		return true
	return goob.effect_type == GoobDefinition.EffectType.BOUNCY or goob.effect_type == GoobDefinition.EffectType.SLIPPERY


## Number of `side`'s lines of three with the fourth cell empty (any height):
## "he makes three" for the happy portrait (Sean, 2026-11-22).
static func open_threes(board: BoardState, side: BoardState.CellOwner) -> int:
	return open_lines(board, side, 3)


## Four-cell windows holding exactly `goobs` of `side`'s Goobs and nothing
## else (the rest empty): open_lines(b, s, 2) = twos that could become threes.
## `touching`: the Goobs must sit side by side in the window (no gap), so a
## "two" is a real pair (portrait surprise; Sean, M6c playtest).
static func open_lines(board: BoardState, side: BoardState.CellOwner, goobs: int, touching := false) -> int:
	var count := 0
	for row in BoardState.ROWS:
		for column in BoardState.COLUMNS:
			for dir in _DIRECTIONS:
				var mine := 0
				var empty := 0
				var first := -1
				var last := -1
				var valid := true
				for i in BoardState.CONNECT:
					var c := column + dir.x * i
					var r := row + dir.y * i
					if not board.in_bounds(c, r):
						valid = false
						break
					var owner := board.get_owner(c, r)
					if owner == side:
						mine += 1
						if first < 0:
							first = i
						last = i
					elif owner == BoardState.CellOwner.EMPTY:
						empty += 1
				if touching and last - first != goobs - 1:
					continue
				if valid and mine == goobs and empty == BoardState.CONNECT - goobs:
					count += 1
	return count
