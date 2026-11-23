class_name GoobRoster
extends RefCounted
## Every Goob type a rolled deck can draw from (M6e). Category sessions add
## their paths here.

const PATHS: Array[String] = [
	"res://resources/goobs/vanilla_goob.tres",
	"res://resources/goobs/convincing_goob.tres",
	"res://resources/goobs/fat_goob.tres",
	"res://resources/goobs/popular_goob.tres",
	"res://resources/goobs/plentiful_goob.tres",
	"res://resources/goobs/sinister_goob.tres",
	"res://resources/goobs/dexterous_goob.tres",
	"res://resources/goobs/lopsided_goob.tres",
	"res://resources/goobs/tipsy_goob.tres",
	"res://resources/goobs/bouncy_goob.tres",
	"res://resources/goobs/slippery_goob.tres",
	"res://resources/goobs/blustery_goob.tres",
	"res://resources/goobs/springy_goob.tres",
	"res://resources/goobs/fidgety_goob.tres",
]


static func all() -> Array[GoobDefinition]:
	var goobs: Array[GoobDefinition] = []
	for path in PATHS:
		var definition := load(path) as GoobDefinition
		if definition == null:
			push_error("GoobRoster: could not load %s" % path)
			continue
		goobs.append(definition)
	return goobs


## The special types of one category (NONE is the plain Goob, not a special).
static func specials(category: GoobDefinition.Category, roster: Array[GoobDefinition] = []) -> Array[GoobDefinition]:
	var found: Array[GoobDefinition] = []
	for goob in (roster if not roster.is_empty() else all()):
		if goob.category == category and category != GoobDefinition.Category.NONE:
			found.append(goob)
	return found


static func plain() -> GoobDefinition:
	return load(PATHS[0]) as GoobDefinition
