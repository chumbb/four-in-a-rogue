extends Control
## Scenario controller — turn loop with decks and hands (M4) in the portrait
## touch layout, on the M3.6 2D pixel board.
##
## The coin-flip winner moves first. Each turn draws 1 Goob (the player's pops
## in big, then flies into the fan). The player plays a hand Goob only by
## dragging it onto a column and letting go (release off the board cancels and
## it flies back); a blue flash and the floating Goob follow the column under
## the finger. Tapping a hand Goob selects it; touching the board never plays,
## aims or clears the selection (Sean, M6f 2026-11-24).
## Double tap inspects a hand or board Goob. The opponent (OpponentAI) replies after a short delay.
## Player turns are timed (slice §2B): at timeout the
## Goob goes into the column under the finger, else a random column, rolling
## off full columns. Goobs fall (or roll) into place before the next turn;
## input stays locked until they land. Each landed Goob's special effect then
## plays (M5; fizzle cue when it has no target), then the win check. A four
## plays the scoring sequence on the board first. The result is a big centred announcement: win/lose
## offers "Back to title", a draw "Replay" (straight back to the coin flip).
##
## M6b: pixel HUD (ScenarioHud: portrait, objective, scenario, timer emblem,
## Pause bottom left), turn banners, the pause menu (tree paused) with Options,
## haptics, the Screen shake option, and Normal / Fast on the play
## animations (Settings).

const OBJECTIVE := "Get four in a row"
## Opponent think delay: OPPONENT_DELAY_SEC ± THINK_JITTER_SEC, plus
## THINK_HARD_SEC when he is blocking you or the choice is close (Sean,
## 2026-11-22: 0.5–0.9 s, ~+0.4 s).
const OPPONENT_DELAY_SEC := 0.7
const THINK_JITTER_SEC := 0.2
const THINK_HARD_SEC := 0.4
## Red flash on the opponent's column right before its Goob is played.
## Per-scenario player turn limit (slice §2B); v0.1 has one scenario.
const TURN_SECONDS := 30.0
## Timeout auto-play must be obvious (Sean, 2026-11-11): "Time's up!" and a
## flash on the column for this long before the Goob drops.
const TIMEOUT_REVEAL_SEC := 0.7
const MSG_TIMES_UP := "Time's up!"
const MSG_HAND_FULL := "Hand full"
const MSG_NOT_NOW := "Not now" # debug give / discard while your hand is moving
const MSG_TURN_SKIPPED := "Turn skipped" # your hand is empty (Sean, 2026-11-23)
const MSG_OPPONENT_SKIPPED := "Opponent's turn skipped"
const MSG_JINXED := "Jinxed: no draw" # Jinxing (M6e Draw)
const MSG_JINXED_FEWER := "Jinxed: %d fewer"
const MSG_OPPONENT_JINXED := "Opponent jinxed: no draw"
const MSG_OPPONENT_JINXED_FEWER := "Opponent jinxed: %d fewer"
const MSG_STIFLED := "Stifled: no effect" # Stifling (M6e Tech)
const MSG_OPPONENT_STIFLED := "Opponent stifled: no effect"
const MSG_STOLE := "Stole %s's effect" # Thieving
const MSG_COPIED := "Copied %s" # Nostalgic / Mocking (M6e Uniquely powerful)
## Forest hand prop (assets/hand/forest_stump.png), in its game px: the row the
## hand Goobs' bottoms rest on, and the usable width of its top.
const STUMP_SEAT_Y := 34.0
const STUMP_TOP_WIDTH := 180.0
## Drag starts once the finger moves this far from the press (slice §2B).
const DRAG_START_PX := 12.0
const DOUBLE_TAP_SEC := 0.3
## Skipped draw: short whole-screen shake (slice §4, ~0.25 s).
const SCREEN_SHAKE_PX := [8, -8, 6, -6, 3, -3, 0]
const SCREEN_SHAKE_STEP_SEC := 0.035

const COLOR_FLASH_PLAYER := Color(0.3, 0.55, 1.0, 0.35)
## Dark highlight over a full column under the finger (Sean, M6d playtest).
const COLOR_FLASH_FULL := Color(0.0, 0.0, 0.0, 0.45)
const COLOR_FULL_GREY := Color(0.08, 0.08, 0.1, 0.55)
const COLOR_WIN := Color(1.0, 0.85, 0.3)
const COLOR_LOSE := Color(1.0, 0.3, 0.3)
const COLOR_SCORE_OUTLINE := Color(0.13, 0.08, 0.1)
## Scoring sequence timing (slice §4; snappier per Sean, M6c playtest 2026-11-23:
## ~0.55 s per Goob, was ~0.85).
const SCORE_RECOGNISE_SEC := 0.7
## Win/lose lead-in (faces + sting) before the scoring recognition.
const LEAD_IN_SEC := 0.8
## Shortest time a drawn Goob's name stays up (Fast).
const CAPTION_MIN_SEC := 1.0
## The opponent starts waiting after this long without a touch on your turn,
## and always while the fuse burns (Sean, M6c playtest).
const WAITING_AFTER_SEC := 8.0
const FUSE_BURN := preload("res://assets/audio/sfx/fuse_burn.ogg")
const SCORE_STEP_SEC := 0.4
## Scoring (Sean, M6c playtest): each Goob flips to its back, its multiplier
## shows there for SCORE_SHOW_SEC, then floats up into the gap between the HUD
## and the board (SCORE_FLOAT_SEC) as the Goob flips back; the total ends there.
const SCORE_SHOW_SEC := 0.15
const SCORE_FLOAT_SEC := 0.2
const SCORE_SLOT_GAP := 10.0
const SCORE_PAUSE_SEC := 0.25
const SCORE_COLLAPSE_SEC := 0.25
const SCORE_HOLD_SEC := 1.0
## Beat between a special's landing and its effect, and the pause after the
## effect before the next turn (Sean, 2026-11-19).
const EFFECT_LEAD_SEC := 0.2
const EFFECT_HOLD_SEC := 0.6
## Turn banner length (Normal). Fast halves it.
const TURN_BANNER_SEC := 0.9
## "Game start" banner, then a beat before the first turn banner.
const GAME_START_SEC := 1.3
const GAME_START_GAP_SEC := 0.25
## Debug auto-play (M6e): a draw's Replay presses itself after this long.
const AUTOPLAY_REPLAY_SEC := 1.0

@onready var _hud_slot: Control = %HudSlot
@onready var _board_view: BoardView2D = %BoardView
@onready var _aim_lane: Control = %AimLane
@onready var _flash: ColorRect = %ColumnFlash
@onready var _stump: TextureRect = %Stump
@onready var _end_overlay: Control = %EndOverlay
@onready var _hand: HandView = %PlayerHand

## Seconds before the opponent drops. Tests set 0.0 (move immediately).
var opponent_delay_sec := OPPONENT_DELAY_SEC
var turn_seconds := TURN_SECONDS
## Tests set 0.0 to drop at once on timeout.
var timeout_reveal_sec := TIMEOUT_REVEAL_SEC
## Tests set false: Goobs land at once (no fall / roll animation), and the
## scoring sequence runs without waits.
var animate_drops := true
## Tests set a deck (e.g. all Vanilla) to replace the starter deck.
var deck: Array[GoobDefinition] = []

var _hud: ScenarioHud
## Active statuses as pills in the gap (M6e).
var _pills: StatusPills
var _pause: PauseMenu
## F4 debug picker (debug builds only; null in a release build).
var _debug: DebugPanel
## Play data (M6g): each side's plays this scenario ({"played", "held"}),
## sent to Telemetry at the end (or on a quit).
var _stats: Dictionary = {}
var _stats_sent := false
var _started_msec := 0
var _autoplay_used := false
## The F4 panel changed this game (its data is left out of the Goob stats).
var _debug_used := false
## Set when the turn timer ran out (the HUD reads 0 until the Goob is played).
var _timed_out := false
var _loop := TurnLoop.new()
var _rng := RandomNumberGenerator.new()
var _toast: Toast
var _sfx: Sfx
## One-shot child timers: anything pending is freed with the scene.
var _opponent_timer: Timer
var _turn_timer: Timer
var _timeout_timer: Timer
var _opponent_column := -1
var _opponent_hand_index := -1
## WorkerThreadPool task of an AI move being chosen (-1 = none): waited for if
## the scenario leaves first.
var _ai_task := -1
## Choose AI moves on a worker thread. Off on web builds (no threads): the AI
## then thinks in AI_SLICE_USEC slices, one per frame (tests can force it off).
var ai_threads := OS.has_feature("threads")
const AI_SLICE_USEC := 8000
## Auto-play is choosing your move (its timer isn't running yet).
var _autoplay_thinking := false
## Debug auto-play (M6e): the AI's think delay on your turn, then its move.
var _autoplay_timer: Timer
var _autoplay_column := -1
var _autoplay_hand_index := -1
var _replay_timer: Timer
## The board just before the play now being shown (portrait reactions).
var _board_before := BoardState.new()
## Think-delay spread only, so it never shifts the game's own random draws.
var _think_rng := RandomNumberGenerator.new()
var _timeout_column := -1
var _timeout_hand_index := -1
## Columns the timeout Goob rolls over (off-board entries = edge bounces).
var _timeout_path: Array[int] = []

## Player input is accepted only while true (player turn, nothing animating).
var _input_enabled := false
## What the current finger started on.
enum Gesture { NONE, HAND, SWALLOW }

## Single pointer: the finger that started the gesture owns it.
var _touch_index := -1
var _gesture := Gesture.NONE
## Column under that finger, -1 when it is off the board. Also the timeout
## column; cleared by release and cancel.
var _touch_column := -1
## Hand index of the selected Goob, -1 when none.
var _selected := -1
var _press_pos := Vector2.ZERO
var _dragging := false
## Double tap: what the last tap hit and when.
var _last_tap_key := ""
var _last_tap_msec := -100000
var _inspect: InspectPanel
var _grey: Array[ColorRect] = []
var _shake_tween: Tween
var _fuse: FuseStrip
## After the end: the result overlay minimised so the board can be looked at
## and its Goobs inspected (Sean, M6c playtest); "Show result" brings it back.
var _reviewing := false
## Last touch (or turn start) on the player's turn, msec, for the waiting face.
var _idle_since_msec := 0
var _end_screen: EndScreen
var _fuse_sound: AudioStreamPlayer
## Scoring sequence: the multiplier labels on show, then the sum (stays up
## under the end overlay).
var score_labels: Array[Label] = []
var sum_label: Label


