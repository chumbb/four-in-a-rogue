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
const GREEDY_DRAW := 2
## Reckless: extra Goobs on its owner's next turn draw (M6e Discard).
const RECKLESS_DRAW := 2
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
## Side -> extra Goobs on its next turn draw (Reckless), used up by that draw.
var _bonus_draws: Dictionary = {}
## Side -> Jinxings on its next turn draw (one Goob fewer each), used up by
## that turn start (M6e Draw).
var _jinxes: Dictionary = {}
## Goobs the current turn draw lost to Jinxing (0 = not jinxed), for the view's
## toast, and how many it then drew for (0 = no draw at all).
var last_jinx_lost := 0
## Side -> Stiflings on it: its next played Goobs have no effect (M6e Tech).
var _stifles: Dictionary = {}
## Side -> the Goob type its latest played Goob was (a Nostalgic / Mocking:
## what it became), for Nostalgic and Mocking to copy (M6e Uniquely powerful).
var _last_played: Dictionary = {}
var last_draw_count := 0
## Plentiful's draws set off by the current turn draw (effect steps with
## "drawn"), for the view to show after that draw. Reset by each turn start.
var turn_draw_steps: Array[Dictionary] = []

## What the last play's special effect did (M5), for the view:
##   kind: GoobDefinition.EffectType of the played Goob
##   cell: Vector2i where it landed; side: BoardState.CellOwner
##   fizzled: true when it had nothing to act on (Sean, 2026-11-19)
##   target: Vector2i flipped (Convincing) or destroyed (Fat) cell, and
##   target_owner: who owned it before
##   extra: Vector2i where Popular's Vanilla landed
##   drawn: Array[GoobDefinition] and hand_full: bool (Greedy, Fickle, Plentiful)
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

## Effect steps that ran at the start of the turn now in progress (same format
## as effect_steps; Smouldering, M6e Destroy), for the view to show after the
## turn banner. Reset by each new turn (a skipped turn's steps are kept).
var turn_start_steps: Array[Dictionary] = []
## The board right after the latest play, before the next turn's start
## effects changed it (the view's reactions compare against this).
var board_after_play: BoardState

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
	board_after_play = null
	board.reset()
	_cell_goobs.clear()
	_skipped_last.clear()
	_bonus_draws.clear()
	_jinxes.clear()
	_stifles.clear()
	_last_played.clear()
	turn_draw_steps = []
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
	return phase != Phase.OVER and board.is_valid_column(column) and not column_blocked(column)


## Whether the current side can't play into `column`: full, or locked by an
## enemy Territorial (M6e Tech).
func column_blocked(column: int) -> bool:
	return board.column_full(column) or column in locked_columns(current_side())


## Where a Goob played into blocked `column` at a timeout rolls to (like
## BoardState.roll_target, a locked column counts as full); -1 = board full.
func roll_target(column: int, go_right: bool) -> int:
	if not board.is_valid_column(column) or board.is_board_full():
		return -1
	var step := 1 if go_right else -1
	var c := column
	for i in BoardState.COLUMNS * 2 + 2:
		if not column_blocked(c):
			return c
		if not board.is_valid_column(c + step):
			step = -step
		c += step
	return -1


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
	var played_as := _played_as(goob, side)
	var row := _play_goob(goob, column, side, rolled_dir, _use_stifle(side))
	_last_played[side] = played_as
	_on_turn_end(side)
	board_after_play = board.copy()
	if not _check_end():
		_begin_turn(Phase.OPPONENT_TURN if phase == Phase.PLAYER_TURN else Phase.PLAYER_TURN)
	return row


## The end-of-turn win check (slice §4): a four, both fours or a full board
## ends the scenario. Returns whether it ended.
func _check_end() -> bool:
	match board.get_outcome():
		BoardState.Outcome.PLAYER_WIN:
			_finish(Result.PLAYER_WIN)
		BoardState.Outcome.OPPONENT_WIN:
			_finish(Result.OPPONENT_WIN)
		BoardState.Outcome.DRAW:
			_finish(Result.DRAW)
		_:
			if not board.is_board_full():
				return false
			_finish(Result.DRAW)
	return true


## The whole play of `goob`: it lands and resolves, then the Goobs a Spiteful
## doomed are destroyed (after their own effects; M6e Destroy). Returns the
## row it first landed in.
func _play_goob(goob: GoobDefinition, column: int, side: BoardState.CellOwner, rolled_dir: int = 0, stifled := false) -> int:
	var row := _land_and_resolve(goob, column, side, rolled_dir, stifled)
	_destroy_doomed()
	_sync_board_statuses()
	return row


