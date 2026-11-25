class_name GoobDefinition
extends Resource

enum EffectType {
	NONE,
	FLIP_ADJACENT,
	DESTROY_ADJACENT,
	EXTRA_VANILLA_DROP,
	DRAW_TWO, ## Greedy (was Plentiful until M6e Draw)
	# M6e Move (Sean, 2026-11-23; vault Special Goobs "M6e Move rules")
	PUSH_LEFT, ## Sinister
	PUSH_RIGHT, ## Dexterous
	ROLL_LEFT, ## Lopsided: on land and when it falls
	ROLL_RIGHT, ## Tipsy
	BOUNCY, ## passive: Goobs landing on it bounce to the next column
	SLIPPERY, ## passive: Goobs played on it roll
	ROLL_HIGHEST, ## Blustery
	SPRINGY, ## passive: rolling Goobs bounce off it
	ROLL_IN_ROW, ## Fidgety
	# M6e Destroy (Sean, 2026-11-23; vault Special Goobs "M6e Destroy rules")
	DESTROY_RANDOM, ## Volatile: any Goob, itself included
	DESTROY_LANDER, ## Spiteful, passive: destroys the next Goob that lands on it
	RESURRECT, ## Occult: one of your destroyed Goobs drops for you
	DESTROY_BELOW, ## Crushing
	DESTROY_BESIDE, ## Brawling: one random side
	DESTROY_LATER, ## Smouldering: a random adjacent Goob at your next turn start
	# M6e Discard (Sean, 2026-11-23; vault Special Goobs "M6e Discard rules")
	DISCARD_ENEMY, ## Distracting: your opponent discards a random Goob
	DEFIANT, ## Defiant, passive: played instead when discarded
	DISCARD_DRAW, ## Fickle: discard 1, then draw 1
	DISCARD_DESTROY_ENEMY, ## Ruthless: discard 2, then destroy a random enemy Goob
	DISCARD_HAND, ## Reckless: discard your hand, +2 draws on your next turn
	RETURN_DISCARD, ## Thrifty: one of your discarded Goobs drops for you
	DISCARD_DESTROY, ## Desperate: discard 1, then destroy a random Goob (never itself)
	# M6e Draw (Sean, 2026-11-23; vault Special Goobs "M6e Draw rules")
	JINX, ## Jinxing: the opponent's next turn draw gives one Goob fewer
	GENEROUS, ## Generous, passive: +1 on its owner's turn draw while on the board
	DRAW_ECHO, ## Plentiful, passive: its owner draws 1 for each Goob the opponent draws
	# M6e Tech (Sean, 2026-11-24; vault Special Goobs "M6e Tech rules")
	STEADFAST, ## your Goobs can't be moved until the end of the opponent's next turn
	LOYAL, ## your Goobs can't be destroyed until the end of the opponent's next turn
	STALWART, ## passive: this Goob can't be destroyed or moved
	TERRITORIAL, ## the opponent can't play in this column on their next turn
	INSPIRE, ## Inspiring: a random adjacent friendly Goob's landing effect fires again
	STIFLE, ## Stifling: the opponent's next played Goob has no effect
	STEAL, ## Thieving: takes a random enemy Goob's ongoing effect
	HOARDING, ## passive: its owner's hand can't be discarded
	# M6e Uniquely powerful (Sean, 2026-11-24; vault Special Goobs "M6e Uniquely powerful rules")
	SHIFT, ## Seismic: every Goob one column left or right; the edge column falls off
	SINK, ## Sinking: the bottom row falls out
	BOUNCE_TOPS, ## Rowdy: the top Goob of every column bounces, left to right
	COPY_OWN, ## Nostalgic: becomes the last Goob you played
	COPY_ENEMY, ## Mocking: becomes the last Goob your opponent played
}

## Deck-building pool (M6e framework).
enum Category { NONE, UNIQUE, TECH, MOVE, DESTROY, DISCARD, DRAW }

@export var id: String = ""
@export var display_name: String = "Goob"
@export var multiplier: float = 1.0
@export_multiline var effect_description: String = ""
@export var effect_type: EffectType = EffectType.NONE
@export var category: Category = Category.NONE
## Family ring on its rim (M6f, Sean 2026-11-24). NONE = its category's ring;
## Uniquely powerful ("legendary") Goobs wear another family's ring.
@export var ring: Category = Category.NONE
## Inspect panel lore line (writing session; vault Design/Lore seed.md).
@export_multiline var flavour_text: String = ""
## Art folder under res://assets/goobs/ (Art pass D2): <team>_yaw/frame_00–07
## (frame_00 = board + hand still), <team>_pitch/, <team>_frames.tres
## (SpriteFrames, one looping animation per expression). Team: blue = player.
@export var art_id: String = "vanilla"
## Flips end over end (its <team>_pitch frames) instead of spinning sideways
## (Sean, M6c playtest: Vanilla).
@export var flips_vertically: bool = false

## Effects that do nothing when played; they act while on the board.
const PASSIVE_EFFECTS: Array[EffectType] = [EffectType.BOUNCY, EffectType.SLIPPERY, EffectType.SPRINGY, EffectType.DESTROY_LANDER, EffectType.DESTROY_LATER, EffectType.DEFIANT, EffectType.GENEROUS, EffectType.DRAW_ECHO, EffectType.STALWART, EffectType.HOARDING]

## Effects with nothing to do when the Goob lands (Inspiring skips them).
const NO_LANDING_EFFECT: Array[EffectType] = [EffectType.NONE, EffectType.BOUNCY, EffectType.SLIPPERY, EffectType.SPRINGY, EffectType.DEFIANT, EffectType.GENEROUS, EffectType.DRAW_ECHO, EffectType.STALWART, EffectType.HOARDING, EffectType.INSPIRE]