func _ready() -> void:
	_rng.randomize()
	_think_rng.randomize()
	# Art B vignette over the forest + stump, under the board and UI (it matches
	# GameFlow's forest cover, so the board fades cleanly over the forest).
	var vignette := GameFlow.make_vignette()
	add_child(vignette)
	move_child(vignette, _stump.get_index() + 1)
	_build_feedback_nodes()
	_build_hud()
	_opponent_timer = _make_timer(_play_opponent_move)
	_turn_timer = _make_timer(_on_turn_timeout)
	_timeout_timer = _make_timer(_finish_timeout)
	_autoplay_timer = _make_timer(_play_autoplay_move)
	_replay_timer = _make_timer(_auto_replay)
	_end_overlay.visible = false
	Settings.changed.connect(_apply_speed)
	Settings.changed.connect(_apply_turn_timer)
	_apply_speed()
	_board_view.item_rect_changed.connect(_layout_table.call_deferred)
	_layout_table.call_deferred()
	_start_loop()
	_board_view.goob_lookup = _loop.goob_at
	_board_view.status_lookup = _loop.has_status
	_board_view.sync_from_board(_loop.board)
	# The player's first-turn draw is revealed by _after_play(), so the fan
	# starts without it.
	var start_hand := _loop.player_deck.hand.duplicate()
	if _loop.phase == TurnLoop.Phase.PLAYER_TURN:
		for goob in _loop.last_draw:
			start_hand.remove_at(start_hand.rfind(goob))
	_hand.rebuild(start_hand)
	_track_start()
	_start_game()


## Test `deck` wins; else the game's rolled decks (kept over draw replays);
## else roll new ones and remember them.
func _start_loop() -> void:
	if not deck.is_empty():
		_loop.start(GameFlow.player_moves_first, _rng, deck)
		return
	var rolled := GameFlow.rolled_decks
	if not rolled.is_empty():
		var mine: Array[GoobDefinition] = []
		var his: Array[GoobDefinition] = []
		mine.assign(rolled["player"])
		his.assign(rolled["opponent"])
		_loop.start(GameFlow.player_moves_first, _rng, mine, his)
		_loop.player_deck_name = rolled.get("player_name", "")
		_loop.opponent_deck_name = rolled.get("opponent_name", "")
		return
	_loop.start(GameFlow.player_moves_first, _rng, [], [], GameFlow.debug_forced_categories)
	GameFlow.rolled_decks = {"player": _loop.player_goobs, "opponent": _loop.opponent_goobs, "player_name": _loop.player_deck_name, "opponent_name": _loop.opponent_deck_name}


## "Game start" banner first, a short beat, then the first turn's banner
## (Sean, M6c playtest: the first turn banner came too quickly).
func _start_game() -> void:
	if animate_drops:
		_sfx.play(&"game_start")
		_hud.hold_face(&"greeting") # he waves hello (Sean, M6c playtest)
		var fast := Settings.speed != Settings.Speed.NORMAL
		await _hud.show_start_banner(GAME_START_SEC / (Settings.FAST_SCALE if fast else 1.0))
		if not is_inside_tree():
			return
		await _wait(GAME_START_GAP_SEC)
		if not is_inside_tree():
			return
		_hud.hold_face(&"idle")
	_after_play()


func _process(_delta: float) -> void:
	_refresh_timer()
	_refresh_fuse()


## The opponent waits on you: after WAITING_AFTER_SEC of your turn without a
## touch, or while the fuse burns; a touch (or a play) brings him back to idle.
func _refresh_waiting() -> void:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN or not _input_enabled:
		if _hud.base_face() == &"waiting":
			_hud.set_base_face(&"idle")
		return
	var idle_sec := (Time.get_ticks_msec() - _idle_since_msec) / 1000.0
	var waiting := _fuse.visible or idle_sec >= WAITING_AFTER_SEC
	var want := &"waiting" if waiting else &"idle"
	if _hud.base_face() != want:
		_hud.set_base_face(want)


## Low-time fuse (M6c): the last FuseStrip.FUSE_SEC of a running player turn;
## hand Goobs look worried and the fuse crackles while it burns.
func _refresh_fuse() -> void:
	var left := -1.0
	if _loop.phase == TurnLoop.Phase.PLAYER_TURN and not _timed_out and not _turn_timer.is_stopped():
		left = _turn_timer.time_left
	_fuse.set_seconds_left(left)
	_hand.set_worried(_fuse.visible)
	_refresh_waiting()
	if _fuse.visible and not _fuse_sound.playing:
		_fuse_sound.play()
	elif not _fuse.visible and _fuse_sound.playing:
		_fuse_sound.stop()


## HUD countdown: the player's seconds left (30 before the turn unlocks, 0 at a
## timeout), "—" on the opponent's turn, after the end, while auto-play
## plays your turns and with Options "Turn timer" Off.
func _refresh_timer() -> void:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN or not Settings.turn_timer:
		_hud.set_timer(ScenarioHud.NO_TIMER)
	elif _timed_out:
		_hud.set_seconds(0)
	elif GameFlow.autoplay:
		_hud.set_timer(ScenarioHud.NO_TIMER)
	elif not _turn_timer.is_stopped():
		_hud.set_seconds(ceili(_turn_timer.time_left))
	else:
		_hud.set_seconds(ceili(turn_seconds))


## Pixel HUD over the zones (under flashes, toasts and overlays), the pause
## menu on top of everything.
func _build_hud() -> void:
	_hud = ScenarioHud.new()
	add_child(_hud)
	move_child(_hud, get_node("%SafeArea").get_index() + 1)
	_hud.set_objective(OBJECTIVE)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.autoplay_pressed.connect(func() -> void:
		_sfx.play(&"ui_tap")
		set_autoplay(not GameFlow.autoplay))
	_hud.set_autoplay_lit(GameFlow.autoplay)
	_hud.set_autoplay_enabled(Settings.autoplay_button)
	# The option turned off hides the button: give control back too.
	Settings.changed.connect(func() -> void:
		_hud.set_autoplay_enabled(Settings.autoplay_button)
		if GameFlow.autoplay and not Settings.autoplay_button:
			set_autoplay(false))
	_hud.portrait_sound.connect(func(kind: StringName) -> void: _sfx.play(kind))
	_hud.show_result_pressed.connect(func() -> void:
		_sfx.play(&"ui_tap")
		set_reviewing(false))
	_hud.stage.relayout.connect(_fit_hud_slot)
	_pills = StatusPills.new()
	add_child(_pills)
	move_child(_pills, _hud.get_index() + 1)
	_pills.pill_pressed.connect(func(text: String) -> void:
		_toast.show_message(text)
		_place_toast())
	_pause = PauseMenu.new()
	# Time paused doesn't count as the player keeping him waiting.
	_pause.resumed.connect(func() -> void: _idle_since_msec = Time.get_ticks_msec())
	add_child(_pause)
	if OS.is_debug_build():
		_build_debug_panel()
	add_child(EscapeKey.new(handle_escape))


## F4 debug picker (M6e): debug builds only.
func _build_debug_panel() -> void:
	_debug = DebugPanel.new()
	_debug.set_forced(GameFlow.debug_forced_categories)
	_debug.toggle_requested.connect(_on_debug_toggle)
	_debug.give_requested.connect(debug_give)
	_debug.discard_requested.connect(debug_discard_random)
	_debug.status_requested.connect(debug_add_status)
	_debug.new_game_requested.connect(func(forced: Dictionary) -> void:
		GameFlow.debug_forced_categories = forced
		GameFlow.rolled_decks = {}
		GameFlow.replay_after_draw())
	add_child(_debug)


func _on_debug_toggle() -> void:
	if _debug.is_open():
		_debug.close()
		_idle_since_msec = Time.get_ticks_msec()
	elif not _pause.is_open() and not GameFlow.is_fading():
		_end_touch() # a gesture can't finish while the tree is paused
		_debug.open()


