extends Node
## Diagnostics & play data (autoload `Telemetry`, M6g; Sean 2026-11-25):
## crashes and script errors to Sentry, play and performance events to
## PostHog, for the builds testers play.
##
## Sends only from an exported build (never the editor or F5), only while
## Options "Send diagnostics" is On (default On), and only with the keys in
## `config/telemetry_keys.gd` (gitignored; copy telemetry_keys.example.gd).
## Anonymous: a random install id, no personal data. It never blocks the game
## and never shows the player an error.
##
## PostHog events wait in a queue: sent 20 at a time or every 30 s, kept on
## disk when the app goes to the background or quits (or a send fails) and
## sent on the next launch; at most QUEUE_CAP, oldest dropped first. Every
## event is also a Sentry breadcrumb, so a crash report shows what led to it.
##
## Sentry's own auto-init is off (project setting); `_start_sentry()` starts
## it. Its classes are reached by name so this script still parses where the
## addon has no library (e.g. Linux).
##
## Web builds (itch.io test page for iPhones; Sean 2026-11-25): the addon has
## no web library, so `_start_web_sentry()` loads Sentry's browser SDK (pinned,
## SRI-checked) with the same DSN, and `WebErrorLogger` forwards Godot errors
## to it. Events become breadcrumbs there too. A hidden tab saves and sends
## the queue (iOS Safari never sends paused or close).

const KEYS_PATH := "res://config/telemetry_keys.gd"
const ID_PATH := "user://telemetry.cfg"
const QUEUE_PATH := "user://telemetry_queue.jsonl"
const BATCH_MAX := 20
const FLUSH_SEC := 30.0
const QUEUE_CAP := 1000
const HTTP_TIMEOUT_SEC := 10.0
## A frame slower than this counts as a hitch (below 30 fps).
const SLOW_FRAME_SEC := 1.0 / 30.0
## Longer frames are the app in the background, not a hitch: left out.
const MAX_FRAME_SEC := 5.0
const APP_NAME := "four-in-a-rogue"
const SENTRY_JS_URL := "https://browser.sentry-cdn.com/11.18.0/bundle.min.js"
const SENTRY_JS_SRI := "sha384-Cwj8RRLJltjNFXNgSSvKNM0ejeR8dcYIRnlP1vLwHCbNvBYfd2O2UUg2WZSalGgs"

var install_id := ""
var session_id := ""
## Queued PostHog events, oldest first ({event, timestamp, properties}).
var queue: Array = []
var queue_path := QUEUE_PATH
var id_path := ID_PATH
## Tests: on without an export or keys, and `sender` replaces the HTTP post
## (it gets the batch and must call sent(ok)).
var force_enabled := false
var sender: Callable
var sentry_started := false
## Web: Sentry's browser SDK is on (`_start_web_sentry`).
var web_sentry_started := false
## Tests: replaces JavaScriptBridge.eval (gets the JS code).
var js_runner: Callable

var _posthog_key := ""
var _posthog_host := ""
var _sentry_dsn := ""
var _http: HTTPRequest
var _web_logger: WebErrorLogger
## Events being sent now (the first N of the queue), 0 = none.
var _sending := 0
var _flush_left := FLUSH_SEC
var _perf_on := false
var _frame_sec := PackedFloat32Array()
var _peak_static_mem := 0
var _load_time_sent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_keys()
	_load_install_id()
	session_id = new_uuid()
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SEC
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	Settings.changed.connect(_on_settings_changed)
	if not Settings.diagnostics:
		return
	_load_queue()
	_start_sentry()
	_start_web_sentry()
	track(&"app_start", device_info())


## Whether play events go to PostHog.
func posthog_enabled() -> bool:
	if force_enabled:
		return true
	return Settings.diagnostics and _exported() and not _posthog_key.is_empty()


## Whether Sentry may start.
func sentry_allowed() -> bool:
	return Settings.diagnostics and _exported() and not _sentry_dsn.is_empty() and Engine.has_singleton("SentrySDK")


## Whether Sentry's browser SDK may start (web builds only).
func web_sentry_allowed() -> bool:
	return Settings.diagnostics and _exported() and OS.has_feature("web") and not _sentry_dsn.is_empty()


## A Godot error on web (from WebErrorLogger) → Sentry's browser SDK.
func report_error(message: String, where: String, stack: String) -> void:
	if not web_sentry_started:
		return
	_js("goobSentry.run(function(S){S.captureMessage(%s,{level:'error',extra:{where:%s,stack:%s}})})" % [
		JSON.stringify(message), JSON.stringify(where), JSON.stringify(stack)])