## Ongoing effects Thieving can take (an armed Spiteful / pending Smouldering
## too; TurnLoop._stealable). Lopsided / Tipsy: their roll when they fall.
const STEALABLE_EFFECTS: Array[EffectType] = [EffectType.BOUNCY, EffectType.SLIPPERY, EffectType.SPRINGY, EffectType.GENEROUS, EffectType.DRAW_ECHO, EffectType.STALWART, EffectType.HOARDING, EffectType.ROLL_LEFT, EffectType.ROLL_RIGHT]

const ART_DIR := "res://assets/goobs/%s/%s_%s"
const RING_DIR := "res://assets/goobs/rings/%s_%s.png"
const RING_NAMES := {Category.MOVE: "move", Category.DESTROY: "destroy", Category.DISCARD: "discard", Category.DRAW: "draw", Category.TECH: "tech"}


## Whose look this Goob shows (M6f): a Nostalgic / Mocking that became another
## Goob looks like it (TurnLoop._become sets "look"); else its plain definition.
func look() -> GoobDefinition:
	return get_meta(&"look", get_meta(&"base", self))


## Any special (not a plain Goob): tinted darker and ringed.
func is_special() -> bool:
	return look().category != Category.NONE


## Uniquely powerful: the legendary glint on top of the special look.
func is_legendary() -> bool:
	return look().category == Category.UNIQUE


## The family whose ring it wears (NONE for a plain Goob).
func ring_family() -> Category:
	var l := look()
	return l.ring if l.ring != Category.NONE else l.category


## Its ring overlay for `side` (32 px, same frame as the still); null if none.
func ring_texture(side: BoardState.CellOwner) -> Texture2D:
	var family := ring_family()
	if not RING_NAMES.has(family):
		return null
	return load(RING_DIR % [RING_NAMES[family], team_of(side)])


## Its sparkle while on the board (M6f, Sean 2026-11-24), from what its effect
## does now (a stolen or copied effect counts): &"embers" (armed destroy),
## &"stars" (protection), &"motes" (bonus Goobs), &"chevrons" (bounce),
## &"crackle_left" / &"crackle_right" / &"crackle" (rolling). Steadfast /
## Loyal give &"steadfast" / &"loyal": stars only while that status lasts
## (the board view checks). &"" = none.
func sparkle() -> StringName:
	match effect_type:
		EffectType.DESTROY_LANDER, EffectType.DESTROY_LATER:
			return &"embers" if get_meta(&"armed_by", BoardState.CellOwner.EMPTY) != BoardState.CellOwner.EMPTY else &""
		EffectType.STALWART, EffectType.HOARDING:
			return &"stars"
		EffectType.STEADFAST:
			return &"steadfast"
		EffectType.LOYAL:
			return &"loyal"
		EffectType.GENEROUS, EffectType.DRAW_ECHO:
			return &"motes"
		EffectType.BOUNCY, EffectType.SPRINGY:
			return &"chevrons"
		EffectType.ROLL_LEFT:
			return &"crackle_left"
		EffectType.ROLL_RIGHT:
			return &"crackle_right"
		EffectType.SLIPPERY:
			return &"crackle"
	return &""


static func team_of(side: BoardState.CellOwner) -> String:
	return "red" if side == BoardState.CellOwner.OPPONENT else "blue"


## The board/hand still (idle keyframe) for `side`.
func still(side: BoardState.CellOwner) -> Texture2D:
	return load((ART_DIR % [art_id, team_of(side), "yaw"]) + "/frame_00.png")


## The 8 spin frames for `side`: face → edge → back → edge.
func yaw_frames(side: BoardState.CellOwner) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in 8:
		frames.append(load((ART_DIR % [art_id, team_of(side), "yaw"]) + "/frame_%02d.png" % i))
	return frames


## The 8 frames this Goob flips with (face → edge → back → edge): pitch
## when it flips vertically, else yaw. Frame 4 is its back.
func flip_frames(side: BoardState.CellOwner) -> Array[Texture2D]:
	return pitch_frames(side) if flips_vertically else yaw_frames(side)


## The 8 end-over-end frames for `side` (face → edge → back → edge). Every
## played Goob flips into place with these (Sean, M6c playtest).
func pitch_frames(side: BoardState.CellOwner) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in 8:
		frames.append(load((ART_DIR % [art_id, team_of(side), "pitch"]) + "/frame_%02d.png" % i))
	return frames


## Expression loops for `side` (idle, giggle, happy, sad, celebrating,
## surprised, worried); wired to game events in M6c.
func sprite_frames(side: BoardState.CellOwner) -> SpriteFrames:
	return load(ART_DIR % [art_id, team_of(side), "frames.tres"])


## The frame of expression `anim` at `t` seconds into its loop (frame
## durations as baked in the SpriteFrames; idle holds its open-eyed frame and
## blinks now and then). Null if `frames` lacks `anim`.
static func face_frame(frames: SpriteFrames, anim: StringName, t: float) -> Texture2D:
	if frames == null or not frames.has_animation(anim):
		return null
	var count := frames.get_frame_count(anim)
	var speed := frames.get_animation_speed(anim)
	var total := 0.0
	for i in count:
		total += frames.get_frame_duration(anim, i) / speed
	var at := fposmod(t, total)
	for i in count:
		at -= frames.get_frame_duration(anim, i) / speed
		if at < 0.0:
			return frames.get_frame_texture(anim, i)
	return frames.get_frame_texture(anim, count - 1)