## Debug: puts `goob` at the end of `side`'s hand; a full hand drops its oldest
## (index 0) first. The player's fan is rebuilt, so yours only while your hand
## is stable (_hand_stable(); else a "Not now" toast).
func debug_give(goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	if side == BoardState.CellOwner.PLAYER and not _hand_stable():
		_show_not_now()
		return
	_debug_used = true
	var deck := _loop.deck_of(side)
	var hand := deck.hand
	if hand.size() >= Deck.HAND_MAX:
		deck.take(0)
		if side == BoardState.CellOwner.OPPONENT and _opponent_planned():
			# His chosen Goob shifts down; if it was the dropped one, he plays
			# the given one instead (same column).
			_opponent_hand_index = _opponent_hand_index - 1 if _opponent_hand_index > 0 else hand.size()
	deck.add(goob)
	if side == BoardState.CellOwner.PLAYER:
		_end_touch()
		_hand.rebuild(hand)
		if not _autoplay_timer.is_stopped(): # auto-play re-plans with the new hand
			_autoplay_timer.stop()
			_run_autoplay_turn()


## Debug: discards a random Goob from `side`'s hand and shows its reveal. Yours
## only while your hand is stable and never your last Goob (a timeout needs
## one; else a "Not now" toast); his any time (never the Goob he has chosen to
## play).
func debug_discard_random(side: BoardState.CellOwner) -> void:
	_debug_used = true
	var replan := false
	if side == BoardState.CellOwner.PLAYER:
		# Taking your last Goob skips this turn, unless your last turn was
		# skipped too (never two in a row; Sean, 2026-11-23).
		if not _hand_stable() or (_loop.player_deck.hand.size() <= 1 and _loop.was_skipped_last(BoardState.CellOwner.PLAYER)):
			_show_not_now()
			return
		replan = not _autoplay_timer.is_stopped()
		_autoplay_timer.stop() # its chosen hand index is about to shift
	var choices: Array[int] = []
	for i in _loop.deck_of(side).hand.size():
		if not (side == BoardState.CellOwner.OPPONENT and _opponent_planned() and i == _opponent_hand_index):
			choices.append(i)
	if choices.is_empty():
		return
	var index: int = choices[randi_range(0, choices.size() - 1)]
	if side == BoardState.CellOwner.OPPONENT and _opponent_planned() and index < _opponent_hand_index:
		_opponent_hand_index -= 1
	if side == BoardState.CellOwner.PLAYER:
		_end_touch()
	var first := _loop.effect_steps.size()
	_loop.discard_from(side, index)
	# The discard, and a Defiant's drop and landing moves (M6e Discard).
	var steps := _loop.effect_steps.slice(first)
	for step in steps:
		if step.has("discarded"):
			await _play_discard_step(step)
		else:
			await _play_effect(step)
		if not is_inside_tree():
			return
	if steps.size() > 1:
		_board_view.sync_from_board(_loop.board)
		_refresh_hud()
	if not is_inside_tree() or _loop.phase != TurnLoop.Phase.PLAYER_TURN or side != BoardState.CellOwner.PLAYER:
		return
	if _loop.player_deck.hand.is_empty():
		# Your last Goob is gone: this turn is skipped (you draw next turn).
		_set_input_enabled(false)
		_loop.skip_turn()
		_after_play()
	elif replan and GameFlow.autoplay:
		_run_autoplay_turn() # auto-play re-plans with the new hand


## True while your hand can change under the debug panel: your input is on, or
## auto-play is thinking. Not during a drawn-Goob reveal, the timeout reveal
## or a play (the fan is mid-animation or out of step with Deck.hand).
func _hand_stable() -> bool:
	return _input_enabled or not _autoplay_timer.is_stopped()


func _show_not_now() -> void:
	_toast.show_message(MSG_NOT_NOW)
	_place_toast()


## Debug: a two-turn test status on `side`.
func debug_add_status(side: BoardState.CellOwner) -> void:
	_debug_used = true
	_loop.add_status(&"debug", side, "Test", "A test status from the debug panel.", 2)
	_refresh_hud()


## Debug auto-play (M6e; debug builds only): on, the AI plays your turns with
## the opponent's think delay, your timer and fuse hidden and input locked
## (a gesture in progress is cancelled); off gives control back, with a fresh
## turn timer if it was thinking. Kept over draw replays (GameFlow.autoplay).
func set_autoplay(on: bool) -> void:
	if on and not OS.is_debug_build():
		return
	GameFlow.autoplay = on
	_hud.set_autoplay_lit(on)
	if on:
		if _input_enabled and _loop.phase == TurnLoop.Phase.PLAYER_TURN:
			_set_input_enabled(false) # stops the timer, drops the touch and aim
			_run_autoplay_turn()
	elif not _autoplay_timer.is_stopped() or _autoplay_thinking:
		_autoplay_timer.stop()
		_autoplay_thinking = false # its move, when it comes, is dropped
		_set_input_enabled(true)
	_refresh_timer()


## The opponent AI picks your move on a mirrored board (it plays as
## OPPONENT), then thinks like him before playing it.
func _run_autoplay_turn() -> void:
	_autoplay_thinking = true
	var move: Dictionary = await _finish_ai_move(_start_ai_move(BoardState.CellOwner.PLAYER)) # off the main thread too
	if not is_inside_tree() or not _autoplay_thinking:
		return # auto-play turned off (control given back) while it thought
	_autoplay_thinking = false
	if not GameFlow.autoplay or _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return
	if move["column"] == -1:
		set_autoplay(false) # nothing it can play: auto-play off, your turn as usual
		_set_input_enabled(true)
		return
	_autoplay_column = move["column"]
	_autoplay_hand_index = move["hand_index"]
	var wait := _think_sec(move["blocking"] or move["close"])
	if wait > 0.0:
		_autoplay_timer.start(wait)
	else:
		_play_autoplay_move()


func _play_autoplay_move() -> void:
	if GameFlow.autoplay and _loop.phase == TurnLoop.Phase.PLAYER_TURN:
		_play_player(_autoplay_column, _autoplay_hand_index, [], true, true)


## A draw with auto-play on presses Replay by itself (while you view the
## board it waits; set_reviewing(false) arms it again).
func _auto_replay() -> void:
	if GameFlow.autoplay and _end_overlay.visible:
		_on_end_pressed()


## True while the opponent has chosen his move and not played it yet.
func _opponent_planned() -> bool:
	return _loop.phase == TurnLoop.Phase.OPPONENT_TURN and _opponent_hand_index != -1


## The zones reserve the HUD block's height above the board.
func _fit_hud_slot() -> void:
	var insets := SafeArea.insets_for(get_viewport())
	_hud_slot.custom_minimum_size.y = maxf(0.0, ceilf(_hud.bottom() - float(insets.top)))
	_place_banner_band.call_deferred()


## Turn banners go in the gap between the HUD and the board (Sean, 2026-11-20).
func _place_banner_band() -> void:
	_hud.set_banner_band(_hud.bottom(), _board_view.get_global_rect().position.y)
	# Pills go above the aim lane: column input always wins (M6e review).
	_pills.set_band(_hud.bottom(), _aim_lane.get_global_rect().position.y)


## Desktop Esc (Sean, M6f 2026-11-24): closes the topmost menu (debug panel,
## Options, Quit confirm, pause, inspect) like its own button; with nothing
## open it pauses, when the Pause button could. True when it used the key.
func handle_escape() -> bool:
	if _debug != null and _debug.is_open():
		_on_debug_toggle()
		return true
	if _pause.is_open():
		if _pause.is_inspecting():
			_pause.close_inspect()
		elif _pause.options().is_open():
			_pause.options()._on_back()
		elif _pause.is_confirming() or _pause.is_viewing_deck():
			_pause.back_to_menu()
		else:
			_pause.resume()
		return true
	if _inspect.is_open():
		_inspect.close()
		_sfx.play(&"inspect_close")
		return true
	if _end_overlay.visible or _reviewing or GameFlow.is_fading():
		return false
	if _touch_index != -1:
		_end_touch() # a gesture can't finish while the tree is paused
	_on_pause_pressed()
	return true


func _on_pause_pressed() -> void:
	if _end_overlay.visible or GameFlow.is_fading():
		return
	_pause.set_deck(_loop.player_deck_name, _loop.player_goobs, HandView.GOOB_PX * _board_view.hand_px() * 2.0)
	_pause.open()


## Normal / Fast (Settings; also when changed from the pause menu). Tests'
## animate_drops = false turns the play animations off.
func _apply_speed() -> void:
	var on := _animating()
	_board_view.animate = on
	_hand.animate = on
	_board_view.speed_scale = Settings.anim_scale()
	_board_view.shake_enabled = Settings.screen_shake
	_hand.speed_scale = Settings.anim_scale()


func _animating() -> bool:
	return animate_drops


## The opponent's think delay: halved on Fast.
## `hard` (blocking / close call) adds THINK_HARD_SEC; 0 base = no delay.
func _think_sec(hard: bool = false) -> float:
	if opponent_delay_sec <= 0.0:
		return 0.0
	var sec := opponent_delay_sec + _think_rng.randf_range(-THINK_JITTER_SEC, THINK_JITTER_SEC)
	if hard:
		sec += THINK_HARD_SEC
	return sec / Settings.anim_scale()


func _banner_sec() -> float:
	if Settings.speed == Settings.Speed.NORMAL:
		return TURN_BANNER_SEC
	return TURN_BANNER_SEC / Settings.FAST_SCALE


## Turn banner (blue / red ribbon + sting). Tests (animate_drops = false) skip it.
func _show_turn_banner(player: bool) -> void:
	if not animate_drops:
		return
	_sfx.play(&"turn_whoosh", not player) # soft whoosh, a little lower for the opponent
	await _hud.show_turn_banner(player, _banner_sec())


## The biome's hand prop (Forest: an oak stump, Sean 2026-11-19): pixel art
## at the hand Goobs' pixel scale, centred, narrower than the screen so the
## background shows at its sides, running off the bottom. The hand Goobs rest
## on its top, and the fan stays within it.
func _layout_table() -> void:
	var hand_px := _board_view.hand_px()
	_hand.set_pixel_size(hand_px, _board_view.board_px())
	var tex_size := _stump.texture.get_size()
	var ui_scale := float(get_window().size.x) / get_viewport_rect().size.x
	# Goob bottoms (hand_view slot) sit on the stump's seat line.
	var goob_bottom := _hand.global_position.y + HandView.LIFT_PX * hand_px + 8.0 + HandView.GOOB_PX * hand_px
	var pos := Vector2((size.x - tex_size.x * hand_px) * 0.5, goob_bottom - STUMP_SEAT_Y * hand_px)
	_stump.position = (pos * ui_scale).round() / ui_scale
	_stump.size = tex_size * hand_px
	_hand.set_fan_width(STUMP_TOP_WIDTH * hand_px)
	_place_banner_band()
	# Fuse strip centred between the board panel's bottom and the hand.
	var k := _board_view.column_rect(0).size.x / BoardView2D.CELL
	var board_bottom := _board_view.column_rect(0).end.y + BoardView2D.GRID_ORIGIN.y * k
	var hand_top := _hand.global_position.y
	_fuse.place(roundf((board_bottom + hand_top) * 0.5), size.x, k)


func _make_timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _build_feedback_nodes() -> void:
	_toast = Toast.new()
	add_child(_toast)
	_sfx = Sfx.new()
	add_child(_sfx)
	_board_view.drop_sound.connect(_on_drop_sound)
	_hand.hand_sound.connect(_sfx.play)
	for column in BoardState.COLUMNS:
		var grey := ColorRect.new()
		grey.color = COLOR_FULL_GREY
		grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grey.visible = false
		add_child(grey)
		_grey.append(grey)
	_inspect = InspectPanel.new()
	add_child(_inspect)
	move_child(_inspect, _end_overlay.get_index())
	_end_screen = EndScreen.new()
	_end_overlay.add_child(_end_screen)
	_end_screen.view_pressed.connect(_on_view_board_pressed)
	_end_screen.primary_pressed.connect(func() -> void:
		_sfx.play(&"ui_tap")
		_on_end_pressed())
	_fuse = FuseStrip.new()
	_fuse.name = "Fuse"
	add_child(_fuse)
	move_child(_fuse, _inspect.get_index())
	_fuse_sound = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = FUSE_BURN.duplicate()
	loop.loop = true
	_fuse_sound.stream = loop
	_fuse_sound.bus = &"SFX"
	add_child(_fuse_sound)


# --- Touch input (slice §2B) ---------------------------------------------------

## Touch events only: on desktop a click arrives both as a mouse event and as
## an emulated touch, so reading both would act twice. _input (not
## _unhandled_input) so Controls under the finger can't swallow it.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event)
		elif event.index == _touch_index:
			_on_release(event)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_on_drag(event)


func _on_press(event: InputEventScreenTouch) -> void:
	_idle_since_msec = Time.get_ticks_msec()
	if _touch_index != -1:
		return # a second finger; single pointer only
	if PixelStage.touches_button(_hud, event.position) or PixelStage.touches_button(_pills, event.position):
		return # the Pause button or a status pill (normal Control signals)
	if _inspect.is_open():
		# The next tap closes the inspect view and does nothing else.
		_inspect.close()
		_sfx.play(&"inspect_close")
		_start_gesture(event, Gesture.SWALLOW)
		return
	if _reviewing:
		_review_press(event)
		return
	if not _input_enabled:
		return
	var hand_index := _hand.goob_at(event.position)
	if hand_index != -1:
		_start_gesture(event, Gesture.HAND)
		var double := _is_double_tap("hand:%d" % hand_index)
		if _selected != hand_index:
			_sfx.play(&"select")
		_select(hand_index)
		if double:
			_open_inspect(_loop.player_deck.hand[hand_index], BoardState.CellOwner.PLAYER)
			_gesture = Gesture.SWALLOW
		return
	var column := column_at(event.position)
	if column == -1:
		return
	# Board touches never play or aim, even with a Goob selected (only a drag
	# from the hand plays; Sean, M6f 2026-11-24); a double tap on a board Goob
	# inspects it and the selection stays.
	_start_gesture(event, Gesture.SWALLOW)
	var cell := _board_view.cell_at(event.position)
	var goob := _loop.goob_at(cell.x, cell.y)
	if goob != null and _is_double_tap("cell:%d,%d" % [cell.x, cell.y]):
		_open_inspect(goob, _loop.board.get_owner(cell.x, cell.y))
		_gesture = Gesture.SWALLOW


func _start_gesture(event: InputEventScreenTouch, gesture: Gesture) -> void:
	_touch_index = event.index
	_gesture = gesture
	_press_pos = event.position
	_dragging = false
	get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	match _gesture:
		Gesture.HAND:
			if not _dragging and event.position.distance_to(_press_pos) > DRAG_START_PX:
				_dragging = true
				_last_tap_key = "" # a drag is not a tap
				_hand.begin_drag(_selected)
				_sfx.play(&"drag")
			if _dragging:
				_hand.drag_to(event.position)
				var column := column_at(event.position)
				if column != _touch_column:
					_enter_column(column)
				_hand.set_drag_visible(not _board_view.is_preview_visible())


func _on_release(event: InputEventScreenTouch) -> void:
	var gesture := _gesture
	var dragging := _dragging
	_touch_index = -1
	_gesture = Gesture.NONE
	_dragging = false
	get_viewport().set_input_as_handled()
	if not _input_enabled or _selected == -1:
		return
	var column := column_at(event.position)
	var legal := column != -1 and not event.canceled and not _loop.column_blocked(column)
	# Letting go on a full (or Territorial-locked) column is the play attempt:
	# shake + error sound.
	var full := column != -1 and not event.canceled and _loop.column_blocked(column)
	match gesture:
		Gesture.HAND:
			if not dragging:
				return # a tap: the Goob stays selected
			if legal:
				_play_selected(column)
			else:
				# Released off the board (or on a full column): it flies back.
				if full:
					_reject_placement(_blocked_message(column))
				_hand.cancel_drag()
				_sfx.play(&"cancel")
				_clear_aim()
				_select(-1)


func _is_double_tap(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if key == _last_tap_key and now - _last_tap_msec <= DOUBLE_TAP_SEC * 1000.0:
		_last_tap_key = ""
		return true
	_last_tap_key = key
	_last_tap_msec = now
	return false


func _select(index: int) -> void:
	_selected = index
	if _hand.selected() != index:
		_hand.select(index)
	_refresh_grey()


func _open_inspect(goob: GoobDefinition, side: BoardState.CellOwner) -> void:
	_sfx.play(&"inspect_open")
	_inspect.open(goob, side, HandView.GOOB_PX * _board_view.hand_px() * 2.0)


## The finger moved onto `column` (-1 = off the board). A full column shows
## the dark highlight + "Column full" once per entry (this only runs when the
## column under the finger changes); the shake and sound wait for a release.
func _enter_column(column: int) -> void:
	_touch_column = column
	if column == -1:
		_hide_aim()
	elif _loop.column_blocked(column):
		_board_view.hide_preview()
		_show_flash(column, COLOR_FLASH_FULL)
		_toast.show_message(_blocked_message(column))
		_place_toast()
	else:
		# Every column entry clicks (first touch and each slide; Sean 2026-11-19).
		_sfx.play(&"column_tick")
		_show_aim(column)


## The toast for a column you can't play into: full, or locked by his
## Territorial (M6e Tech).
func _blocked_message(column: int) -> String:
	return Toast.MSG_COLUMN_FULL if _loop.board.column_full(column) else Toast.MSG_BLOCKED_CELL


func _clear_aim() -> void:
	_touch_column = -1
	_hide_aim()


## Input locks: drop any gesture, aim, selection and inspect view.
func _end_touch() -> void:
	if _hand.is_dragging():
		_hand.cancel_drag()
	_touch_index = -1
	_gesture = Gesture.NONE
	_dragging = false
	_clear_aim()
	_select(-1)
	_inspect.close()


## Full columns grey out while a Goob is selected (slice §2B).
func _refresh_grey() -> void:
	for column in BoardState.COLUMNS:
		var grey := _grey[column]
		grey.visible = _selected != -1 and _input_enabled and _loop.column_blocked(column)
		if grey.visible:
			var rect := column_hit_rect(column)
			grey.global_position = rect.position
			grey.size = rect.size


## Column whose hit area (column slot + the aim lane above it) contains the
## viewport position, or -1.
func column_at(pos: Vector2) -> int:
	for column in BoardState.COLUMNS:
		if column_hit_rect(column).has_point(pos):
			return column
	return -1


## A column's slot on screen, stretched up through the aim lane.
func column_hit_rect(column: int) -> Rect2:
	var slot := _board_view.column_rect(column)
	var top := _aim_lane.get_global_rect().position.y
	return Rect2(slot.position.x, top, slot.size.x, slot.end.y - top)


func _show_flash(column: int, color: Color) -> void:
	var rect := column_hit_rect(column)
	_flash.color = color
	_flash.global_position = rect.position
	_flash.size = rect.size
	_flash.visible = true


func _hide_flash() -> void:
	_flash.visible = false


## Player aim feedback: blue column flash + their Goob floating on top of the
## board over that column. `goob` defaults to the selected hand Goob.
## `from` (viewport px): where the float Goob flips up from when it first
## appears; default = the selected hand Goob where it is now (M6c).
func _show_aim(column: int, goob: GoobDefinition = null, from: Vector2 = Vector2.INF) -> void:
	var hand := _loop.player_deck.hand
	if goob == null and _selected >= 0 and _selected < hand.size():
		goob = hand[_selected]
	if from == Vector2.INF and _selected >= 0:
		from = _hand.card_center(_selected)
	_show_flash(column, COLOR_FLASH_PLAYER)
	_board_view.show_preview(column, BoardState.CellOwner.PLAYER, goob, from)


func _hide_aim() -> void:
	_hide_flash()
	_board_view.hide_preview()


func _set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		_idle_since_msec = Time.get_ticks_msec()
		_timed_out = false
		if Settings.turn_timer:
			_turn_timer.start(turn_seconds)
	else:
		_turn_timer.stop()
		_end_touch()
	_refresh_grey()
	_refresh_hud()


# --- Turns -------------------------------------------------------------------

## Options "Turn timer" (Sean, 2026-11-27), also changed mid-turn from the
## pause menu: Off stops your countdown (and the fuse); On gives a fresh one.
func _apply_turn_timer() -> void:
	if not Settings.turn_timer:
		_turn_timer.stop()
	elif _input_enabled and not _timed_out and _turn_timer.is_stopped() and _loop.phase == TurnLoop.Phase.PLAYER_TURN:
		_turn_timer.start(turn_seconds)
	_refresh_timer()
	_refresh_fuse()


## Player entry point: plays hand Goob `hand_index` into `column`. Returns
## the landed row, or -1 if it is not the player's turn (silently), the column
## or hand index is invalid (a caller bug), or the column is full (shake +
## sound + toast).
func try_drop(column: int, hand_index: int = 0) -> int:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return -1
	if not _loop.board.is_valid_column(column):
		push_error("Scenario.try_drop: invalid column %d" % column)
		return -1
	if hand_index < 0 or hand_index >= _loop.player_deck.hand.size():
		push_error("Scenario.try_drop: invalid hand index %d" % hand_index)
		return -1
	if _loop.column_blocked(column):
		_reject_placement(_blocked_message(column))
		return -1
	return _play_player(column, hand_index)


## Plays the selected hand Goob into `column` (no undo).
func _play_selected(column: int) -> void:
	_play_player(column, _selected)


## `roll_path`: the timeout roll over full columns (see _roll_path()).
## `in_fan`: false when the card already left the fan (the timeout removes it
## as "Time's up!" shows; removing it again dropped the next card from the
## fan, so taps played the wrong Goob from then on: Sean, M6c playtest).
## `from_behind`: the Goob flips up from behind the board like the
## opponent's (auto-play; Sean, 2026-11-23).
func _play_player(column: int, hand_index: int, roll_path: Array[int] = [], in_fan := true, from_behind := false) -> int:
	_set_input_enabled(false) # locked until the drop finishes
	if in_fan:
		_hand.remove(hand_index)
	var goob: GoobDefinition = _loop.player_deck.hand[hand_index]
	_board_before = _loop.board.copy()
	var before := _play_snapshot(BoardState.CellOwner.PLAYER, hand_index)
	var row := _loop.play(column, hand_index, roll_dir(roll_path))
	if row != -1:
		_track_play(BoardState.CellOwner.PLAYER, goob, column, before)
	_land_then_continue(column, row, BoardState.CellOwner.PLAYER, roll_path, goob, from_behind)
	return row


## The Goob falls (or rolls) into place, its effect steps play in order
## (TurnLoop.effect_steps), then the next turn starts. §4.2 order: land → special effect → win check last (TurnLoop has
## already resolved all three; this shows them in that order).
## `from_behind`: the Goob (the opponent's, or yours on auto-play) flips up
## from behind the board first.
func _land_then_continue(column: int, row: int, side: BoardState.CellOwner, roll_path: Array[int] = [], goob: GoobDefinition = null, from_behind: bool = false) -> void:
	var effect := _loop.last_effect
	var steps := _loop.effect_steps.duplicate()
	# The portrait reacts while it happens (Sean, M6c playtest): a timeout roll
	# as it starts rolling, an effect's outcome as the effect starts, anything
	# else (a three, a block) as the Goob lands.
	var face := _reaction_for(column, side, roll_path, effect)
	var on_effect := face != &"" and (effect.has("target") or effect.has("extra") or effect.has("motions"))
	if face != &"" and roll_path.size() > 1:
		_hud.react(face)
		face = &""
	await _board_view.play_drop(column, row, side, roll_path, goob, from_behind)
	_sfx.play(&"land", side == BoardState.CellOwner.OPPONENT)
	if side == BoardState.CellOwner.PLAYER:
		Settings.vibrate() # one pulse when your Goob lands (slice §2B)
	if face != &"" and not on_effect:
		_hud.react(face)
	var effect_index := steps.find(effect) # a Bouncy / Slippery step can come first
	for i in steps.size():
		await _play_effect(steps[i], face if on_effect and i == effect_index else &"")
		if not is_inside_tree():
			return
	# A turn-start effect (Smouldering) already changed the board: the view
	# catches up when it plays (_play_turn_start).
	if _loop.turn_start_steps.is_empty():
		_board_view.sync_from_board(_loop.board)
		_refresh_hud() # statuses the effects added or ticked
	_after_play()


## Opponent portrait reaction to the play just shown (slice §2B; Sean,
## 2026-11-22): surprised on a chain (Fat's destroy making Goobs fall) or a
## timeout roll; for his play, happy when he makes a new open three or his
## effect hits you; for yours, angry when your effect hits him and sad
## (disappointed) when you break up his threes (a block). Otherwise, when a
## two (a side-by-side pair) is blocked before it becomes a three: "well
## played" when you block his, a giggle when he blocks yours (Sean, M6c
## playtest). Game over is left to the end lead-in.
func _reaction_for(_column: int, side: BoardState.CellOwner, roll_path: Array[int], effect: Dictionary) -> StringName:
	if _loop.phase == TurnLoop.Phase.OVER:
		return &""
	# Before the next turn's start effects (Smouldering) changed it.
	var after: BoardState = _loop.board_after_play if _loop.board_after_play != null else _loop.board
	var hit_other := false
	var chain := false
	if effect.has("target"):
		# Who owned the target just before the effect (a Bouncy / Slippery
		# can move the Goob first, so the board before the play won't do).
		hit_other = effect.get("target_owner", BoardState.CellOwner.EMPTY) == TurnLoop.enemy_of(side)
		chain = _chained(effect)
	for fallen: Dictionary in effect.get("fallen", []):
		# Seismic / Sinking knocked his (your) Goobs off the board (M6e).
		hit_other = hit_other or fallen["owner"] == TurnLoop.enemy_of(side)
	var face := &""
	if chain or roll_path.size() > 1:
		face = &"surprised"
	elif side == BoardState.CellOwner.OPPONENT:
		var threes_before := OpponentAI.open_threes(_board_before, side)
		if hit_other or OpponentAI.open_threes(after, side) > threes_before:
			face = &"happy"
	else:
		var his := BoardState.CellOwner.OPPONENT
		if hit_other:
			face = &"angry"
		elif OpponentAI.open_threes(after, his) < OpponentAI.open_threes(_board_before, his):
			face = &"sad" # disappointed, not angry (Sean, M6c playtest)
	if face == &"":
		var other := TurnLoop.enemy_of(side)
		if OpponentAI.open_lines(after, other, 2, true) < OpponentAI.open_lines(_board_before, other, 2, true):
			face = &"well_played" if side == BoardState.CellOwner.PLAYER else &"giggle"
	return face


## Whether `effect` set off a chain: a destroy made the Goobs above fall
## (Crushing's own fall doesn't count), or a Lopsided / Tipsy rolled after
## falling (M6e).
func _chained(effect: Dictionary) -> bool:
	for step in _loop.effect_steps:
		if step.get("chain", false):
			return true
	# Any destroy this play, also one nested in Occult's returned Goob.
	for step in _loop.effect_steps:
		var own_fall := 1 if step.get("kind") == GoobDefinition.EffectType.DESTROY_BELOW else 0
		if step.get("fell", 0) > own_fall:
			return true
	var own := 1 if effect.get("kind") == GoobDefinition.EffectType.DESTROY_BELOW else 0
	return effect.get("fell", 0) > own


## Shows one TurnLoop effect step: the type's impact on its target (the
## target was picked first, slice §4), a fizzle when it had none, or a
## discard reveal. Plain Goobs' steps (kind NONE) show nothing.
## `face`: the portrait reaction to show as the effect starts ("" = none).
func _play_effect(effect: Dictionary, face: StringName = &"") -> void:
	var kind: GoobDefinition.EffectType = effect.get("kind", GoobDefinition.EffectType.NONE)
	if kind == GoobDefinition.EffectType.NONE and not effect.has("discarded") and not effect.get("stifled", false):
		return
	if effect.get("passive", false):
		return # Bouncy / Slippery / Springy act later, while on the board
	var cell: Vector2i = effect["cell"]
	var side: BoardState.CellOwner = effect["side"]
	if effect.get("instant", false):
		# A Bouncy / Slippery under the played Goob moves it straight away.
		await _board_view.play_move(cell, effect["motions"], Vector2i(-1, -1), false)
		return
	# Let the landing register before the effect starts, and leave room after
	# it before the next turn (Sean, 2026-11-19 playtest).
	await _wait(EFFECT_LEAD_SEC)
	if face != &"":
		_hud.react(face)
	await _play_effect_impact(effect, kind, cell, side)
	await _wait(EFFECT_HOLD_SEC)


func _play_effect_impact(effect: Dictionary, kind: GoobDefinition.EffectType, cell: Vector2i, side: BoardState.CellOwner) -> void:
	if effect.has("discarded"):
		await _play_discard_step(effect)
		return
	if effect.get("stifled", false):
		_toast.show_message(MSG_STIFLED if side == BoardState.CellOwner.PLAYER else MSG_OPPONENT_STIFLED)
		_place_toast()
	if effect["fizzled"]:
		await _board_view.play_fizzle(cell)
		return
	if effect.has("copied"):
		# Nostalgic / Mocking: what it became; that Goob's effect is the next step.
		_toast.show_message(MSG_COPIED % effect["copied"])
		_place_toast()
	if effect.get("cue", false):
		# A discard Goob winds up; its discards are the steps after this one.
		await _board_view.play_cue(cell)
		return
	if effect.has("drawn"):
		await _play_draw_step(effect, cell, side)
		return
	if effect.has("motions"):
		# Move Goobs (M6e): a chain roll has no wind-up.
		await _board_view.play_move(cell, effect["motions"], effect.get("rolled", Vector2i(-1, -1)), not effect.get("chain", false))
		return
	match kind:
		GoobDefinition.EffectType.FLIP_ADJACENT:
			await _board_view.play_flip(cell, effect["target"], side)
		GoobDefinition.EffectType.DESTROY_ADJACENT, GoobDefinition.EffectType.DESTROY_RANDOM, GoobDefinition.EffectType.DESTROY_BELOW, GoobDefinition.EffectType.DESTROY_BESIDE, GoobDefinition.EffectType.DESTROY_LANDER, GoobDefinition.EffectType.DESTROY_LATER, GoobDefinition.EffectType.DISCARD_DESTROY_ENEMY, GoobDefinition.EffectType.DISCARD_DESTROY:
			await _board_view.play_destroy(cell, effect["target"])
		GoobDefinition.EffectType.RESURRECT, GoobDefinition.EffectType.RETURN_DISCARD:
			# Occult / Thrifty: the destroyed (discarded) Goob arcs out of it
			# and drops for you; its own landing and effect are the steps
			# after this one.
			var back: GoobDefinition = effect["returned"]
			var at: Vector2i = effect["extra"]
			await _board_view.play_summon(cell, at.x, side, back, &"resurrect")
			await _board_view.play_drop(at.x, at.y, side, [], back)
			_sfx.play(&"land", side == BoardState.CellOwner.OPPONENT)
		GoobDefinition.EffectType.INSPIRE:
			# Inspiring winds up and lights the friend it sets off; that
			# Goob's own effect is the next step.
			var inspired: Vector2i = effect["inspired"]
			await _board_view.play_cue(cell)
			_board_view.sparkle(inspired, side)
			await _board_view.play_cue(inspired)
		GoobDefinition.EffectType.STEAL:
			# Thieving: the robbed Goob shudders, the thief sparkles.
			var robbed: Vector2i = effect["stolen_from"]
			_toast.show_message(MSG_STOLE % effect["stolen_name"])
			_place_toast()
			await _board_view.play_cue(robbed)
			_board_view.sparkle(cell, side)
			await _board_view.play_cue(cell)
		GoobDefinition.EffectType.EXTRA_VANILLA_DROP:
			var extra: Vector2i = effect["extra"]
			await _board_view.play_summon(cell, extra.x, side)
			await _board_view.play_drop(extra.x, extra.y, side)
			_sfx.play(&"land", side == BoardState.CellOwner.OPPONENT)
			_board_view.sparkle(extra, side)


## A draw effect (Plentiful, Fickle's draw): ghosts fly to the hand, yours pop
## in; a full hand toasts (his fizzles).
func _play_draw_step(effect: Dictionary, cell: Vector2i, side: BoardState.CellOwner) -> void:
	var drawn: Array[GoobDefinition] = effect["drawn"]
	if drawn.is_empty():
		# Hand already full: nothing drawn.
		if side == BoardState.CellOwner.PLAYER:
			_show_hand_full()
		else:
			await _board_view.play_fizzle(cell)
		return
	await _board_view.play_draw_cue(cell, side, drawn.size())
	if side == BoardState.CellOwner.PLAYER:
		if effect["hand_full"]:
			_show_hand_full()
		for goob in drawn:
			await _reveal_drawn(goob)


## A discard step: the reveal; a Defiant then flips up from behind the board
## and drops where TurnLoop played it (its landing moves are the next steps).
func _play_discard_step(effect: Dictionary) -> void:
	var goob: GoobDefinition = effect["discarded"]
	var side: BoardState.CellOwner = effect["side"]
	var played: Vector2i = effect.get("played", Vector2i(-1, -1))
	await _show_discard(goob, side, effect.get("index", -1), played.x >= 0)
	if played.x < 0 or not is_inside_tree():
		return
	await _board_view.play_drop(played.x, played.y, side, [], goob, true)
	_sfx.play(&"land", side == BoardState.CellOwner.OPPONENT)


## Timeout: the column under the finger, else a random one (full included).
## Input locks, "Time's up!" shows and the column flashes, then the Goob drops;
## a full column sends it rolling to the first open one (slice §2B).
func _on_turn_timeout() -> void:
	if _loop.phase != TurnLoop.Phase.PLAYER_TURN:
		return
	# Column under the dragging finger, else random.
	var column := _touch_column if _touch_index != -1 else -1
	if column == -1:
		column = _rng.randi_range(0, BoardState.COLUMNS - 1)
	# The selected (or dragged) Goob, else a random one (Sean, 2026-11-13).
	_timeout_hand_index = _selected
	if _timeout_hand_index == -1:
		_timeout_hand_index = _rng.randi_range(0, _loop.player_deck.hand.size() - 1)
	_set_input_enabled(false)
	_timed_out = true
	Telemetry.track(&"turn_timeout", {"turn": _loop.player_deck.turns, "dragging": _touch_index != -1})
	var from := _hand.card_center(_timeout_hand_index)
	_hand.remove(_timeout_hand_index)
	_toast.show_message(MSG_TIMES_UP)
	_sfx.play(&"times_up")
	_place_toast()
	var rightward := _rng.randi() % 2 == 0
	_timeout_column = _loop.roll_target(column, rightward)
	_timeout_path = _roll_path(column, rightward)
	if timeout_reveal_sec > 0.0:
		_show_aim(column, _loop.player_deck.hand[_timeout_hand_index], from)
		_timeout_timer.start(timeout_reveal_sec)
	else:
		_finish_timeout()


func _finish_timeout() -> void:
	_hide_aim()
	_play_player(_timeout_column, _timeout_hand_index, _timeout_path, false)


## The direction (-1 / +1) a timeout roll along `path` was going when it
## fell (0 = no roll), for a Bouncy it lands on (M6e).
static func roll_dir(path: Array[int]) -> int:
	if path.size() < 2:
		return 0
	return signi(path[-1] - path[-2])


## Columns a Goob played into full `column` rolls over before it falls, for
## the roll animation. Same walk as BoardState.roll_target(); an off-board
## entry (-1 or COLUMNS) marks a bounce off that edge. [column] if it is open.
func _roll_path(column: int, rightward: bool) -> Array[int]:
	var path: Array[int] = [column]
	if _loop.roll_target(column, rightward) == -1:
		return path
	var step := 1 if rightward else -1
	var at := column
	while _loop.column_blocked(at): # a locked column counts as full (M6e Tech)
		if not _loop.board.is_valid_column(at + step):
			path.append(at + step)
			step = -step
		at += step
		path.append(at)
	return path


func _after_play() -> void:
	for side in _loop.last_skipped:
		_toast.show_message(MSG_TURN_SKIPPED if side == BoardState.CellOwner.PLAYER else MSG_OPPONENT_SKIPPED)
		Telemetry.track(&"turn_skipped", {"side": _side_name(side)})
	match _loop.phase:
		TurnLoop.Phase.OVER:
			_show_end()
		TurnLoop.Phase.OPPONENT_TURN:
			_run_opponent_turn()
		_:
			await _show_turn_banner(true)
			if not is_inside_tree():
				return
			await _play_turn_start()
			if not is_inside_tree() or _loop.phase != TurnLoop.Phase.PLAYER_TURN:
				return
			await _show_turn_draw()
			if is_inside_tree() and _loop.phase == TurnLoop.Phase.PLAYER_TURN:
				_refresh_hud() # statuses ticked at the turn start (also on auto-play turns)
				if GameFlow.autoplay:
					_run_autoplay_turn()
				else:
					_set_input_enabled(true)


## Effects that ran at the start of this turn (Smouldering; TurnLoop.
## turn_start_steps), shown once after the turn banner, before the draw.
func _play_turn_start() -> void:
	var steps := _loop.turn_start_steps.duplicate()
	if steps.is_empty():
		return
	_loop.turn_start_steps = [] # shown: never again
	for step in steps:
		await _play_effect(step)
		if not is_inside_tree():
			return
	_board_view.sync_from_board(_loop.board)
	_refresh_hud()


## The player's start-of-turn draw: each drawn Goob pops in big and flies into
## the fan; a draw skipped by a full hand shows "Hand full" + a screen shake.
func _show_turn_draw() -> void:
	if _loop.last_draw_hand_full:
		_show_hand_full()
	for goob in _loop.last_draw:
		await _reveal_drawn(goob)
	await _play_turn_draw_extras(BoardState.CellOwner.PLAYER)


## After `side`'s turn draw (M6e Draw): the Jinxing toast, then the Plentiful
## draws it set off (TurnLoop.turn_draw_steps), each shown once.
func _play_turn_draw_extras(side: BoardState.CellOwner) -> void:
	if _loop.last_jinx_lost > 0:
		var none := _loop.last_draw_count == 0
		if side == BoardState.CellOwner.PLAYER:
			_toast.show_message(MSG_JINXED if none else MSG_JINXED_FEWER % _loop.last_jinx_lost)
		else:
			_toast.show_message(MSG_OPPONENT_JINXED if none else MSG_OPPONENT_JINXED_FEWER % _loop.last_jinx_lost)
		_place_toast()
	var steps := _loop.turn_draw_steps.duplicate()
	_loop.turn_draw_steps = [] # shown: never again
	for step in steps:
		await _play_effect(step)
		if not is_inside_tree():
			return
	if not steps.is_empty():
		_refresh_hud()


## A drawn Goob pops into the hand while its name shows in the gap above the
## board (Sean, M6c playtest). The name stays readable on Fast.
func _reveal_drawn(goob: GoobDefinition) -> void:
	var sec := HandView.REVEAL_POP_SEC + HandView.REVEAL_HOLD_SEC + HandView.REVEAL_FLY_SEC
	_hud.show_caption(goob.display_name, maxf(sec / Settings.anim_scale() if _animating() else 0.0, CAPTION_MIN_SEC))
	await _hand.reveal(goob)


## A discarded Goob (TurnLoop.discard_from, M6e): it pops in at the centre
## while its name shows in the gap, then leaves the screen (down = yours, up =
## his). HandView.DISCARD_SEC, never sped up by Fast; one at a time (await
## it). `index`: the hand index it left (yours leaves the fan there). Tests
## (animate_drops = false) skip the motion.
func _show_discard(goob: GoobDefinition, side: BoardState.CellOwner, index: int = -1, defiant := false) -> void:
	var start_msec := Time.get_ticks_msec()
	_hud.show_caption(goob.display_name, HandView.DISCARD_SEC)
	await _hand.play_discard(goob, side, index, defiant)
	# The tween's first tick can count frame time from before it started: top
	# up to the full length on the clock (a pause already ran it past that).
	while _animating() and is_inside_tree() and Time.get_ticks_msec() - start_msec < HandView.DISCARD_SEC * 1000.0:
		await get_tree().process_frame


## A draw skipped by the hand cap (turn draw or Plentiful): toast + shake.
func _show_hand_full() -> void:
	Telemetry.track(&"hand_full")
	_toast.show_message(MSG_HAND_FULL)
	_sfx.play(&"hand_full")
	_place_toast()
	_shake_screen()


func _on_drop_sound(kind: StringName, side: BoardState.CellOwner) -> void:
	_sfx.play(kind, side == BoardState.CellOwner.OPPONENT)


## Short whole-screen shake in whole logical px (none with Screen shake Off).
func _shake_screen() -> void:
	if not Settings.screen_shake:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for px: int in SCREEN_SHAKE_PX:
		_shake_tween.tween_property(self, "position:x", float(px), SCREEN_SHAKE_STEP_SEC)


## The red banner, then the think delay, then his Goob (no column flash;
## Sean, M6d playtest 2026-11-23).
## The move is chosen up front (the board can't change while he thinks) so a
## block or a close call can think a little longer.
func _run_opponent_turn() -> void:
	_set_input_enabled(false)
	# The AI thinks on a worker thread while the banner and turn start play: a
	# heavy hand took up to ~0.9 s and froze the game right after your play
	# (Sean, 2026-11-28).
	var ai := _start_ai_move(BoardState.CellOwner.OPPONENT)
	# The red banner first, then he thinks (Sean, M6c playtest: the delay was
	# hidden under the banner).
	if animate_drops:
		await _show_turn_banner(false)
		if not is_inside_tree() or _loop.phase != TurnLoop.Phase.OPPONENT_TURN:
			return
	await _play_turn_start()
	if not is_inside_tree() or _loop.phase != TurnLoop.Phase.OPPONENT_TURN:
		return
	await _play_turn_draw_extras(BoardState.CellOwner.OPPONENT)
	if not is_inside_tree() or _loop.phase != TurnLoop.Phase.OPPONENT_TURN:
		return
	_hud.set_base_face(&"thinking") # web builds may still be choosing
	var move: Dictionary = await _finish_ai_move(ai)
	if not is_inside_tree() or _loop.phase != TurnLoop.Phase.OPPONENT_TURN:
		return
	_opponent_column = move["column"]
	_opponent_hand_index = move["hand_index"]
	var wait := _think_sec(move["blocking"] or move["close"])
	if wait > 0.0:
		_opponent_timer.start(wait)
	else:
		_play_opponent_move()


## Starts choosing `side`'s move on a worker thread, from copies of
## everything it reads (the AI plays as OPPONENT: your side is mirrored).
## Returns the handle for _finish_ai_move().
func _start_ai_move(side: BoardState.CellOwner) -> Dictionary:
	if _ai_task != -1: # one at a time (a debug re-plan mid-think)
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1
	var mine := side == BoardState.CellOwner.PLAYER
	var deck := _loop.deck_of(side)
	var hand: Array[GoobDefinition] = deck.hand.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi() # its own rng: the scenario's keeps running meanwhile
	var job := {"hand": hand}
	var board := _loop.board.mirrored() if mine else _loop.board.copy()
	var count := deck.draw_pile.size()
	var goobs := _loop.cell_goobs()
	var piles := _loop.destroyed_piles(mine).duplicate(true)
	var state := _loop.sim_state(mine).duplicate(true)
	var planner := OpponentAI.Planner.new(board, hand, count, rng, goobs, piles, state)
	job["planner"] = planner
	if ai_threads:
		_ai_task = WorkerThreadPool.add_task(planner.step.bind(-1), false, "OpponentAI.choose_move")
		job["task"] = _ai_task
	elif opponent_delay_sec <= 0.0:
		planner.step(-1) # no think delay (tests): nothing to spread it over
	else:
		_step_planner(planner) # web builds: a slice a frame, behind the banner
	return job


## Thinks a slice per frame until `planner` is done (no-threads builds).
func _step_planner(planner: OpponentAI.Planner) -> void:
	while not planner.step(AI_SLICE_USEC) and is_inside_tree():
		await get_tree().process_frame


## Waits (a frame at a time) for the move _start_ai_move() is choosing. If
## the hand changed meanwhile (debug panel), it chooses again from the new one.
func _finish_ai_move(job: Dictionary) -> Dictionary:
	if job.has("task"):
		# No think delay (tests): no frames to hide it behind, so just wait.
		# (_ai_task no longer this one = already waited for elsewhere.)
		while opponent_delay_sec > 0.0 and _ai_task == job["task"] and not WorkerThreadPool.is_task_completed(job["task"]):
			await get_tree().process_frame
		if _ai_task == job["task"]:
			WorkerThreadPool.wait_for_task_completion(job["task"])
			_ai_task = -1
	var planner: OpponentAI.Planner = job["planner"]
	while not planner.done and is_inside_tree():
		await get_tree().process_frame
	if not planner.done:
		return planner.move # left the tree mid-think: no move
	var side := _loop.current_side()
	if job["hand"] != _loop.deck_of(side).hand:
		var mine := side == BoardState.CellOwner.PLAYER
		var deck := _loop.deck_of(side)
		return OpponentAI.choose_move(_loop.board.mirrored() if mine else _loop.board, deck.hand, deck.draw_pile.size(), _rng, _loop.cell_goobs(), _loop.destroyed_piles(mine), _loop.sim_state(mine))
	return planner.move


func _play_opponent_move() -> void:
	var hand_index := _opponent_hand_index
	_opponent_hand_index = -1 # played: no plan until his next turn chooses one
	var goob: GoobDefinition = _loop.opponent_deck.hand[hand_index]
	_hud.set_base_face(&"idle")
	_board_before = _loop.board.copy()
	var before := _play_snapshot(BoardState.CellOwner.OPPONENT, hand_index)
	var row := _loop.play(_opponent_column, hand_index)
	if row == -1:
		push_error("Scenario: opponent chose illegal column %d" % _opponent_column)
		return
	_track_play(BoardState.CellOwner.OPPONENT, goob, _opponent_column, before)
	_land_then_continue(_opponent_column, row, BoardState.CellOwner.OPPONENT, [], goob, true)


func _show_end() -> void:
	_track_end()
	_set_input_enabled(false)
	_hud.set_pause_visible(false)
	_autoplay_timer.stop()
	if _loop.result != TurnLoop.Result.DRAW: # auto-play ends at win / lose
		GameFlow.autoplay = false
		_hud.set_autoplay_lit(false)
	var kind := &"draw"
	match _loop.result:
		TurnLoop.Result.PLAYER_WIN:
			await _lead_in(BoardState.CellOwner.PLAYER)
			if not is_inside_tree():
				return
			await _play_scoring(BoardState.CellOwner.PLAYER)
			if not is_inside_tree():
				return
			await _hud.play_defeat(Settings.anim_scale() if _animating() else 0.0, _defeat_face())
			if not is_inside_tree():
				return
			_board_view.highlight_cells(_loop.scoring_cells(BoardState.CellOwner.PLAYER))
			kind = &"win"
		TurnLoop.Result.OPPONENT_WIN:
			await _lead_in(BoardState.CellOwner.OPPONENT)
			if not is_inside_tree():
				return
			await _play_scoring(BoardState.CellOwner.OPPONENT)
			if not is_inside_tree():
				return
			_board_view.highlight_cells(_loop.scoring_cells(BoardState.CellOwner.OPPONENT))
			kind = &"lose"
	_end_screen.set_result(kind)
	_end_overlay.visible = true
	_end_screen.play_intro.call_deferred(animate_drops)
	if kind == &"draw" and GameFlow.autoplay:
		_replay_timer.start(AUTOPLAY_REPLAY_SEC)


## Win/lose lead-in (slice §2B): the winner's Goobs turn happy, the loser's
## sad, the winning four celebrates; the opponent portrait celebrates his win
## or says "well played" (then cracks and explodes after the scoring). A
## win or lose sting marks it.
func _lead_in(winner: BoardState.CellOwner) -> void:
	_board_view.set_side_face(winner, &"happy")
	_board_view.set_side_face(TurnLoop.enemy_of(winner), &"sad")
	for cell in _loop.scoring_cells(winner):
		_board_view.set_face(cell, &"celebrating")
	var player_won := winner == BoardState.CellOwner.PLAYER
	_hand.set_mood(&"happy" if player_won else &"sad")
	_hud.hold_face(_defeat_face() if player_won else &"celebrating")
	_sfx.play(&"win_sting" if player_won else &"lose_sting")
	await _wait(LEAD_IN_SEC)


## His face when you win: "well played", or angry when a chain this turn
## handed you the four (Sean, M6c playtest 2026-11-23).
func _defeat_face() -> StringName:
	return &"angry" if _chained(_loop.last_effect) else &"well_played"


## Scoring sequence (slice §4, Balatro rhythm): first a moment of recognition
## (gold outline, hop, sting); then every Goob in `side`'s
## winning lines, lowest column first and bottom to top, bounces and shows its
## multiplier (×1 / ×2) above it, one per SCORE_STEP_SEC on a rising note;
## after a pause they collapse into the sum, one big plain number at the board
## centre on the top note (Sean, 2026-11-19). Draws never get here.
func _play_scoring(side: BoardState.CellOwner) -> void:
	var cells := _loop.scoring_cells(side)
	var ladder := Sfx.SCORE_LADDER
	# Recognition first (Sean, 2026-11-20): the scored Goobs light up in gold
	# and hop together before any multiplier appears.
	_board_view.recognise_cells(cells)
	_sfx.play(&"score_recognise")
	await _wait(SCORE_RECOGNISE_SEC)
	var total := 0.0
	# One label per Goob, made up front (hidden) so the row in the gap can be
	# laid out: slot i, centred on the gap, labels evenly spaced.
	var widths := 0.0
	for cell in cells:
		var goob := _loop.goob_at(cell.x, cell.y)
		# Only tests place Goobs without a definition; count those as Vanilla.
		var multiplier := goob.multiplier if goob != null else TurnLoop.VANILLA.multiplier
		total += multiplier
		var label := _make_score_label("×" + format_score(multiplier), &"Mono2", Color.WHITE)
		label.visible = false
		score_labels.append(label)
		widths = maxf(widths, label.size.x)
	var gap := gap_center()
	var spacing := minf(widths + SCORE_SLOT_GAP, size.x * 0.9 / maxf(1.0, cells.size()))
	for i in cells.size():
		var cell := cells[i]
		var label := score_labels[i]
		_sfx.play(ladder[mini(i, ladder.size() - 1)])
		await _board_view.flip_cell(cell, true)
		if not is_inside_tree():
			return
		_place_centered(label, _board_view.cell_center(cell))
		label.visible = true
		await _wait(SCORE_SHOW_SEC)
		var slot := gap + Vector2((i - (cells.size() - 1) * 0.5) * spacing, 0.0)
		_board_view.flip_cell(cell, false)
		if _animating():
			var ui_scale := float(get_window().size.x) / get_viewport_rect().size.x
			var to := ((slot - label.size * 0.5) * ui_scale).round() / ui_scale
			var float_up := create_tween().set_speed_scale(Settings.anim_scale())
			float_up.tween_property(label, "global_position", to, SCORE_FLOAT_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			await float_up.finished
		else:
			_place_centered(label, slot)
		await _wait(maxf(0.0, SCORE_STEP_SEC - SCORE_SHOW_SEC - SCORE_FLOAT_SEC))
	await _wait(SCORE_PAUSE_SEC)
	var centre := gap
	_sfx.play(&"score_collapse")
	if _animating():
		var collapse := create_tween().set_parallel().set_speed_scale(Settings.anim_scale())
		for label in score_labels:
			collapse.tween_property(label, "position", centre - label.size * 0.5, SCORE_COLLAPSE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			collapse.tween_property(label, "modulate:a", 0.0, SCORE_COLLAPSE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await collapse.finished
	for label in score_labels:
		label.queue_free()
	score_labels.clear()
	sum_label = _make_score_label(format_score(total), &"Mono3", COLOR_WIN if side == BoardState.CellOwner.PLAYER else COLOR_LOSE)
	_place_centered(sum_label, centre)
	_sfx.play(ladder[mini(cells.size(), ladder.size() - 1)])
	if _animating():
		sum_label.pivot_offset = sum_label.size * 0.5
		sum_label.scale = Vector2(0.3, 0.3)
		create_tween().set_speed_scale(Settings.anim_scale()).tween_property(sum_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(SCORE_HOLD_SEC)


## 1 → "1", 0.5 → "0.5", 3.5 → "3.5".
static func format_score(value: float) -> String:
	var text := String.num(value, 1)
	return text.trim_suffix(".0")


func _make_score_label(text: String, variation: StringName, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_SCORE_OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	move_child(label, _end_overlay.get_index()) # under the end overlay
	label.reset_size()
	return label


## Centres `control` on `pos`, on a whole physical pixel.
func _place_centered(control: Control, pos: Vector2) -> void:
	var ui_scale := float(get_window().size.x) / get_viewport_rect().size.x
	control.global_position = ((pos - control.size * 0.5) * ui_scale).round() / ui_scale


## Waits `sec` (at the animation speed) on a child timer (freed with the
## scene, so a pending wait just stops; paused with the tree). No wait when
## animations are off (tests).
func _wait(sec: float) -> void:
	if not _animating() or sec <= 0.0:
		return
	var timer := _make_timer(func() -> void: pass)
	timer.start(sec / Settings.anim_scale())
	await timer.timeout
	timer.queue_free()



## §4.6 feedback: shake + error sound + toast.
func _reject_placement(message: String) -> void:
	Telemetry.track(&"column_full_attempt", {"message": message})
	_board_view.shake()
	_sfx.play(&"error")
	Settings.vibrate()
	_toast.show_message(message)
	_place_toast()


## Toasts sit just above the aim lane.
## Every text notification goes in the gap between the HUD and the board
## (Sean, M6c playtest), like the turn banners and the drawn Goob's name.
func _place_toast() -> void:
	_place_centered(_toast, gap_center())


## Centre of the gap between the HUD and the board (viewport px).
func gap_center() -> Vector2:
	return Vector2(size.x * 0.5, (_hud.bottom() + _board_view.get_global_rect().position.y) * 0.5)


func _refresh_hud() -> void:
	_refresh_timer()
	_pills.show_statuses(_loop.statuses)


## Review after the end: a double tap on a board or hand Goob inspects it;
## nothing else reacts. The Show result button is a normal Control.
func _review_press(event: InputEventScreenTouch) -> void:
	_start_gesture(event, Gesture.SWALLOW)
	var hand_index := _hand.goob_at(event.position)
	if hand_index != -1:
		if _is_double_tap("hand:%d" % hand_index):
			_open_inspect(_loop.player_deck.hand[hand_index], BoardState.CellOwner.PLAYER)
		return
	var cell := _board_view.cell_at(event.position)
	var goob := _loop.goob_at(cell.x, cell.y)
	if goob != null and _is_double_tap("cell:%d,%d" % [cell.x, cell.y]):
		_open_inspect(goob, _loop.board.get_owner(cell.x, cell.y))


func _on_view_board_pressed() -> void:
	_sfx.play(&"ui_tap")
	set_reviewing(true)


## Minimises (true) or restores (false) the end overlay. While minimised the
## sum stays hidden so no Goob is covered.
func set_reviewing(on: bool) -> void:
	_reviewing = on
	_end_overlay.visible = not on
	_hud.set_show_result_visible(on)
	if sum_label:
		sum_label.visible = not on
	if not on and GameFlow.autoplay and _loop.result == TurnLoop.Result.DRAW and _loop.phase == TurnLoop.Phase.OVER:
		_replay_timer.start(AUTOPLAY_REPLAY_SEC)


func is_reviewing() -> bool:
	return _reviewing


func _on_end_pressed() -> void:
	if _loop.result == TurnLoop.Result.DRAW:
		GameFlow.replay_after_draw()
	else:
		GameFlow.return_to_title()


# --- Play data (M6g) ---------------------------------------------------------

## A quit (pause → Quit, or the app closing) before the end: what was played.
func _exit_tree() -> void:
	if _ai_task != -1: # left mid-think (Quit, a scene change): never leak the task
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1
	if _stats.is_empty() or _stats_sent:
		return
	_stats_sent = true
	var props := {
		"turns": _loop.player_deck.turns + _loop.opponent_deck.turns,
		"duration_sec": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"debug": _debug_game(),
	}
	props.merge(Telemetry.perf_end())
	Telemetry.track(&"scenario_quit", props)


func _track_start() -> void:
	_started_msec = Time.get_ticks_msec()
	_stats = {}
	for side: BoardState.CellOwner in [BoardState.CellOwner.PLAYER, BoardState.CellOwner.OPPONENT]:
		_stats[side] = {"played": [], "held": []}
	Telemetry.perf_begin()
	Telemetry.track(&"scenario_start", {
		"player_first": GameFlow.player_moves_first,
		"specials": _loop.player_goobs.filter(func(g: GoobDefinition) -> bool: return g.id != "vanilla").size(),
		"player_deck": _goob_ids(_loop.player_goobs),
		"opponent_deck": _goob_ids(_loop.opponent_goobs),
		"player_decklist": _loop.player_deck_name,
		"opponent_decklist": _loop.opponent_deck_name,
		"auto_flip": Settings.auto_flip,
		"turn_timer": Settings.turn_timer,
		"autoplay": GameFlow.autoplay,
		"speed": "fast" if Settings.speed == Settings.Speed.FAST else "normal",
		"debug": _debug_game(),
	})


## Before `side` plays its hand Goob at `hand_index`: how long it waited, the
## turn and the hand size.
func _play_snapshot(side: BoardState.CellOwner, hand_index: int) -> Dictionary:
	var hand_deck := _loop.deck_of(side)
	return {"held": hand_deck.held_turns(hand_index), "turn": hand_deck.turns, "hand_size": hand_deck.hand.size()}


## One play: the Goob, how many turns it waited in hand (0 = played at once)
## and its effects (fizzled or not).
func _track_play(side: BoardState.CellOwner, goob: GoobDefinition, column: int, before: Dictionary) -> void:
	var stats: Dictionary = _stats.get(side, {})
	if stats.is_empty() or goob == null:
		return
	stats["played"].append(goob.id)
	stats["held"].append(before["held"])
	var mine := side == BoardState.CellOwner.PLAYER
	if mine and GameFlow.autoplay:
		_autoplay_used = true
	var effects: Array = []
	for step in _loop.effect_steps:
		var kind: int = step.get("kind", GoobDefinition.EffectType.NONE)
		if kind == GoobDefinition.EffectType.NONE:
			continue
		effects.append({"kind": str(GoobDefinition.EffectType.find_key(kind)).to_lower(), "fizzled": step.get("fizzled", false)})
	Telemetry.track(&"goob_played", {
		"side": _side_name(side),
		"goob": goob.id,
		"column": column,
		"turn": before["turn"],
		"turns_held": before["held"],
		"hand_size": before["hand_size"],
		"timeout": mine and _timed_out,
		"autoplay": mine and GameFlow.autoplay,
		"effects": effects,
	})


## The end of the scenario: the result, then per side its deck, what it played
## (in order, with turns held), what was left in hand, discarded and
## destroyed, and the Goobs in its winning four; plus the performance sample.
## Goob win rates and combinations come from these (tools/telemetry/goob_stats.py).
func _track_end() -> void:
	if _stats.is_empty() or _stats_sent:
		return
	_stats_sent = true
	var result := "draw"
	var winner := BoardState.CellOwner.EMPTY
	match _loop.result:
		TurnLoop.Result.PLAYER_WIN:
			result = "win"
			winner = BoardState.CellOwner.PLAYER
		TurnLoop.Result.OPPONENT_WIN:
			result = "lose"
			winner = BoardState.CellOwner.OPPONENT
	var props := {
		"result": result,
		"turns": _loop.player_deck.turns + _loop.opponent_deck.turns,
		"duration_sec": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"autoplay_used": _autoplay_used,
		"debug": _debug_game(),
		"score": 0.0,
	}
	for side: BoardState.CellOwner in _stats:
		var prefix := _side_name(side) + "_"
		var side_deck := _loop.deck_of(side)
		props[prefix + "deck"] = _goob_ids(_loop.player_goobs if side == BoardState.CellOwner.PLAYER else _loop.opponent_goobs)
		props[prefix + "played"] = _stats[side]["played"]
		props[prefix + "held"] = _stats[side]["held"]
		props[prefix + "left_in_hand"] = _goob_ids(side_deck.hand)
		props[prefix + "discarded"] = _goob_ids(side_deck.discard_pile)
		props[prefix + "destroyed"] = _goob_ids(side_deck.destroyed_pile)
		var line: Array = []
		if side == winner:
			var score := 0.0
			for cell in _loop.scoring_cells(side):
				var goob := _loop.goob_at(cell.x, cell.y)
				line.append(goob.id if goob != null else "vanilla")
				score += goob.multiplier if goob != null else TurnLoop.VANILLA.multiplier
			props["score"] = score
		props[prefix + "winning_line"] = line
	props.merge(Telemetry.perf_end())
	Telemetry.track(&"scenario_end", props)


func _debug_game() -> bool:
	return _debug_used or not GameFlow.debug_forced_categories.is_empty() or not deck.is_empty()


static func _goob_ids(goobs: Array) -> Array:
	return goobs.map(func(g: GoobDefinition) -> String: return g.id if g != null else "")


static func _side_name(side: BoardState.CellOwner) -> String:
	return "player" if side == BoardState.CellOwner.PLAYER else "opponent"
