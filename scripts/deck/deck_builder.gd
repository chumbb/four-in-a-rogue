class_name DeckBuilder
extends RefCounted
## Rolls one side's 21-Goob deck (M6e; M6f, Sean 2026-11-24).
##
## Two deck types, picked 50/50 per roll and the same for both sides
## (roll_type): CLASSIC = 10 specials + 11 plain Goobs, LOADED = 14 + 7.
## Pools follow the family rings (GoobDefinition.ring_family(), so legendary
## Goobs roll with the family whose ring they wear): 1-2 (LOADED 2-3) from the
## TECH family "top" pool, the rest split between two different MOVE / DESTROY
## / DISCARD pools. DRAW Goobs take 0-1 slots of each of those two pools. At
## most LEGENDARY_MAX legendaries per deck. A pool picks distinct types while
## it can, cycling when it runs out; an empty pool gives plain Goobs.

enum DeckType { CLASSIC, LOADED }

const SIZE := 21
const SPECIALS := {DeckType.CLASSIC: 10, DeckType.LOADED: 14}
const TOP_RANGE := {DeckType.CLASSIC: Vector2i(1, 2), DeckType.LOADED: Vector2i(2, 3)}
const LEGENDARY_MAX := 2
const TOP_FAMILY := GoobDefinition.Category.TECH
const MAIN_CATEGORIES: Array[GoobDefinition.Category] = [GoobDefinition.Category.MOVE, GoobDefinition.Category.DESTROY, GoobDefinition.Category.DISCARD]


## 50/50 deck type for a new scenario (both sides use it).
static func roll_type(rng: RandomNumberGenerator) -> DeckType:
	return DeckType.LOADED if rng.randi_range(0, 1) == 1 else DeckType.CLASSIC


## `forced` keys (all optional, debug/tests): "type" = a DeckType (else 50/50),
## "main" = two of MOVE / DESTROY / DISCARD.
static func roll(rng: RandomNumberGenerator, forced := {}) -> Array[GoobDefinition]:
	return roll_from(rng, GoobRoster.all(), forced)


static func roll_from(rng: RandomNumberGenerator, roster: Array[GoobDefinition], forced := {}) -> Array[GoobDefinition]:
	var type: DeckType = forced["type"] if forced.has("type") else roll_type(rng)
	var main: Array = forced.get("main", [])
	if main.size() != 2:
		var pool: Array = MAIN_CATEGORIES.duplicate()
		_shuffle(pool, rng)
		main = pool.slice(0, 2)
	var top_range: Vector2i = TOP_RANGE[type]
	var top_count := rng.randi_range(top_range.x, top_range.y)
	var rest: int = SPECIALS[type] - top_count
	var first := rest / 2
	if rest % 2 == 1 and rng.randi_range(0, 1) == 1:
		first += 1
	var sizes := [first, rest - first]
	var draw_counts := [rng.randi_range(0, 1), rng.randi_range(0, 1)]

	var state := {"legendaries": 0}
	var goobs: Array[GoobDefinition] = []
	goobs.append_array(_pick(TOP_FAMILY, top_count, roster, rng, state))
	var draws := _pick(GoobDefinition.Category.DRAW, draw_counts[0] + draw_counts[1], roster, rng, state)
	var draw_at := 0
	for i in 2:
		goobs.append_array(_pick(main[i], sizes[i] - draw_counts[i], roster, rng, state))
		goobs.append_array(draws.slice(draw_at, draw_at + draw_counts[i]))
		draw_at += draw_counts[i]
	while goobs.size() < SIZE:
		goobs.append(GoobRoster.plain())
	return goobs


## `count` Goobs of a ring family (or of several mixed): its types shuffled and
## taken in order, cycling when exhausted, skipping legendaries once the deck
## has LEGENDARY_MAX (`state` is shared by one roll); plain Goobs when nothing
## is left.
static func _pick(family, count: int, roster: Array[GoobDefinition], rng: RandomNumberGenerator, state: Dictionary) -> Array[GoobDefinition]:
	var picked: Array[GoobDefinition] = []
	var types: Array = []
	for c in (family if family is Array else [family]):
		types.append_array(GoobRoster.family(c, roster))
	_shuffle(types, rng)
	var at := 0
	for i in count:
		var goob: GoobDefinition = null
		for k in types.size():
			var t: GoobDefinition = types[(at + k) % types.size()]
			if t.is_legendary() and state["legendaries"] >= LEGENDARY_MAX:
				continue
			goob = t
			at = (at + k + 1) % types.size()
			break
		if goob == null:
			goob = GoobRoster.plain()
		elif goob.is_legendary():
			state["legendaries"] += 1
		picked.append(goob)
	return picked


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
