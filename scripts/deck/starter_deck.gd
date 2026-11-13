class_name StarterDeck
extends RefCounted
## Loads the starter deck composition from starter_deck.json (slice §4).

const DECK_JSON_PATH := "res://resources/goobs/starter_deck.json"


static func load_manifest() -> Dictionary:
	var file := FileAccess.open(DECK_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("StarterDeck: could not open %s" % DECK_JSON_PATH)
		return {}
	var text := file.get_as_text()
	return JSON.parse_string(text) as Dictionary


## The 21 Goobs of one starter deck, unshuffled, in manifest order. Copies of
## the same type share one GoobDefinition resource.
static func build() -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	var manifest := load_manifest()
	var paths: Dictionary = manifest.get("resource_paths", {})
	for entry: Dictionary in manifest.get("entries", []):
		var id: String = entry.get("goob_id", "")
		var definition := load(paths.get(id, "")) as GoobDefinition
		if definition == null:
			push_error("StarterDeck: no resource for goob_id '%s'" % id)
			continue
		for i in int(entry.get("count", 0)):
			goobs.append(definition)
	return goobs
