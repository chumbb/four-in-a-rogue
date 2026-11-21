class_name ScenarioHud
extends Control
## Scenario HUD on the game-pixel grid (Art B mock 2, slice §2B "HUD"; M6b):
## one block with thick gold section bars: the opponent's bust portrait (v0.1:
## the Strange Man, idle) | the turn timer in the round Forest emblem, with the
## scenario's objective ("Get four in a row") under it | "Scenario" + its number.
## Timer: a number from 30, red for the last 10 s, "—" on the opponent's turn.
## The Pause button is at the bottom left of the safe area. Also shows the turn
## banners (blue "Your turn" / red "Opponent's turn" ribbons across the screen),
## in the gap between the HUD and the board.
##
## Sean, 2026-11-20: the block grew from 56 to 76 game px so the 64 px bust
## shows whole; playtest 1: emblem moved up into the block's centre section,
## no "Objective" heading, scenario shows "1", banners above the board.

signal pause_pressed

const PORTRAIT := preload("res://assets/strange_man/portrait_idle.png")
const EMBLEM := preload("res://assets/ui/timer_emblem_forest.png")
const DIVIDER := preload("res://assets/ui/divider_v.png")
const PAUSE_ICON := preload("res://assets/ui/icon_pause.png")
const RIBBON_BLUE := preload("res://assets/ui/ribbon_blue.png")
const RIBBON_RED := preload("res://assets/ui/ribbon_red.png")

const GOLD_HI := Color("fbb954")
const RED := Color("e83b3b")
## Layout in game px (mock 2, block 76 tall for the 64 px bust).
const TOP_GAP := 8.0
const BLOCK_X := 6.0
const BLOCK_H := 76.0
const PORTRAIT_INSET := 6.0
const SCENARIO_W := 62.0
const EMBLEM_TOP := 4.0 ## emblem top inside the block's centre section
const OBJECTIVE_Y := 52.0 ## objective line under the emblem
const PAUSE_SIZE := Vector2(40, 38)
const PAUSE_INSET := 9.0
## Ink outline around the timer digits (8 directions + a drop below).
const OUTLINE := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 2)]
const NO_TIMER := "—"
const RED_FROM_SEC := 10
## Turn banner: band opens, text slides in, holds, slides out (Normal; the
## scenario passes the length for the speed setting).
const BANNER_SLIDE_PX := 40.0

var stage: PixelStage
var _block: NinePatchRect
var _objective: Label
var _scenario: Label
var _timer_box: Control
var _timer_labels: Array[Label] = []
var _emblem: TextureRect
var _pause: Button
var _ribbon: TextureRect
var _ribbon_label: Label
var _ribbon_tween: Tween
## Gap between the HUD and the board in game px (set_banner_band); the
## ribbon is centred in it.
var _band := Vector2(-1, -1)


func _init() -> void:
	name = "Hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = PixelStage.new()
	add_child(stage)
	_build()
	stage.relayout.connect(_layout)


