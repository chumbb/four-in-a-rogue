class_name GoobDefinition
extends Resource

enum EffectType {
	NONE,
	FLIP_ADJACENT,
	DESTROY_ADJACENT,
	EXTRA_VANILLA_DROP,
	DRAW_TWO,
}

@export var id: String = ""
@export var display_name: String = "Goob"
@export var multiplier: float = 1.0
@export_multiline var effect_description: String = ""
@export var effect_type: EffectType = EffectType.NONE
## Inspect panel lore line (writing session; vault Design/Lore seed.md).
@export_multiline var flavour_text: String = ""
## Art folder under res://assets/goobs/ (Art pass D2): <team>_yaw/frame_00–07
## (frame_00 = board + hand still), <team>_pitch/, <team>_frames.tres
## (SpriteFrames, one looping animation per expression). Team: blue = player.
@export var art_id: String = "vanilla"

const ART_DIR := "res://assets/goobs/%s/%s_%s"


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


## Expression loops for `side` (idle, giggle, happy, sad, celebrating,
## surprised, worried); wired to game events in M6c.
func sprite_frames(side: BoardState.CellOwner) -> SpriteFrames:
	return load(ART_DIR % [art_id, team_of(side), "frames.tres"])
