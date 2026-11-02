@tool
extends EditorPlugin
## Editor toolbar: [Git: <branch ▾>] [Sync] [↻]
## Sync = fetch, switch to the picked branch, fast-forward pull, rescan files.
## Git work happens in git_sync_runner.gd on a worker thread.

const Runner := preload("res://addons/git_sync/git_sync_runner.gd")

var _bar: HBoxContainer
var _branches: OptionButton
var _sync_button: Button
var _refresh_button: Button
var _dialog: AcceptDialog
var _thread: Thread
var _repo := ""


func _enter_tree() -> void:
	_repo = ProjectSettings.globalize_path("res://").trim_suffix("/")
	_build_ui()
	add_control_to_container(CONTAINER_TOOLBAR, _bar)
	_run_async(_do_refresh)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	remove_control_from_container(CONTAINER_TOOLBAR, _bar)
	_bar.queue_free()
	_dialog.queue_free()


func _build_ui() -> void:
	_bar = HBoxContainer.new()
	_bar.name = "GitSync"
	var label := Label.new()
	label.text = "Git:"
	_bar.add_child(label)

	_branches = OptionButton.new()
	_branches.name = "BranchPicker"
	_branches.custom_minimum_size.x = 160
	_branches.tooltip_text = "Branch to switch to"
	_bar.add_child(_branches)

	_sync_button = Button.new()
	_sync_button.name = "SyncButton"
	_sync_button.text = "Sync"
	_sync_button.tooltip_text = "Fetch, switch to the picked branch and pull. Local edits are stashed, not lost."
	_sync_button.pressed.connect(_on_sync_pressed)
	_bar.add_child(_sync_button)

	_refresh_button = Button.new()
	_refresh_button.name = "RefreshButton"
	_refresh_button.text = "↻"
	_refresh_button.tooltip_text = "Fetch and refresh the branch list"
	_refresh_button.pressed.connect(func() -> void: _run_async(_do_refresh))
	_bar.add_child(_refresh_button)

	_dialog = AcceptDialog.new()
	_dialog.title = "Git Sync"
	_dialog.min_size = Vector2i(640, 320)
	# Not exclusive: the sync often finishes while Godot's own "files changed
	# on disk" dialog is open, and two exclusive children of one window error.
	_dialog.exclusive = false
	EditorInterface.get_base_control().add_child(_dialog)


func _on_sync_pressed() -> void:
	if _branches.selected < 0:
		_show("No branch selected. Press ↻ to load branches.")
		return
	var branch := _branches.get_item_text(_branches.selected)
	_run_async(_do_sync.bind(branch))


# --- Worker-thread jobs (no UI calls here) ---------------------------------

func _do_refresh() -> Dictionary:
	var fetched := Runner.fetch(_repo)
	return {
		"kind": "refresh",
		"fetched": fetched,
		"branches": Runner.list_branches(_repo),
		"current": Runner.current_branch(_repo),
	}


func _do_sync(branch: String) -> Dictionary:
	var r := Runner.sync(_repo, branch)
	r.kind = "sync"
	r.branches = Runner.list_branches(_repo)
	r.current = Runner.current_branch(_repo)
	return r


# --- Threading -------------------------------------------------------------

func _run_async(job: Callable) -> void:
	if _thread and _thread.is_started():
		if _thread.is_alive():
			return # one job at a time
		_thread.wait_to_finish()
	_set_busy(true)
	_thread = Thread.new()
	_thread.start(func() -> void: _on_job_done.call_deferred(job.call()))


func _on_job_done(result: Dictionary) -> void:
	_thread.wait_to_finish()
	_set_busy(false)
	_fill_branches(result.branches, result.current)
	if result.kind == "refresh":
		if not result.fetched:
			push_warning("Git Sync: fetch failed (offline, or git not on PATH?)")
		return
	var log: PackedStringArray = result.log
	print("Git Sync:\n", "\n".join(log))
	if result.ok:
		EditorInterface.get_resource_filesystem().scan()
		_show("✔ Synced.\n\n" + "\n".join(log))
	else:
		_show("✖ Sync stopped — nothing was overwritten.\n\n" + "\n".join(log))


func _fill_branches(branches: PackedStringArray, current: String) -> void:
	var keep := current
	if _branches.selected >= 0 and _branches.get_item_text(_branches.selected) in branches:
		keep = _branches.get_item_text(_branches.selected)
	_branches.clear()
	var pick := -1
	for b in branches:
		_branches.add_item(b)
		if b == keep:
			pick = _branches.item_count - 1
	# OptionButton auto-selects item 0; never let Sync target a branch nobody
	# picked (e.g. when the current branch isn't on the remote).
	_branches.select(pick)
	_branches.tooltip_text = "Current branch: %s" % current


func _set_busy(busy: bool) -> void:
	_sync_button.disabled = busy
	_refresh_button.disabled = busy
	_sync_button.text = "Syncing…" if busy else "Sync"


func _show(text: String) -> void:
	_dialog.dialog_text = text
	_dialog.popup_centered()