func _build() -> void:
	_block = NinePatchRect.new()
	_block.texture = UiKit.texture(&"panel")
	var m: Array = UiKit.MARGINS[&"panel"]
	_block.patch_margin_left = m[0]
	_block.patch_margin_top = m[1]
	_block.patch_margin_right = m[2]
	_block.patch_margin_bottom = m[3]
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.canvas.add_child(_block)
	stage.add_image(PORTRAIT, Vector2(PORTRAIT_INSET, PORTRAIT_INSET), _block)
	for i in 2:
		var bar := TextureRect.new()
		bar.texture = DIVIDER
		bar.stretch_mode = TextureRect.STRETCH_TILE
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.name = "Bar%d" % i
		_block.add_child(bar)
	_objective = _shadowed(stage.add_label("Get four in a row", PixelStage.CREAM, &"", _block))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var run_header := _shadowed(stage.add_label("Scenario", GOLD_HI, &"", _block))
	run_header.name = "ScenarioHeader"
	_scenario = _shadowed(stage.add_label("1", PixelStage.CREAM, &"Mono2", _block), 2)
	for label: Label in [_objective, run_header, _scenario]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emblem = stage.add_image(EMBLEM, Vector2.ZERO, _block)
	_timer_box = Control.new()
	_timer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.add_child(_timer_box)
	for offset: Vector2 in OUTLINE + [Vector2.ZERO]:
		var label := stage.add_label("", PixelStage.INK0 if offset != Vector2.ZERO else PixelStage.CREAM, &"Mono2", _timer_box)
		label.position = offset
		_timer_labels.append(label)
	_pause = stage.add_button("", PAUSE_SIZE.x)
	_pause.name = "PauseButton"
	_pause.size = PAUSE_SIZE
	stage.add_image(PAUSE_ICON, ((PAUSE_SIZE - PAUSE_ICON.get_size()) * 0.5).floor() + Vector2(0, -1), _pause)
	_pause.pressed.connect(pause_pressed.emit)
	_ribbon = TextureRect.new()
	_ribbon.stretch_mode = TextureRect.STRETCH_TILE
	_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.visible = false
	stage.canvas.add_child(_ribbon)
	_ribbon_label = _shadowed(stage.add_label("", PixelStage.WHITE, &"Mono2", _ribbon), 2)
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_timer(NO_TIMER)


func _shadowed(label: Label, drop := 1) -> Label:
	label.add_theme_color_override(&"font_shadow_color", PixelStage.INK0)
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", drop)
	return label


func _layout() -> void:
	var safe := stage.safe
	var top := safe.position.y + TOP_GAP
	var width := stage.game_size.x - BLOCK_X * 2.0
	_block.position = Vector2(BLOCK_X, top)
	_block.size = Vector2(width, BLOCK_H)
	var bar_w := float(DIVIDER.get_width())
	var x1 := PORTRAIT_INSET + PORTRAIT.get_width() + 3.0
	var x2 := width - SCENARIO_W
	for i in 2:
		var bar: TextureRect = _block.get_node("Bar%d" % i)
		bar.position = Vector2(x1 if i == 0 else x2, 2)
		bar.size = Vector2(bar_w, BLOCK_H - 4.0)
	var mid_x := x1 + bar_w
	var mid_w := x2 - mid_x
	_emblem.position = Vector2(mid_x + floorf((mid_w - EMBLEM.get_width()) * 0.5), EMBLEM_TOP)
	_objective.position = Vector2(mid_x + 2, OBJECTIVE_Y)
	_objective.size = Vector2(mid_w - 4, 16)
	var run_x := x2 + bar_w
	var run_w := width - 3.0 - run_x
	var run_header: Label = _block.get_node("ScenarioHeader")
	run_header.position = Vector2(run_x, 16)
	run_header.size = Vector2(run_w, 16)
	_scenario.position = Vector2(run_x, 28)
	_scenario.size = Vector2(run_w, 32)
	_centre_timer()
	_pause.position = Vector2(safe.position.x + PAUSE_INSET, safe.end.y - PAUSE_INSET - PAUSE_SIZE.y)
	_ribbon.size = Vector2(stage.game_size.x, RIBBON_BLUE.get_height())
	_place_ribbon()
	_ribbon.pivot_offset = _ribbon.size * 0.5
	_ribbon_label.size = Vector2(_ribbon.size.x, 32)
	_ribbon_label.position.y = floorf((_ribbon.size.y - 32.0) * 0.5) - 1.0


## Bottom of the HUD block in viewport (720-base) units: the scenario
## reserves this much above the board.
func bottom() -> float:
	var bottom_px := stage.safe.position.y + TOP_GAP + BLOCK_H
	return stage.canvas.position.y + bottom_px * stage.k


## The turn banners sit in the gap between the HUD and the board: `top` and
## `bottom` in viewport units (HUD bottom, board top).
func set_banner_band(top: float, bottom_y: float) -> void:
	_band = Vector2((top - stage.canvas.position.y) / stage.k, (bottom_y - stage.canvas.position.y) / stage.k)
	_place_ribbon()