## Drops `goob` for `side` into `column`; a Bouncy or Slippery Goob under it
## moves it first (M6e), then its effect resolves where it ended up. Returns
## the row it first landed in. `stifled`: its effect is cancelled (Stifling).
func _land_and_resolve(goob: GoobDefinition, column: int, side: BoardState.CellOwner, rolled_dir: int = 0, stifled := false) -> int:
	var row := board.drop(column, side)
	var cell := Vector2i(column, row)
	_cell_goobs[cell] = goob
	_check_landing(cell)
	cell = _landing_step(cell, rolled_dir)
	_resolve_effect(goob, cell, side, stifled)
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
	if not _can_move(cell):
		return cell # Stalwart / Steadfast: it stays on top
	if _effect_at(cell + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
		if dir == 0:
			var sides := _open_sides(cell)
			dir = sides[_pick(sides.size())]
		var carried := _lift(cell)
		var points: Array = []
		var to := _bounce(cell, dir, points)
		_put(to, carried)
		_record(cell, to, points)
		_check_landing(to)
		return to
	var dirs := _roll_dirs(cell)
	if dirs.is_empty():
		return cell
	return _roll(cell, dirs[_pick(dirs.size())])


## The played Goob's special effect (slice §4 roster). Random targets come
## from the scenario rng; with nothing to act on the effect fizzles. A
## `stifled` Goob's effect is cancelled (Stifling; ongoing ones still work).
func _resolve_effect(goob: GoobDefinition, cell: Vector2i, side: BoardState.CellOwner, stifled := false) -> void:
	var step := {"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false}
	effect_steps.append(step)
	last_effect = step
	if stifled:
		step["fizzled"] = true
		step["stifled"] = true
		return
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
		GoobDefinition.EffectType.DESTROY_ADJACENT, GoobDefinition.EffectType.DESTROY_RANDOM, GoobDefinition.EffectType.DESTROY_BELOW, GoobDefinition.EffectType.DESTROY_BESIDE:
			var targets := _destroy_targets(goob.effect_type, cell)
			if targets.is_empty():
				step["fizzled"] = true
				return
			_destroy_target(step, targets[_pick(targets.size())])
		GoobDefinition.EffectType.DESTROY_LANDER, GoobDefinition.EffectType.DESTROY_LATER:
			# Spiteful / Smouldering arm for the side that played them; they
			# act later (a landing, or that side's next turn start).
			_mark(cell, &"armed_by", side)
		GoobDefinition.EffectType.RESURRECT, GoobDefinition.EffectType.RETURN_DISCARD:
			# Occult: one of your destroyed Goobs drops for you into a random
			# open column, and its own on-land effect fires (Sean, 2026-11-23).
			# Thrifty: the same from your discard pile (M6e Discard).
			var pile := deck_of(side).destroyed_pile if goob.effect_type == GoobDefinition.EffectType.RESURRECT else deck_of(side).discard_pile
			var open := open_columns(board)
			if pile.is_empty() or open.is_empty():
				step["fizzled"] = true
				return
			var back: GoobDefinition = pile.pop_at(_pick(pile.size()))
			var column := open[_pick(open.size())]
			step["returned"] = back
			var row := _land_and_resolve(back, column, side)
			step["extra"] = Vector2i(column, row)
			last_effect = step
		GoobDefinition.EffectType.DISCARD_ENEMY:
			# Distracting: a random Goob from the opponent's hand.
			var enemy := enemy_of(side)
			if deck_of(enemy).hand.is_empty() or not _can_discard(enemy, 0):
				step["fizzled"] = true
				return
			step["cue"] = true
			_discard_random(enemy)
		GoobDefinition.EffectType.DISCARD_DRAW:
			# Fickle: an empty hand fizzles, the draw too (Sean, 2026-11-23).
			var deck := deck_of(side)
			if deck.hand.is_empty() or not _can_discard(side, 0):
				step["fizzled"] = true
				return
			step["cue"] = true
			_discard_random(side)
			var hand_full := deck.draw_blocked_by_hand(1)
			var drawn := deck.draw(1)
			if not drawn.is_empty() or hand_full:
				effect_steps.append({"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false, "drawn": drawn, "hand_full": hand_full})
			effect_steps.append_array(_echo_draws(side, drawn.size()))
		GoobDefinition.EffectType.DISCARD_DESTROY_ENEMY, GoobDefinition.EffectType.DISCARD_DESTROY:
			# Ruthless (cost 2) / Desperate (cost 1): the cost is paid in full or
			# the whole effect fizzles, nothing discarded (Sean, 2026-11-23).
			var cost := 2 if goob.effect_type == GoobDefinition.EffectType.DISCARD_DESTROY_ENEMY else 1
			if deck_of(side).hand.size() < cost or not _can_discard(side, 0) or _discard_destroy_targets(goob.effect_type, cell, side).is_empty():
				step["fizzled"] = true
				return
			step["cue"] = true
			for i in cost:
				_discard_random(side)
			# Picked after the discards (a Defiant may have dropped meanwhile).
			var hit := {"kind": goob.effect_type, "cell": cell, "side": side, "fizzled": false}
			effect_steps.append(hit)
			last_effect = hit
			var targets := _discard_destroy_targets(goob.effect_type, cell, side)
			if targets.is_empty():
				hit["fizzled"] = true
				return
			_destroy_target(hit, targets[_pick(targets.size())])
		GoobDefinition.EffectType.DISCARD_HAND:
			# Reckless: every hand Goob, then +2 on your next turn draw (also
			# with an empty hand). Hoarding: nothing discarded, no +2 (Sean,
			# 2026-11-24).
			if not _can_discard(side, 0):
				step["fizzled"] = true
				return
			step["cue"] = true
			var deck := deck_of(side)
			for i in range(deck.hand.size() - 1, -1, -1):
				_discard(side, i)
			_bonus_draws[side] = _bonus_draws.get(side, 0) + RECKLESS_DRAW
			_sync_bonus_status(side)
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			var open := open_columns(board)
			if open.is_empty():
				step["fizzled"] = true
				return
			var column := open[_pick(open.size())]
			var row := board.drop(column, side)
			_cell_goobs[Vector2i(column, row)] = VANILLA
			step["extra"] = Vector2i(column, row)
			_check_landing(Vector2i(column, row))
			# Landing on a Bouncy / Slippery moves it too (Sean, 2026-11-23).
			_landing_step(Vector2i(column, row))
		GoobDefinition.EffectType.DRAW_TWO:
			# Greedy (was Plentiful until M6e Draw).
			var deck := deck_of(side)
			var hand_full := deck.draw_blocked_by_hand(GREEDY_DRAW)
			var drawn := deck.draw(GREEDY_DRAW)
			step["drawn"] = drawn
			step["hand_full"] = hand_full
			# Nothing drawn and not a full hand = an empty deck: fizzle.
			step["fizzled"] = drawn.is_empty() and not hand_full
			effect_steps.append_array(_echo_draws(side, drawn.size()))
		GoobDefinition.EffectType.JINX:
			# Jinxing: the opponent's next turn draw gives one Goob fewer;
			# copies add up on that one turn (Sean, 2026-11-23).
			var enemy := enemy_of(side)
			if deck_of(enemy).draw_pile.is_empty():
				step["fizzled"] = true
				return
			step["cue"] = true
			_jinxes[enemy] = _jinxes.get(enemy, 0) + 1
			_sync_jinx_status(enemy)
		GoobDefinition.EffectType.STEADFAST, GoobDefinition.EffectType.LOYAL:
			# Tech (M6e): your Goobs can't be moved / destroyed until the end
			# of the opponent's next turn; another copy restarts the window.
			step["cue"] = true
			_protect(side, goob.effect_type)
		GoobDefinition.EffectType.TERRITORIAL:
			step["cue"] = true
			_lock_column(enemy_of(side), cell.x)
		GoobDefinition.EffectType.STIFLE:
			step["cue"] = true
			var enemy := enemy_of(side)
			_stifles[enemy] = _stifles.get(enemy, 0) + 1
			_sync_stifle_status(enemy)
		GoobDefinition.EffectType.INSPIRE:
			# A random adjacent friendly Goob's landing effect fires again, for
			# you, from its cell (Sean, 2026-11-24).
			var targets := _inspire_targets(cell, side)
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_pick(targets.size())]
			step["inspired"] = target
			_resolve_effect(_cell_goobs[target], target, side)
			last_effect = step
		GoobDefinition.EffectType.STEAL:
			# Thieving: a random enemy Goob's ongoing effect becomes its own;
			# the target turns plain. Nothing fires now (Sean, 2026-11-24).
			var targets := _steal_targets(side)
			if targets.is_empty():
				step["fizzled"] = true
				return
			var target := targets[_pick(targets.size())]
			step["stolen_from"] = target
			step["stolen_name"] = _cell_goobs[target].display_name
			_steal(target, cell, side)
		GoobDefinition.EffectType.SHIFT, GoobDefinition.EffectType.SINK, GoobDefinition.EffectType.BOUNCE_TOPS:
			# Uniquely powerful (M6e): the only effects that take Goobs off the
			# board; those count as destroyed (Sean, 2026-11-24).
			step["motions"] = []
			_motions = step["motions"]
			step["fallen"] = []
			match goob.effect_type:
				GoobDefinition.EffectType.SHIFT:
					var dir: int = [-1, 1][_pick(2)]
					step["dir"] = dir
					_shift(dir, step)
				GoobDefinition.EffectType.SINK:
					_sink(step)
				_:
					_bounce_tops()
			step["fizzled"] = _motions.is_empty()
			_settle()
		GoobDefinition.EffectType.COPY_OWN, GoobDefinition.EffectType.COPY_ENEMY:
			# Nostalgic / Mocking become the last Goob that side played: its
			# landing effect fires and its passives stay (Sean, 2026-11-24).
			var source := copy_source(goob.effect_type, side, _last_played)
			_become(cell, source)
			if source.effect_type == GoobDefinition.EffectType.NONE:
				step["fizzled"] = true # nothing to copy, or a plain Goob
				return
			step["cue"] = true
			step["copied"] = source.display_name
			_resolve_effect(_cell_goobs[cell], cell, side)
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
		deck_of(owner).destroyed_pile.append(base_of(goob))
	_collapse_goobs(cell.x, cell.y)
	# The lowest Goob that fell landed on something new (the rest rode down).
	_check_landing(cell)


# --- Destroy effects (M6e; Sean, 2026-11-23: vault Special Goobs "M6e Destroy
# rules"). Per-Goob state (an armed Spiteful / Smouldering, a doomed lander)
# lives in metadata on a copy of the cell's GoobDefinition, swapped in
# copy-on-write, so it moves with the Goob and play_results' simulations never
# touch the real board's state. base_of() gives the plain definition back.

const _MAX_DESTROYS := 64


## The plain definition behind a marked copy (or `goob` itself).
static func base_of(goob: GoobDefinition) -> GoobDefinition:
	if goob == null:
		return null
	return goob.get_meta(&"base", goob)


## Sets (or with null, clears) per-Goob state `key` on the Goob in `cell`.
func _mark(cell: Vector2i, key: StringName, value: Variant) -> void:
	var copy := _own_copy(cell)
	if copy == null:
		return
	if value == null:
		copy.remove_meta(key)
	else:
		copy.set_meta(key, value)


## Swaps a fresh copy of the Goob in `cell` (its state kept) into the board and
## returns it to change (copy-on-write); null if the cell has no Goob.
func _own_copy(cell: Vector2i) -> GoobDefinition:
	var goob: GoobDefinition = _cell_goobs.get(cell)
	if goob == null:
		return null
	var copy := goob.duplicate() as GoobDefinition
	for k in goob.get_meta_list():
		copy.set_meta(k, goob.get_meta(k))
	copy.set_meta(&"base", base_of(goob))
	_cell_goobs[cell] = copy
	return copy


## The side an armed Spiteful / Smouldering in `cell` acts for (EMPTY = none).
func armed_side(cell: Vector2i) -> BoardState.CellOwner:
	var goob: GoobDefinition = _cell_goobs.get(cell)
	if goob == null or board.is_empty(cell.x, cell.y):
		return BoardState.CellOwner.EMPTY
	return goob.get_meta(&"armed_by", BoardState.CellOwner.EMPTY)


## Whether `cell` holds an armed Spiteful.
func _armed_spiteful(cell: Vector2i) -> bool:
	return _effect_at(cell) == GoobDefinition.EffectType.DESTROY_LANDER and armed_side(cell) != BoardState.CellOwner.EMPTY


## A Goob at `at` lands on top of an armed Spiteful: the Spiteful is spent
## (it acts once). Returns whether it was there.
func _spite_under(at: Vector2i) -> bool:
	var below := at + Vector2i(0, -1)
	if below.y < 0 or not board.in_bounds(below.x, below.y) or not _armed_spiteful(below):
		return false
	_mark(below, &"armed_by", null)
	return true


## The Goob in `cell` just landed (played, dropped, rolled, bounced or fell
## onto what is under it): on an armed Spiteful it is doomed, destroyed at the
## end of the play (after its own effect; Sean, 2026-11-23).
func _check_landing(cell: Vector2i) -> void:
	if board.in_bounds(cell.x, cell.y) and not board.is_empty(cell.x, cell.y) and _spite_under(cell):
		_mark(cell, &"doomed", true)


## Cells the destroy effect `kind` of a Goob in `cell` can pick from.
func _destroy_targets(kind: GoobDefinition.EffectType, cell: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	match kind:
		GoobDefinition.EffectType.DESTROY_ADJACENT:
			targets = neighbours(board, cell, BoardState.CellOwner.EMPTY)
		GoobDefinition.EffectType.DESTROY_RANDOM:
			# Volatile: any Goob on the board, itself included.
			for c in BoardState.COLUMNS:
				for r in BoardState.ROWS:
					if not board.is_empty(c, r):
						targets.append(Vector2i(c, r))
		GoobDefinition.EffectType.DESTROY_BELOW:
			if cell.y > 0 and not board.is_empty(cell.x, cell.y - 1):
				targets.append(cell + Vector2i(0, -1))
		GoobDefinition.EffectType.DESTROY_BESIDE:
			# Brawling: one random side; only one occupied → that one.
			for dir: int in [-1, 1]:
				var at := cell + Vector2i(dir, 0)
				if board.get_owner(at.x, at.y) != BoardState.CellOwner.EMPTY:
					targets.append(at)
	return targets


## Whether the Goob in `cell` can be destroyed: not a Stalwart, nor a Goob of
## a side under Loyal (M6e Tech).
func _can_destroy(cell: Vector2i) -> bool:
	if _effect_at(cell) == GoobDefinition.EffectType.STALWART:
		return false
	return not has_status(&"loyal", board.get_owner(cell.x, cell.y))


## Whether the Goob in `cell` can be moved sideways (pushes, rolls, bounces):
## not a Stalwart, nor a Goob of a side under Steadfast (M6e Tech). Gravity
## always applies.
func _can_move(cell: Vector2i) -> bool:
	if _effect_at(cell) == GoobDefinition.EffectType.STALWART:
		return false
	return not has_status(&"steadfast", board.get_owner(cell.x, cell.y))


## Destroys `target` for `step` (target, target_owner, fell = how many Goobs
## above it fell); the falls' chains (Lopsided / Tipsy, landing on a Bouncy /
## Slippery) follow as their own step. A Goob that can't be destroyed wastes
## the effect (fizzle).
func _destroy_target(step: Dictionary, target: Vector2i) -> void:
	step["target"] = target
	step["target_owner"] = board.get_owner(target.x, target.y)
	if not _can_destroy(target):
		step["fizzled"] = true
		return
	var height := _column_height(target.x)
	destroy_at(target)
	var fell: Array[Vector2i] = []
	for r in range(target.y, height - 1):
		fell.append(Vector2i(target.x, r))
	step["fell"] = fell.size()
	_roll_fallen(fell)


## Destroys every doomed Goob (a Spiteful's lander), bottom to top, each as a
## DESTROY_LANDER step from the Spiteful under it; Goobs falling onto another
## armed Spiteful are doomed in turn.
func _destroy_doomed() -> void:
	for i in _MAX_DESTROYS:
		var at := _find_cell(func(cell: Vector2i) -> bool:
			var goob: GoobDefinition = _cell_goobs.get(cell)
			return goob != null and goob.has_meta(&"doomed"))
		if at.x < 0:
			return
		_mark(at, &"doomed", null)
		var source := at + Vector2i(0, -1)
		if _effect_at(source) != GoobDefinition.EffectType.DESTROY_LANDER:
			source = at # the Spiteful went elsewhere: the Goob just bursts
		var step := {"kind": GoobDefinition.EffectType.DESTROY_LANDER, "cell": source, "side": board.get_owner(source.x, source.y), "fizzled": false}
		effect_steps.append(step)
		_destroy_target(step, at)


## The first occupied cell (bottom to top, left to right) where `test` holds;
## (-1, -1) if none.
func _find_cell(test: Callable) -> Vector2i:
	for r in BoardState.ROWS:
		for c in BoardState.COLUMNS:
			var cell := Vector2i(c, r)
			if not board.is_empty(c, r) and test.call(cell):
				return cell
	return Vector2i(-1, -1)


## Smouldering: at the start of the turn of the side that played it, each one
## armed for `side` destroys a random adjacent Goob around where it is now.
func _smoulder(side: BoardState.CellOwner) -> void:
	for i in _MAX_DESTROYS:
		var at := _find_cell(func(cell: Vector2i) -> bool:
			return _effect_at(cell) == GoobDefinition.EffectType.DESTROY_LATER and armed_side(cell) == side)
		if at.x < 0:
			break
		_mark(at, &"armed_by", null)
		var step := {"kind": GoobDefinition.EffectType.DESTROY_LATER, "cell": at, "side": side, "fizzled": false}
		effect_steps.append(step)
		var targets := neighbours(board, at, BoardState.CellOwner.EMPTY)
		if targets.is_empty():
			step["fizzled"] = true
			continue
		_destroy_target(step, targets[_pick(targets.size())])
	_destroy_doomed()


## Status pills for the armed Spiteful / Smouldering Goobs on the board, one
## per kind and side (tap = which columns).
func _sync_board_statuses() -> void:
	for id: StringName in [&"spiteful", &"smouldering", &"generous", &"plentiful", &"hoarding"]:
		for side in [BoardState.CellOwner.PLAYER, BoardState.CellOwner.OPPONENT]:
			remove_status(id, side)
	for side in [BoardState.CellOwner.PLAYER, BoardState.CellOwner.OPPONENT]:
		var spiteful: Array[String] = []
		var smouldering: Array[String] = []
		for c in BoardState.COLUMNS:
			for r in BoardState.ROWS:
				var cell := Vector2i(c, r)
				if armed_side(cell) != side:
					continue
				if _effect_at(cell) == GoobDefinition.EffectType.DESTROY_LANDER:
					spiteful.append(str(c + 1))
				elif _effect_at(cell) == GoobDefinition.EffectType.DESTROY_LATER:
					smouldering.append(str(c + 1))
		var whose := "your" if side == BoardState.CellOwner.PLAYER else "his"
		var generous := _owned_columns(GoobDefinition.EffectType.GENEROUS, side)
		var plentiful := _owned_columns(GoobDefinition.EffectType.DRAW_ECHO, side)
		if not generous.is_empty():
			add_status(&"generous", side, "Generous +%d" % generous.size(), "Generous (%s): %s turn draw gets %d extra Goob%s." % [_columns_text(generous), whose, generous.size(), "" if generous.size() == 1 else "s"], -1)
		if not plentiful.is_empty():
			var who := "you draw a Goob whenever he draws one" if side == BoardState.CellOwner.PLAYER else "he draws a Goob whenever you draw one"
			add_status(&"plentiful", side, "Plentiful", "Plentiful (%s): %s." % [_columns_text(plentiful), who], -1)
		var hoarding := _owned_columns(GoobDefinition.EffectType.HOARDING, side)
		if not hoarding.is_empty():
			add_status(&"hoarding", side, "Hoarding", "Hoarding (%s): %s Goobs can't be discarded." % [_columns_text(hoarding), whose], -1)
		if not spiteful.is_empty():
			add_status(&"spiteful", side, "Spiteful", "Spiteful (%s): the next Goob that lands on it is destroyed." % _columns_text(spiteful), -1)
		if not smouldering.is_empty():
			add_status(&"smouldering", side, "Smouldering", "Smouldering (%s): destroys a random adjacent Goob at the start of %s next turn." % [_columns_text(smouldering), whose], -1)


## Columns (1-based, as text) of the Goobs with `kind` that `side` owns now,
## one entry per Goob.
func _owned_columns(kind: GoobDefinition.EffectType, side: BoardState.CellOwner) -> Array[String]:
	var columns: Array[String] = []
	for cell in _owned_cells(kind, side):
		columns.append(str(cell.x + 1))
	return columns


## Cells of the Goobs with `kind` that `side` owns now (a flip moves them).
func _owned_cells(kind: GoobDefinition.EffectType, side: BoardState.CellOwner) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var cell := Vector2i(c, r)
			if _effect_at(cell) == kind and board.get_owner(c, r) == side:
				cells.append(cell)
	return cells


## Plentiful: `drawer` just drew `count` Goobs, so each Plentiful its opponent
## owns draws that many for its owner (hand cap 5). These draws never set off
## another Plentiful (Sean, 2026-11-23). One step per Plentiful that drew; a
## full hand or empty deck draws nothing, silently (no "Hand full" shake on
## every opponent draw).
func _echo_draws(drawer: BoardState.CellOwner, count: int) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if count <= 0:
		return steps
	var owner := enemy_of(drawer)
	var deck := deck_of(owner)
	for cell in _owned_cells(GoobDefinition.EffectType.DRAW_ECHO, owner):
		var hand_full := deck.draw_blocked_by_hand(count)
		var drawn := deck.draw(count)
		if drawn.is_empty():
			break # full hand or empty deck
		steps.append({"kind": GoobDefinition.EffectType.DRAW_ECHO, "cell": cell, "side": owner, "fizzled": false, "drawn": drawn, "hand_full": hand_full})
	return steps


static func _columns_text(columns: Array[String]) -> String:
	return ("column " if columns.size() == 1 else "columns ") + ", ".join(columns)


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
	if not _can_move(cell):
		return false # a wall for the Goobs rolling into it
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
	# Resting on an armed Spiteful anywhere along the way counts as landing
	# on it (like a Bouncy; M6e Destroy).
	var doomed := false
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
			doomed = _spite_under(at) or doomed
			if _effect_at(at + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
				at = _bounce(at, dir, points, cell)
				break
			continue
		if _effect_at(Vector2i(next, at.y)) == GoobDefinition.EffectType.SPRINGY:
			at = _hop(at, next, dir, points, cell)
			if _effect_at(at + Vector2i(0, -1)) == GoobDefinition.EffectType.BOUNCY:
				at = _bounce(at, _last_dir, points, cell)
		break
	if at != cell:
		doomed = _spite_under(at) or doomed
	_put(at, carried)
	_record(cell, at, points)
	if doomed:
		_mark(at, &"doomed", true)
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
		var below_drop := 0 # how far the Goob under it fell this pass
		for r in BoardState.ROWS:
			if board.is_empty(c, r):
				continue
			var drop := r - write
			if drop > 0:
				var from := Vector2i(c, r)
				var to := Vector2i(c, write)
				_put(to, _lift(from))
				_record(from, to, [{"at": to, "how": &"fall"}], _group)
				moved[from] = to
				# Falling exactly as far as the Goob under it = riding it
				# down, not landing on it.
				if drop != below_drop:
					_check_landing(to)
			below_drop = drop
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


## Discards `side`'s hand Goob at `index` (debug panel, tests); returns it
## (null if out of range). A Defiant drops instead (_discard).
func discard_from(side: BoardState.CellOwner, index: int) -> GoobDefinition:
	var keep := last_effect
	var goob := _discard(side, index)
	if goob != null:
		last_effect = keep if not keep.is_empty() else effect_steps[0]
		_destroy_doomed() # a Defiant that landed on an armed Spiteful
		_sync_board_statuses()
	return goob


# --- Discard effects (M6e; Sean, 2026-11-23: vault Special Goobs "M6e Discard
# rules"). Every discard is random and goes through _discard, so a Defiant is
# always played instead.

## Discards `side`'s hand Goob at `index` as a discard step ({discarded, index,
## side}; `played` = Vector2i where a Defiant dropped instead). A Defiant drops
## for its owner into a random open column (no turn used; landings apply);
## with the board full it goes to the pile. Returns it (null = nothing).
func _discard(side: BoardState.CellOwner, index: int) -> GoobDefinition:
	var deck := deck_of(side)
	if index < 0 or index >= deck.hand.size() or not _can_discard(side, index):
		return null
	var goob := deck.take(index)
	var step := {"kind": GoobDefinition.EffectType.NONE, "discarded": goob, "index": index, "side": side, "cell": Vector2i(-1, -1), "fizzled": false}
	effect_steps.append(step)
	if goob.effect_type == GoobDefinition.EffectType.DEFIANT:
		var open := open_columns(board)
		if not open.is_empty():
			var column := open[_pick(open.size())]
			var keep := last_effect
			var row := _land_and_resolve(goob, column, side)
			last_effect = keep
			step["played"] = Vector2i(column, row)
			return goob
	deck.discard_pile.append(goob)
	return goob


## Discards a random Goob from `side`'s hand (none if empty). While the AI
## enumerates outcomes, a hand without a Defiant always takes index 0 (which
## Goob goes doesn't change the board).
func _discard_random(side: BoardState.CellOwner) -> void:
	var hand := deck_of(side).hand
	if hand.is_empty():
		return
	var defiant := hand.any(func(g: GoobDefinition) -> bool: return g.effect_type == GoobDefinition.EffectType.DEFIANT)
	_discard(side, 0 if _scripted and not defiant else _pick(hand.size()))


## Whether `side`'s hand Goob at `index` can be discarded: not while `side`
## owns a Hoarding on the board (M6e Tech; also its own discard costs).
func _can_discard(side: BoardState.CellOwner, _index: int) -> bool:
	return _owned_cells(GoobDefinition.EffectType.HOARDING, side).is_empty()


# --- Tech effects (M6e; Sean, 2026-11-24: vault Special Goobs "M6e Tech
# rules"). Windows (Steadfast, Loyal, Territorial's lock) are statuses that
# last until the end of the opponent's next turn.

## Turns (status ticks) until the end of the next turn of `side`'s opponent.
func _window_turns(side: BoardState.CellOwner) -> int:
	return 2 if current_side() == side else 3


## Steadfast / Loyal: the window for `side`'s Goobs.
func _protect(side: BoardState.CellOwner, kind: GoobDefinition.EffectType) -> void:
	var whose := "your" if side == BoardState.CellOwner.PLAYER else "his"
	var theirs := "his" if side == BoardState.CellOwner.PLAYER else "your"
	if kind == GoobDefinition.EffectType.STEADFAST:
		add_status(&"steadfast", side, "Steadfast", "Steadfast: %s Goobs can't be moved until the end of %s next turn." % [whose, theirs], _window_turns(side))
	else:
		add_status(&"loyal", side, "Loyal", "Loyal: %s Goobs can't be destroyed until the end of %s next turn." % [whose, theirs], _window_turns(side))


## Territorial: `side` can't play into `column` on its next turn.
func _lock_column(side: BoardState.CellOwner, column: int) -> void:
	var columns: Array[int] = []
	columns.assign(_lock_status_columns(side))
	if not column in columns:
		columns.append(column)
	columns.sort()
	var names: Array[String] = []
	for c in columns:
		names.append(str(c + 1))
	var who := "you can't" if side == BoardState.CellOwner.PLAYER else "he can't"
	add_status(&"territorial", side, "Locked", "Territorial: %s play in %s on the next turn." % [who, _columns_text(names)], _window_turns(enemy_of(side)))
	statuses[-1]["columns"] = columns


func _lock_status_columns(side: BoardState.CellOwner) -> Array:
	for st in statuses:
		if st["id"] == &"territorial" and st["side"] == side:
			return st.get("columns", [])
	return []


## Columns `side` can't play into (Territorial); none when every other
## column is full (the lock lifts).
func locked_columns(side: BoardState.CellOwner) -> Array[int]:
	var locked: Array[int] = []
	locked.assign(_lock_status_columns(side))
	if locked.is_empty():
		return locked
	for c in open_columns(board):
		if not c in locked:
			return locked
	locked.clear()
	return locked


## Stifling: `side`'s next played Goob has no effect; true uses one up.
func _use_stifle(side: BoardState.CellOwner) -> bool:
	if _stifles.get(side, 0) <= 0:
		return false
	_stifles[side] -= 1
	if _stifles[side] <= 0:
		_stifles.erase(side)
	_sync_stifle_status(side)
	return true


func _sync_stifle_status(side: BoardState.CellOwner) -> void:
	var count: int = _stifles.get(side, 0)
	if count <= 0:
		remove_status(&"stifled", side)
		return
	var whose := "your" if side == BoardState.CellOwner.PLAYER else "his"
	var goobs := "Goob has" if count == 1 else "%d Goobs have" % count
	add_status(&"stifled", side, "Stifled", "Stifled: %s next played %s no effect." % [whose, goobs], -1)


## Inspiring: adjacent Goobs of `side` with a landing effect.
func _inspire_targets(cell: Vector2i, side: BoardState.CellOwner) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for at in neighbours(board, cell, side):
		if not _effect_at(at) in GoobDefinition.NO_LANDING_EFFECT:
			found.append(at)
	return found


## Thieving: enemy Goobs with an ongoing effect it can take.
func _steal_targets(side: BoardState.CellOwner) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var at := Vector2i(c, r)
			if board.get_owner(c, r) == enemy_of(side) and _stealable(at):
				found.append(at)
	return found


## A passive (Bouncy, Generous, Stalwart, ...) or an armed Spiteful /
## pending Smouldering.
func _stealable(cell: Vector2i) -> bool:
	var kind := _effect_at(cell)
	if kind in GoobDefinition.STEALABLE_EFFECTS:
		return true
	var armed := kind == GoobDefinition.EffectType.DESTROY_LANDER or kind == GoobDefinition.EffectType.DESTROY_LATER
	return armed and armed_side(cell) != BoardState.CellOwner.EMPTY


## The Goob in `thief` takes the effect of the one in `target` (for `side`,
## an armed one too); `target` turns plain (still x2: its type is kept).
func _steal(target: Vector2i, thief: Vector2i, side: BoardState.CellOwner) -> void:
	var kind := _effect_at(target)
	var armed := armed_side(target) != BoardState.CellOwner.EMPTY
	var victim: GoobDefinition = _cell_goobs[target]
	var gained := _own_copy(thief)
	gained.effect_type = kind
	gained.effect_description = "Stole %s's effect: %s" % [victim.display_name, victim.effect_description]
	var lost := _own_copy(target)
	lost.effect_type = GoobDefinition.EffectType.NONE
	lost.effect_description = "Its effect was stolen."
	lost.remove_meta(&"armed_by")
	if armed:
		gained.set_meta(&"armed_by", side)


# --- Uniquely powerful effects (M6e; Sean, 2026-11-24: vault Special Goobs
# "M6e Uniquely powerful rules"). A Goob that leaves the board is destroyed
# (destroyed pile; Loyal / Stalwart keep it on). Its motion has "gone": true
# and ends on an &"off" point outside the board.

## Seismic: each row slides one column `dir`, edge-nearest first; the edge Goob
## falls off. An unmovable Goob stays, and so does a protected one at the edge;
## the Goobs pushing toward it stop beside it. One group (they move together);
## gravity follows in _settle.
func _shift(dir: int, step: Dictionary) -> void:
	_group += 1
	var group := _group
	var edge := 0 if dir < 0 else BoardState.COLUMNS - 1
	var columns: Array = range(BoardState.COLUMNS) if dir < 0 else range(BoardState.COLUMNS - 1, -1, -1)
	for r in BoardState.ROWS:
		for c: int in columns:
			var at := Vector2i(c, r)
			if board.is_empty(c, r) or not _can_move(at):
				continue
			if c == edge:
				if _can_destroy(at):
					_fall_off(at, at + Vector2i(dir, 0), group, step)
				continue
			var to := at + Vector2i(dir, 0)
			if board.is_empty(to.x, to.y):
				_put(to, _lift(at))
				_record(at, to, [{"at": to, "how": &"slide"}], group)


## Sinking: every bottom-row Goob that can be destroyed falls out (itself
## included); gravity follows in _settle.
func _sink(step: Dictionary) -> void:
	_group += 1
	var group := _group
	for c in BoardState.COLUMNS:
		var at := Vector2i(c, 0)
		if not board.is_empty(c, 0) and _can_destroy(at):
			_fall_off(at, Vector2i(c, -1), group, step)


## Takes the Goob at `at` off the board through `off` (a cell outside it):
## destroyed pile of its owner, recorded in step["fallen"] ({cell, owner}).
func _fall_off(at: Vector2i, off: Vector2i, group: int, step: Dictionary) -> void:
	var carried := _lift(at)
	var goob: GoobDefinition = carried["goob"]
	if goob != null:
		deck_of(carried["owner"]).destroyed_pile.append(base_of(goob))
	step["fallen"].append({"cell": at, "owner": carried["owner"]})
	_motions.append({"from": at, "to": off, "points": [{"at": off, "how": &"off"}], "group": group, "gone": true})


## Rowdy: column by column, left to right, the top Goob at that moment bounces
## like Bouncy's bounce (random side; edge columns inward; a full column rolls
## it from the top), then gravity and chains settle. A Goob already moved by
## this effect, or one that can't move, is skipped.
func _bounce_tops() -> void:
	for c in BoardState.COLUMNS:
		var height := _column_height(c)
		if height == 0:
			continue
		var at := Vector2i(c, height - 1)
		var goob: GoobDefinition = _cell_goobs.get(at)
		if (goob != null and goob.has_meta(&"rowdy")) or not _can_move(at):
			continue
		var sides := _open_sides(at)
		var dir := sides[_pick(sides.size())]
		_mark(at, &"rowdy", true)
		var carried := _lift(at)
		var points: Array = []
		var to := _bounce(at, dir, points)
		_put(to, carried)
		_record(at, to, points)
		_check_landing(to)
		if _on_mover(to):
			_landing_move(to, _last_dir)
		_settle()
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var cell := Vector2i(c, r)
			var goob: GoobDefinition = _cell_goobs.get(cell)
			if goob != null and goob.has_meta(&"rowdy"):
				_mark(cell, &"rowdy", null)


## What Nostalgic (`kind` COPY_OWN: `side`'s) or Mocking (the enemy's) copies
## from `last_played`; a plain Goob when there is no earlier play.
static func copy_source(kind: GoobDefinition.EffectType, side: BoardState.CellOwner, last_played: Dictionary) -> GoobDefinition:
	var whose := side if kind == GoobDefinition.EffectType.COPY_OWN else enemy_of(side)
	var source: GoobDefinition = last_played.get(whose)
	return source if source != null else VANILLA


## The type `goob`, played by `side`, counts as for later copies: what a
## Nostalgic / Mocking becomes, else itself.
func _played_as(goob: GoobDefinition, side: BoardState.CellOwner) -> GoobDefinition:
	var base := base_of(goob)
	if base.effect_type == GoobDefinition.EffectType.COPY_OWN or base.effect_type == GoobDefinition.EffectType.COPY_ENEMY:
		return copy_source(base.effect_type, side, _last_played)
	return base


## The Goob in `cell` becomes `source`'s type for good (effect and passives;
## its own name, owner and x2 stay).
func _become(cell: Vector2i, source: GoobDefinition) -> void:
	var copy := _own_copy(cell)
	if copy == null:
		return
	copy.effect_type = source.effect_type
	if source.effect_type == GoobDefinition.EffectType.NONE:
		copy.effect_description = "Copied a plain Goob: no effect."
	else:
		copy.effect_description = "Copied %s: %s" % [source.display_name, source.effect_description]


## Ruthless: any enemy Goob; Desperate: any Goob but itself (`cell`).
func _discard_destroy_targets(kind: GoobDefinition.EffectType, cell: Vector2i, side: BoardState.CellOwner) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for c in BoardState.COLUMNS:
		for r in BoardState.ROWS:
			var owner := board.get_owner(c, r)
			if owner == BoardState.CellOwner.EMPTY or Vector2i(c, r) == cell:
				continue
			if kind == GoobDefinition.EffectType.DISCARD_DESTROY or owner == enemy_of(side):
				targets.append(Vector2i(c, r))
	return targets


## The Jinxed pill: `side`'s next turn draw is smaller.
func _sync_jinx_status(side: BoardState.CellOwner) -> void:
	var jinxes: int = _jinxes.get(side, 0)
	if jinxes <= 0:
		remove_status(&"jinxed", side)
		return
	var whose := "your" if side == BoardState.CellOwner.PLAYER else "his"
	# Two ticks: it stays through the jinxed turn, so the pill is seen.
	add_status(&"jinxed", side, "Jinxed", "Jinxed: %s turn draw is %d Goob%s fewer." % [whose, jinxes, "" if jinxes == 1 else "s"], 2)


## The Reckless pill: `side`'s next turn draw is bigger.
func _sync_bonus_status(side: BoardState.CellOwner) -> void:
	var extra: int = _bonus_draws.get(side, 0)
	if extra <= 0:
		remove_status(&"reckless", side)
		return
	var whose := "your" if side == BoardState.CellOwner.PLAYER else "his"
	add_status(&"reckless", side, "Reckless", "Reckless: %s next turn draws %d extra Goobs." % [whose, extra], -1)


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
## the status tick and before the draw. Its effect steps go to
## turn_start_steps.
func _on_turn_start(side: BoardState.CellOwner) -> void:
	_smoulder(side)
	_sync_board_statuses()


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
static func play_results(on: BoardState, goobs: Dictionary, goob: GoobDefinition, column: int, side: BoardState.CellOwner, limit: int = 48, piles: Dictionary = {}, state: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var script: Array[int] = []
	for run in limit:
		var sim := TurnLoop.new()
		sim.board = on.copy()
		sim._cell_goobs = goobs.duplicate()
		for pile_side: BoardState.CellOwner in piles:
			sim.deck_of(pile_side).destroyed_pile = piles[pile_side].duplicate()
		# Discard effects (M6e): the hands (the played Goob has left `side`'s)
		# and the discard piles, from sim_state().
		var hands: Dictionary = state.get("hands", {})
		for hand_side: BoardState.CellOwner in hands:
			var hand: Array[GoobDefinition] = []
			hand.assign(hands[hand_side])
			if hand_side == side and hand.has(goob):
				hand.erase(goob)
			sim.deck_of(hand_side).hand = hand
		var discards: Dictionary = state.get("discards", {})
		for pile_side: BoardState.CellOwner in discards:
			sim.deck_of(pile_side).discard_pile.assign(discards[pile_side])
		# Tech (M6e): Steadfast / Loyal windows and Stiflings, from sim_state().
		for st: Dictionary in state.get("statuses", []):
			sim.statuses.append(st.duplicate())
		sim._stifles = state.get("stifles", {}).duplicate()
		sim._last_played = state.get("last_played", {}).duplicate()
		sim._scripted = true
		sim._script = script
		sim._play_goob(goob, column, side, 0, sim._stifles.get(side, 0) > 0)
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


## Both destroyed piles by side, for play_results (Occult); `mirrored` swaps
## the sides like BoardState.mirrored() (the AI playing your turn).
func destroyed_piles(mirrored := false) -> Dictionary:
	var mine := BoardState.CellOwner.OPPONENT if mirrored else BoardState.CellOwner.PLAYER
	return {mine: player_deck.destroyed_pile, enemy_of(mine): opponent_deck.destroyed_pile}


## Hands and discard piles for play_results, seen by the AI playing as
## OPPONENT (`mirrored`: for you, on auto-play): its own hand, the other
## side's hand only as that many plain Goobs (no cheating), both discard piles.
func sim_state(mirrored := false) -> Dictionary:
	var actor := player_deck if mirrored else opponent_deck
	var other := opponent_deck if mirrored else player_deck
	var unseen: Array[GoobDefinition] = []
	for i in other.hand.size():
		unseen.append(VANILLA)
	# Statuses and Stiflings with the sides as the AI sees them.
	var seen_statuses: Array[Dictionary] = []
	for st in statuses:
		var copy: Dictionary = st.duplicate()
		copy["side"] = _seen_side(st["side"], mirrored)
		seen_statuses.append(copy)
	var seen_stifles := {}
	for s: BoardState.CellOwner in _stifles:
		seen_stifles[_seen_side(s, mirrored)] = _stifles[s]
	var seen_played := {}
	for s: BoardState.CellOwner in _last_played:
		seen_played[_seen_side(s, mirrored)] = _last_played[s]
	return {
		"last_played": seen_played, # Nostalgic / Mocking copy these
		"statuses": seen_statuses,
		"stifles": seen_stifles,
		"locked": locked_columns(BoardState.CellOwner.PLAYER if mirrored else BoardState.CellOwner.OPPONENT),
		"hands": {BoardState.CellOwner.OPPONENT: actor.hand.duplicate(), BoardState.CellOwner.PLAYER: unseen},
		"discards": {BoardState.CellOwner.OPPONENT: actor.discard_pile.duplicate(), BoardState.CellOwner.PLAYER: other.discard_pile.duplicate()},
		"their_deck": other.draw_pile.size(), # Jinxing fizzles on an empty deck
	}


static func _seen_side(side: BoardState.CellOwner, mirrored: bool) -> BoardState.CellOwner:
	return enemy_of(side) if mirrored else side


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
	last_jinx_lost = 0
	last_draw_count = 0
	turn_draw_steps = []
	if not chained:
		last_skipped = []
		turn_start_steps = []
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
	# The turn-start effects get their own step list; the play's stays intact.
	var play_steps := effect_steps
	var play_effect := last_effect
	effect_steps = []
	_on_turn_start(current_side())
	turn_start_steps.append_array(effect_steps)
	effect_steps = play_steps
	last_effect = play_effect
	var deck := current_deck()
	var side := current_side()
	var unjinxed := _turn_draw_count(side, false)
	var count := _turn_draw_count(side)
	_bonus_draws.erase(side) # Reckless: used up by this draw
	_sync_bonus_status(side)
	_jinxes.erase(side) # Jinxing: used up by this turn, also by a forced draw
	if _skipped_last.get(side, false):
		count = maxi(count, TURN_DRAW) # never two skipped turns in a row
	# Goobs really lost: what the deck and the hand cap allow either way.
	last_jinx_lost = _drawable(deck, unjinxed) - _drawable(deck, count)
	last_draw_count = count
	last_draw_hand_full = deck.draw_blocked_by_hand(count)
	last_draw = deck.draw(count)
	turn_draw_steps = _echo_draws(side, last_draw.size())
	# No playable Goob (empty hand) after the draw, e.g. a discard plus a
	# prevented draw: this turn is skipped and turn order goes on as normal
	# (Sean, 2026-11-23; skips are never a draw).
	_skipped_last[side] = deck.hand.is_empty()
	if deck.hand.is_empty():
		last_skipped.append(side)
		# The skipped turn ends now: its start effects (Smouldering) get
		# their end-of-turn win check before the turn moves on.
		if not turn_start_steps.is_empty() and _check_end():
			return
		_begin_turn(other if phase == next else next, true)


## How many Goobs `side` draws at its turn start: Reckless's bonus and +1
## per Generous it owns now, minus 1 per Jinxing on it (never below 0;
## `jinxed` = false leaves the Jinxings out).
func _turn_draw_count(side: BoardState.CellOwner, jinxed := true) -> int:
	var count: int = TURN_DRAW + _bonus_draws.get(side, 0) + _owned_cells(GoobDefinition.EffectType.GENEROUS, side).size()
	if jinxed:
		count -= _jinxes.get(side, 0)
	return maxi(count, 0)


## How many of `count` Goobs `deck` can draw now (deck size, hand cap).
static func _drawable(deck: Deck, count: int) -> int:
	return clampi(mini(count, deck.draw_pile.size()), 0, maxi(Deck.HAND_MAX - deck.hand.size(), 0))


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
