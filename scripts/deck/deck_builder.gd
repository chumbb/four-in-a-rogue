class_name DeckBuilder
extends RefCounted
## Builds both sides' 21-Goob starting decks by rarity, not family (Sean,
## Special Goobs.xlsx "Example Deck Balance", 2026-11-27): 1 legendary,
## 4 very rare, 7 rare + 9 plain Goobs.
##
## Each scenario both sides get a different deck: a handmade decklist from
## decklists.json, or (RANDOM_CHANCE) a random deck of the same shape with no
## repeated types. A draw replay keeps the same decks (the scenario remembers them).

const SIZE := 21
const SHAPE := {GoobDefinition.Rarity.LEGENDARY: 1, GoobDefinition.Rarity.VERY_RARE: 4, GoobDefinition.Rarity.RARE: 7}
const DECKLISTS_PATH := "res://resources/goobs/decklists.json"
## Chance per side of a random deck instead of a decklist.
const RANDOM_CHANCE := 0.25
## The pick key / deck name for a random deck.
const RANDOM := "Random"
const JSON_KEYS := {GoobDefinition.Rarity.LEGENDARY: "legendary", GoobDefinition.Rarity.VERY_RARE: "very_rare", GoobDefinition.Rarity.RARE: "rare"}


## The decklists' names, in file order.
static func decklist_names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in _decklists():
		names.append(entry.get("name", ""))
	return names


## Both sides' decks for a new scenario: {"player": {name, goobs},
## "opponent": {name, goobs}}. `forced` (debug, optional): "player" /
## "opponent" = a decklist name or RANDOM.
static func roll_pair(rng: RandomNumberGenerator, forced := {}) -> Dictionary:
	var player := _pick_name(rng, forced.get("player", ""), "")
	var opponent := _pick_name(rng, forced.get("opponent", ""), player)
	return {"player": named(player, rng), "opponent": named(opponent, rng)}


## {name, goobs} for a decklist name, or a fresh random deck for RANDOM.
static func named(deck_name: String, rng: RandomNumberGenerator) -> Dictionary:
	if deck_name == RANDOM:
		return {"name": RANDOM, "goobs": random_deck(rng)}
	return {"name": deck_name, "goobs": decklist(deck_name)}


## A random deck of SHAPE: distinct types per rarity, then plain Goobs.
static func random_deck(rng: RandomNumberGenerator, roster: Array[GoobDefinition] = []) -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	for rarity: GoobDefinition.Rarity in SHAPE:
		var pool := of_rarity(rarity, roster)
		_shuffle(pool, rng)
		goobs.append_array(pool.slice(0, SHAPE[rarity]))
	while goobs.size() < SIZE:
		goobs.append(GoobRoster.plain())
	return goobs


## The 21 Goobs of a decklist (unshuffled); empty if there is none by that name.
static func decklist(deck_name: String) -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	for entry: Dictionary in _decklists():
		if entry.get("name", "") != deck_name:
			continue
		var by_id := {}
		for goob in GoobRoster.all():
			by_id[goob.id] = goob
		for rarity: GoobDefinition.Rarity in SHAPE:
			var ids = entry.get(JSON_KEYS[rarity], [])
			for id: String in (ids if ids is Array else [ids]):
				if by_id.has(id):
					goobs.append(by_id[id])
				else:
					push_error("DeckBuilder: decklist '%s' has unknown Goob '%s'" % [deck_name, id])
		while goobs.size() < SIZE:
			goobs.append(GoobRoster.plain())
		return goobs
	push_error("DeckBuilder: no decklist named '%s'" % deck_name)
	return goobs


## The special types of one rarity.
static func of_rarity(rarity: GoobDefinition.Rarity, roster: Array[GoobDefinition] = []) -> Array[GoobDefinition]:
	var found: Array[GoobDefinition] = []
	for goob in (roster if not roster.is_empty() else GoobRoster.all()):
		if goob.rarity == rarity and goob.category != GoobDefinition.Category.NONE:
			found.append(goob)
	return found


## `wanted` if given, else RANDOM_CHANCE random, else a decklist other than `avoid`.
static func _pick_name(rng: RandomNumberGenerator, wanted: String, avoid: String) -> String:
	if wanted != "":
		return wanted
	if rng.randf() < RANDOM_CHANCE:
		return RANDOM
	var names := decklist_names()
	names.erase(avoid)
	if names.is_empty():
		return RANDOM
	return names[rng.randi_range(0, names.size() - 1)]


static func _decklists() -> Array:
	var file := FileAccess.open(DECKLISTS_PATH, FileAccess.READ)
	if file == null:
		push_error("DeckBuilder: could not open %s" % DECKLISTS_PATH)
		return []
	var data = JSON.parse_string(file.get_as_text())
	return data.get("decklists", []) if data is Dictionary else []


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