## Records `event` (snake_case) with `props`: a Sentry breadcrumb and a queued
## PostHog event. Does nothing while diagnostics are off.
func track(event: StringName, props := {}) -> void:
	if sentry_started:
		var crumb: Object = ClassDB.instantiate("SentryBreadcrumb")
		if crumb != null:
			crumb.set("message", String(event))
			crumb.set("category", "game")
			crumb.set("data", props)
			Engine.get_singleton("SentrySDK").call("add_breadcrumb", crumb)
	if web_sentry_started:
		_js("goobSentry.run(function(S){S.addBreadcrumb({category:'game',message:%s})})" % JSON.stringify(String(event)))
	if not posthog_enabled():
		return
	var properties := base_properties()
	properties.merge(props, true)
	queue.append({
		"event": String(event),
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"properties": properties,
	})
	while queue.size() > QUEUE_CAP:
		queue.pop_front()
		_sending = maxi(_sending - 1, 0)
	if queue.size() - _sending >= BATCH_MAX:
		flush()


## Sent with every event.
func base_properties() -> Dictionary:
	return {
		"distinct_id": install_id,
		"$process_person_profile": false, # anonymous events, no person profiles
		"session_id": session_id,
		"build": build_name(),
		"environment": environment(),
		"platform": OS.get_name(),
	}


## Device and renderer, sent once per launch (app_start) and as Sentry context.
func device_info() -> Dictionary:
	var screen := DisplayServer.screen_get_size()
	var info := {
		"model": OS.get_model_name(),
		"os_version": OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"screen": "%dx%d" % [screen.x, screen.y],
		"window": "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"cpu_cores": OS.get_processor_count(),
	}
	# The model is generic on web; the browser's user agent tells phones apart.
	if OS.has_feature("web"):
		info["user_agent"] = str(JavaScriptBridge.eval("navigator.userAgent", true))
	return info


## "0.1.0" from project setting application/config/version.
func build_name() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func environment() -> String:
	return "debug" if OS.is_debug_build() else "release"


