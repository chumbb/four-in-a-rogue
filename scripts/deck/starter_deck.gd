class_name StarterDeck
extends RefCounted
## Loads starter deck composition (stub — shuffle/draw in M4).

const DECK_JSON_PATH := "res://resources/goobs/starter_deck.json"


static func load_manifest() -> Dictionary:
	var file := FileAccess.open(DECK_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("StarterDeck: could not open %s" % DECK_JSON_PATH)
		return {}
	var text := file.get_as_text()
	return JSON.parse_string(text) as Dictionary
