class_name Toast
extends PanelContainer
## Short-lived message pill (invalid placement etc., §4.6).
## Add once to a CanvasLayer/Control; call show_message() as often as needed.

const MSG_COLUMN_FULL := "Column full"
const MSG_BLOCKED_CELL := "A Goob stops you from playing here"

@export var hold_seconds := 1.2
@export var fade_seconds := 0.35

var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_color = Color(0.95, 0.35, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func show_message(text: String) -> void:
	_label.text = text
	reset_size()
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
