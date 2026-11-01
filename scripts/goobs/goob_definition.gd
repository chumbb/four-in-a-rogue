class_name GoobDefinition
extends Resource

enum EffectType {
	NONE,
	FLIP_ADJACENT,
	DESTROY_ADJACENT,
	EXTRA_VANILLA_DROP,
}

@export var id: String = ""
@export var display_name: String = "Goob"
@export var multiplier: float = 1.0
@export_multiline var effect_description: String = ""
@export var effect_type: EffectType = EffectType.NONE
