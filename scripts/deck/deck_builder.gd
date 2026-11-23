class_name DeckBuilder
extends RefCounted
## Rolls one side's 21-Goob deck (M6e): 11 plain Goobs + 10 specials.
##
## Specials: 1-2 from one mixed UNIQUE + TECH "top" pool (forced.top restricts
## it to one of the two), and two different
## MOVE / DESTROY / DISCARD pools of 4-5 each, 10 in total. DRAW Goobs take
## 0-1 slots of one random pool and 0-2 of the other. A pool picks distinct
## types while it can, cycling when it runs out; a category with no Goobs
## gives plain Goobs.

const SIZE := 21
const SPECIALS := 10
const TOP_CATEGORIES: Array[GoobDefinition.Category] = [GoobDefinition.Category.UNIQUE, GoobDefinition.Category.TECH]
const MAIN_CATEGORIES: Array[GoobDefinition.Category] = [GoobDefinition.Category.MOVE, GoobDefinition.Category.DESTROY, GoobDefinition.Category.DISCARD]


## `forced` keys (all optional, debug/tests): "top" = UNIQUE or TECH,
## "main" = two of MOVE / DESTROY / DISCARD.
static func roll(rng: RandomNumberGenerator, forced := {}) -> Array[GoobDefinition]:
	return roll_from(rng, GoobRoster.all(), forced)


static func roll_from(rng: RandomNumberGenerator, roster: Array[GoobDefinition], forced := {}) -> Array[GoobDefinition]:
	# Unforced, the top slots share one mixed UNIQUE + TECH pool.
	var top: Array = [forced["top"]] if forced.has("top") else TOP_CATEGORIES
	var main: Array = forced.get("main", [])
	if main.size() != 2:
		var pool: Array = MAIN_CATEGORIES.duplicate()
		_shuffle(pool, rng)
		main = pool.slice(0, 2)
	var top_count := rng.randi_range(1, 2)
	var rest := SPECIALS - top_count
	var first := rest / 2
	if rest % 2 == 1 and rng.randi_range(0, 1) == 1:
		first += 1
	var sizes := [first, rest - first]
	# Which pool may take only 0-1 DRAW Goobs, the other 0-2.
	var capped := rng.randi_range(0, 1)
	var draw_counts := [0, 0]
	draw_counts[capped] = rng.randi_range(0, 1)
	draw_counts[1 - capped] = rng.randi_range(0, 2)

	var goobs: Array[GoobDefinition] = []
	goobs.append_array(_pick(top, top_count, roster, rng))
	var draws := _pick(GoobDefinition.Category.DRAW, draw_counts[0] + draw_counts[1], roster, rng)
	var draw_at := 0
	for i in 2:
		goobs.append_array(_pick(main[i], sizes[i] - draw_counts[i], roster, rng))
		goobs.append_array(draws.slice(draw_at, draw_at + draw_counts[i]))
		draw_at += draw_counts[i]
	while goobs.size() < SIZE:
		goobs.append(GoobRoster.plain())
	return goobs


## `count` Goobs of a category (or of several categories mixed): its types shuffled and taken in order, cycling
## when exhausted; plain Goobs when the category is empty.
static func _pick(category, count: int, roster: Array[GoobDefinition], rng: RandomNumberGenerator) -> Array[GoobDefinition]:
	var picked: Array[GoobDefinition] = []
	var types: Array = []
	for c in (category if category is Array else [category]):
		types.append_array(GoobRoster.specials(c, roster))
	_shuffle(types, rng)
	for i in count:
		picked.append(types[i % types.size()] if not types.is_empty() else GoobRoster.plain())
	return picked


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
