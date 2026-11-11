class_name SafeArea
extends MarginContainer
## Keeps interactive UI out of notches and the home-gesture strip (slice §2A).
## Margins come from DisplayServer.get_display_safe_area(), converted to
## viewport units, and are reapplied on resize. Desktop has no insets, so F3
## (debug builds only, handled in GameFlow) simulates a phone's.

const GROUP := "safe_area"
## Simulated phone insets at the 720 base: notch / Dynamic Island, home indicator.
const SIM_TOP := 110
const SIM_BOTTOM := 70

static var simulate_insets := false


func _ready() -> void:
	add_to_group(GROUP)
	get_viewport().size_changed.connect(apply)
	apply()


## Top/left/right/bottom insets in viewport units.
func current_insets() -> Dictionary:
	var insets := {"top": 0, "left": 0, "right": 0, "bottom": 0}
	if simulate_insets:
		insets.top = SIM_TOP
		insets.bottom = SIM_BOTTOM
	elif OS.has_feature("mobile"):
		var window := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if window.x > 0 and window.y > 0:
			var scale := get_viewport().get_visible_rect().size / Vector2(window)
			insets.top = maxi(0, int(safe.position.y * scale.y))
			insets.left = maxi(0, int(safe.position.x * scale.x))
			insets.right = maxi(0, int((window.x - safe.end.x) * scale.x))
			insets.bottom = maxi(0, int((window.y - safe.end.y) * scale.y))
	return insets


func apply() -> void:
	var insets := current_insets()
	add_theme_constant_override("margin_top", insets.top)
	add_theme_constant_override("margin_left", insets.left)
	add_theme_constant_override("margin_right", insets.right)
	add_theme_constant_override("margin_bottom", insets.bottom)
