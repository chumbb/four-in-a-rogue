class_name OpponentAI
extends RefCounted
## M6c opponent (Sean, 2026-11-22 AI grill): a fair teacher that always makes
## the strongest play it can see, one move ahead.
##
## Every (hand Goob, legal column) pair is simulated with its effect; random
## effects are averaged over all their equally likely outcomes
## (TurnLoop.effect_outcomes). Each resulting board is scored:
##   1. its own four wins; a player four (or a mutual four) is avoided,
##   2. leaving the player an immediate winning drop is nearly as bad
##      (this is the block, and "never play under the player's winning cell"),
##   3. its own threes/twos with room score up, the player's score down,
##   4. a small centre bias.
## Plentiful earns a little for the Goobs it would draw. Among plays within
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
const TIE_EPSILON := 0.5
## "Close" choice: the runner-up is within this much of the best (think delay).
const CLOSE_MARGIN := 10.0

const _O := BoardState.CellOwner.OPPONENT
const _P := BoardState.CellOwner.PLAYER
const _DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]


## The opponent's move: {column, hand_index, blocking, close}. column = -1 when
## the board is full or the hand is empty. `blocking` = the player had an
## immediate winning drop before this move; `close` = a near-equal runner-up.
## Does not mutate `board` or `hand`.
static func choose_move(board: BoardState, hand: Array[GoobDefinition], deck_count: int, rng: RandomNumberGenerator) -> Dictionary:
	var move := {"column": -1, "hand_index": -1, "blocking": false, "close": false}
	var legal := TurnLoop.open_columns(board)
	if legal.is_empty() or hand.is_empty():
		return move
	move["blocking"] = not winning_drops(board, _P).is_empty()
	var scored: Array[Dictionary] = []
	var seen_types: Dictionary = {}
	for i in hand.size():
		var goob := hand[i]
		var key := goob.id if goob.id != "" else str(goob.effect_type)
		if seen_types.has(key):
			continue
		seen_types[key] = true
		for column in legal:
			var value := _play_value(board, goob, column, hand.size(), deck_count)
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


## Expected score of playing `goob` into `column`.
static func _play_value(board: BoardState, goob: GoobDefinition, column: int, hand_size: int, deck_count: int) -> float:
	var landed := board.copy()
	var row := landed.drop(column, _O)
	var outcomes := TurnLoop.effect_outcomes(landed, goob.effect_type, Vector2i(column, row), _O)
	var total := 0.0
	for outcome in outcomes:
		total += score_board(outcome)
	var value := total / outcomes.size()
	if goob.effect_type == GoobDefinition.EffectType.DRAW_TWO:
		var room := Deck.HAND_MAX - (hand_size - 1)
		value += DRAW_VALUE * mini(mini(TurnLoop.PLENTIFUL_DRAW, deck_count), room)
	return value


## Score of a board after the opponent's play (win check after effects).
static func score_board(board: BoardState) -> float:
	match board.get_outcome():
		BoardState.Outcome.OPPONENT_WIN:
			return WIN
		BoardState.Outcome.PLAYER_WIN:
			return LOSE
		BoardState.Outcome.DRAW:
			return MUTUAL_FOUR
	var score := 0.0
	if not winning_drops(board, _P).is_empty():
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


## Columns where a plain drop by `side` makes its four right now.
static func winning_drops(board: BoardState, side: BoardState.CellOwner) -> Array[int]:
	var found: Array[int] = []
	for column in TurnLoop.open_columns(board):
		var trial := board.copy()
		trial.drop(column, side)
		if not trial.find_winning_line(side).is_empty():
			found.append(column)
	return found


## Number of `side`'s lines of three with the fourth cell empty (any height):
## "he makes three" for the happy portrait (Sean, 2026-11-22).
static func open_threes(board: BoardState, side: BoardState.CellOwner) -> int:
	return open_lines(board, side, 3)


## Four-cell windows holding exactly `goobs` of `side`'s Goobs and nothing
## else (the rest empty): open_lines(b, s, 2) = twos that could become threes.
static func open_lines(board: BoardState, side: BoardState.CellOwner, goobs: int) -> int:
	var count := 0
	for row in BoardState.ROWS:
		for column in BoardState.COLUMNS:
			for dir in _DIRECTIONS:
				var mine := 0
				var empty := 0
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
					elif owner == BoardState.CellOwner.EMPTY:
						empty += 1
				if valid and mine == goobs and empty == BoardState.CONNECT - goobs:
					count += 1
	return count