func _place_ribbon() -> void:
	var mid := stage.game_size.y * 0.5
	if _band.y > _band.x:
		mid = (_band.x + _band.y) * 0.5
	_ribbon.position = Vector2(0, roundf(mid - _ribbon.size.y * 0.5))


## The scenario's objective text (v0.1: "Get four in a row").
func set_objective(text: String) -> void:
	_objective.text = text


func objective() -> String:
	return _objective.text


## The countdown text ("30", "7", or "—").
func set_timer(text: String, red := false) -> void:
	if text == _timer_labels[-1].text and _timer_labels[-1].get_theme_color(&"font_color") == (RED if red else PixelStage.CREAM):
		return
	for label in _timer_labels:
		label.text = text
	_timer_labels[-1].add_theme_color_override(&"font_color", RED if red else PixelStage.CREAM)
	_centre_timer()


## Seconds left on the player's turn: red for the last 10 s.
func set_seconds(seconds: int) -> void:
	set_timer(str(seconds), seconds <= RED_FROM_SEC)


func timer_text() -> String:
	return _timer_labels[-1].text


func is_timer_red() -> bool:
	return _timer_labels[-1].get_theme_color(&"font_color") == RED


func pause_button() -> Button:
	return _pause


func set_pause_visible(on: bool) -> void:
	_pause.visible = on


## Centres the digits' drawn pixels (not the font advance box) on the emblem
## face, like the mock.
func _centre_timer() -> void:
	var label := _timer_labels[-1]
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for l in _timer_labels:
		l.size = Vector2(text_w + 2.0, 32)
	# Monogram 2×: digits are 14 px tall, starting 8 px below the line top;
	# the advance box carries 2 px of trailing space.
	var face := EMBLEM.get_size() * 0.5
	_timer_box.position = Vector2(floorf(face.x - (text_w - 2.0) * 0.5), floorf(face.y - 8.0 - 7.0))


## Turn banner (slice §2B, TCG Pocket style): blue "Your turn" or red
## "Opponent's turn" band across the screen. `sec` is the whole length; await
## it. Under the toasts, over the board.
func show_turn_banner(player: bool, sec: float) -> void:
	if _ribbon_tween and _ribbon_tween.is_valid():
		_ribbon_tween.kill()
	_ribbon.texture = RIBBON_BLUE if player else RIBBON_RED
	_ribbon_label.text = "Your turn" if player else "Opponent's turn"
	_ribbon.visible = true
	if sec <= 0.0:
		_ribbon.visible = false
		return
	var open := sec * 0.15
	var slide := sec * 0.2
	var hold := sec - open - slide * 2.0
	_ribbon.scale = Vector2(1, 0)
	_ribbon_label.position.x = BANNER_SLIDE_PX
	_ribbon_label.modulate.a = 0.0
	_ribbon_tween = create_tween()
	_ribbon_tween.tween_property(_ribbon, "scale:y", 1.0, open).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ribbon_tween.parallel().tween_method(_set_label_x, BANNER_SLIDE_PX, 0.0, open + slide).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ribbon_tween.parallel().tween_property(_ribbon_label, "modulate:a", 1.0, open + slide)
	_ribbon_tween.tween_interval(hold)
	_ribbon_tween.tween_method(_set_label_x, 0.0, -BANNER_SLIDE_PX, slide).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ribbon_tween.parallel().tween_property(_ribbon_label, "modulate:a", 0.0, slide)
	_ribbon_tween.parallel().tween_property(_ribbon, "scale:y", 0.0, slide * 0.5).set_delay(slide * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ribbon_tween.tween_callback(func() -> void: _ribbon.visible = false)
	await _ribbon_tween.finished


func is_banner_visible() -> bool:
	return _ribbon.visible


func banner_text() -> String:
	return _ribbon_label.text


## Whole game px only.
func _set_label_x(x: float) -> void:
	_ribbon_label.position.x = roundf(x)
