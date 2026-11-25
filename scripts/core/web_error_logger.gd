class_name WebErrorLogger
extends Logger
## Godot errors → `report` (web builds; Sean 2026-11-25). The Sentry addon has
## no web library, so `Telemetry` sends these to Sentry's browser SDK instead.
## Warnings are skipped. `report(message, where, stack)`.

var report: Callable
var _busy := false


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	# An error while reporting must not report itself again.
	if error_type == ERROR_TYPE_WARNING or _busy or not report.is_valid():
		return
	_busy = true
	var message := rationale if not rationale.is_empty() else code
	var stack := script_backtraces[0].format() if not script_backtraces.is_empty() else ""
	report.call(message, "%s:%d (%s)" % [file, line, function], stack)
	_busy = false