## Sends the oldest queued events (up to BATCH_MAX) unless a send is running.
func flush() -> void:
	_flush_left = FLUSH_SEC
	if _sending > 0 or queue.is_empty() or not posthog_enabled():
		return
	_sending = mini(queue.size(), BATCH_MAX)
	var batch := queue.slice(0, _sending)
	if sender.is_valid():
		sender.call(batch)
		return
	var body := JSON.stringify({"api_key": _posthog_key, "batch": batch})
	var err := _http.request(_posthog_host.trim_suffix("/") + "/batch/", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		sent(false)


## The send of the current batch finished: drop it from the queue, or keep it
## (on disk too) to try again later.
func sent(ok: bool) -> void:
	if ok:
		queue = queue.slice(_sending)
	_sending = 0
	if not ok:
		save_queue()
	elif queue.size() >= BATCH_MAX:
		flush.call_deferred()


## The queue to disk (nothing left = no file).
func save_queue() -> void:
	if queue.is_empty():
		if FileAccess.file_exists(queue_path):
			DirAccess.remove_absolute(queue_path)
		return
	var file := FileAccess.open(queue_path, FileAccess.WRITE)
	if file == null:
		return
	for entry in queue:
		file.store_line(JSON.stringify(entry))


## Starts the per-scenario performance sample (scenario_start).
func perf_begin() -> void:
	_perf_on = true
	_frame_sec = PackedFloat32Array()
	_peak_static_mem = 0


## Ends the sample: frames, average and 5th-percentile fps, hitches (frames
## under 30 fps), the worst frame and the peak static memory. {} if none.
func perf_end() -> Dictionary:
	_perf_on = false
	var count := _frame_sec.size()
	if count == 0:
		return {}
	var total := 0.0
	var slow := 0
	for sec in _frame_sec:
		total += sec
		if sec > SLOW_FRAME_SEC:
			slow += 1
	var sorted := _frame_sec.duplicate()
	sorted.sort()
	var p95_sec := sorted[mini(int(count * 0.95), count - 1)]
	return {
		"frames": count,
		"avg_fps": snappedf(count / maxf(total, 0.001), 0.1),
		"p5_fps": snappedf(1.0 / maxf(p95_sec, 0.0001), 0.1),
		"slow_frames": slow,
		"worst_frame_ms": snappedf(sorted[count - 1] * 1000.0, 0.1),
		"peak_static_mem_mb": snappedf(_peak_static_mem / 1048576.0, 0.1),
	}


## Boot → title, once per launch (the title calls it when it is ready).
func mark_load_time() -> void:
	if _load_time_sent:
		return
	_load_time_sent = true
	track(&"load_time", {"ms": Time.get_ticks_msec()})


## A random version-4 UUID.
static func new_uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


func _process(delta: float) -> void:
	if _perf_on and delta < MAX_FRAME_SEC:
		_frame_sec.append(delta)
		_peak_static_mem = maxi(_peak_static_mem, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_flush_left -= delta
	if _flush_left <= 0.0:
		flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			track(&"app_background")
			save_queue()
			flush()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_queue()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("web"):
				track(&"app_background")
				save_queue()
				flush()


## Exported builds only: F5 and the editor's headless runs never send.
func _exported() -> bool:
	return not OS.has_feature("editor")


func _load_keys() -> void:
	if not ResourceLoader.exists(KEYS_PATH):
		return
	var script := load(KEYS_PATH) as Script
	if script == null:
		return
	var keys := script.get_script_constant_map()
	_posthog_key = str(keys.get("POSTHOG_KEY", ""))
	_posthog_host = str(keys.get("POSTHOG_HOST", "https://us.i.posthog.com"))
	_sentry_dsn = str(keys.get("SENTRY_DSN", ""))


func _load_install_id() -> void:
	var cfg := ConfigFile.new()
	cfg.load(id_path)
	install_id = str(cfg.get_value("telemetry", "install_id", ""))
	if install_id.is_empty():
		install_id = new_uuid()
		cfg.set_value("telemetry", "install_id", install_id)
		cfg.save(id_path)


func _load_queue() -> void:
	var file := FileAccess.open(queue_path, FileAccess.READ)
	if file == null:
		return
	var saved: Array = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var entry: Variant = JSON.parse_string(line)
		if entry is Dictionary:
			saved.append(entry)
	file.close()
	saved.append_array(queue)
	queue = saved.slice(maxi(saved.size() - QUEUE_CAP, 0))


func _start_sentry() -> void:
	if sentry_started or not sentry_allowed():
		return
	var sdk := Engine.get_singleton("SentrySDK")
	sdk.call("init", func(options: Object) -> void:
		options.set("dsn", _sentry_dsn)
		options.set("environment", environment())
		options.set("release", "%s@%s" % [APP_NAME, build_name()]))
	sentry_started = true
	var user: Object = ClassDB.instantiate("SentryUser")
	if user != null:
		user.set("id", install_id)
		sdk.call("set_user", user)
	sdk.call("set_context", "device_game", device_info())


## Web: loads Sentry's browser SDK once (`window.goobSentry` queues calls
## until it has loaded), then forwards Godot errors to it.
func _start_web_sentry() -> void:
	if web_sentry_started or not web_sentry_allowed():
		return
	var cfg := {
		"dsn": _sentry_dsn, "environment": environment(), "release": "%s@%s" % [APP_NAME, build_name()],
		"user": install_id, "device": device_info(), "url": SENTRY_JS_URL, "sri": SENTRY_JS_SRI,
	}
	_js("""(function(cfg){
	var g = window.goobSentry;
	if (!g) {
		g = window.goobSentry = {q: [], ready: false, on: true, run: function(f) {
			if (!g.on) return;
			if (g.ready) { try { f(window.Sentry); } catch (e) {} }
			else if (g.q.length < 100) g.q.push(f);
		}};
		var s = document.createElement('script');
		s.src = cfg.url; s.integrity = cfg.sri; s.crossOrigin = 'anonymous';
		s.onload = function() {
			Sentry.init({dsn: cfg.dsn, environment: cfg.environment, release: cfg.release});
			Sentry.setUser({id: cfg.user});
			Sentry.setContext('device_game', cfg.device);
			g.ready = true;
			var q = g.q; g.q = [];
			q.forEach(g.run);
		};
		document.head.appendChild(s);
	}
	g.on = true;
})(%s)""" % JSON.stringify(cfg))
	if _web_logger == null:
		_web_logger = WebErrorLogger.new()
		_web_logger.report = report_error
	OS.add_logger(_web_logger)
	web_sentry_started = true


func _stop_web_sentry() -> void:
	if not web_sentry_started:
		return
	OS.remove_logger(_web_logger)
	_js("if (window.goobSentry) goobSentry.on = false;")
	web_sentry_started = false


func _js(code: String) -> void:
	if js_runner.is_valid():
		js_runner.call(code)
	elif OS.has_feature("web"):
		JavaScriptBridge.eval(code, true)


## Options "Send diagnostics": Off drops the queue and stops Sentry; On
## starts them again.
func _on_settings_changed() -> void:
	if Settings.diagnostics:
		_start_sentry()
		_start_web_sentry()
		return
	queue.clear()
	_sending = 0
	save_queue()
	if sentry_started:
		Engine.get_singleton("SentrySDK").call("close")
		sentry_started = false
	_stop_web_sentry()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	sent(result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300)
