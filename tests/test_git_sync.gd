extends SceneTree
## Headless tests for the Git Sync editor plugin's runner, against throwaway
## local git repos (a bare "origin", an author clone and a "Sean" clone).
## Run: godot --headless -s res://tests/test_git_sync.gd

const Runner := preload("res://addons/git_sync/git_sync_runner.gd")

var _failures := 0
var _checks := 0
var _root := ""


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	_root = OS.get_user_data_dir().path_join("git_sync_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root)
	var origin := _root.path_join("origin.git")
	var author := _root.path_join("author")
	var mine := _root.path_join("mine")

	_sh(_root, ["init", "-q", "--bare", "-b", "main", origin])
	_sh(_root, ["clone", "-q", origin, author])
	_write(author, "a.txt", "one")
	_write(author, "eol.txt", "line1\nline2\n")
	_commit(author, "first")
	_sh(author, ["push", "-q", "origin", "main"])
	_sh(author, ["checkout", "-q", "-b", "feature"])
	_write(author, "feature.txt", "f")
	_commit(author, "feature work")
	_sh(author, ["push", "-q", "origin", "feature"])
	_sh(author, ["checkout", "-q", "main"])
	_sh(_root, ["clone", "-q", origin, mine])

	_test_line_endings_only_not_stashed(mine)
	_test_lists_branches(mine)
	_test_switch_to_remote_branch(mine)
	_test_dirty_tree_is_stashed(mine)
	_test_pulls_new_commits(author, mine)
	_test_diverged_fails_safely(author, mine)
	_test_unknown_branch_fails(mine)
	_test_not_a_repo_fails()

	_rm_rf(_root)
	_check(not DirAccess.dir_exists_absolute(_root), "temp repos cleaned up")
	_check(_checks >= 23, "expected checks ran (%d)" % _checks)
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## Windows: autocrlf checks files out with CRLF, Godot re-saves them with LF.
## git status calls that modified, but the content is identical — must not stash.
func _test_line_endings_only_not_stashed(mine: String) -> void:
	_sh(mine, ["config", "core.autocrlf", "true"])
	DirAccess.remove_absolute(mine.path_join("eol.txt"))
	_sh(mine, ["checkout", "--", "eol.txt"])
	_check(_read(mine, "eol.txt") == "line1\r\nline2\r\n", "eol.txt checked out with CRLF")
	_write(mine, "eol.txt", "line1\nline2\n") # Godot-style LF re-save, same content
	_check(_sh(mine, ["status", "--porcelain", "--untracked-files=no"]) != "", "git status reports it modified (the trap)")
	var r: Dictionary = Runner.sync(mine, "main")
	_check(r.ok, "sync with line-ending-only change succeeds: %s" % "\n".join(r.log))
	_check(r.stashed == "", "line-ending-only change is not stashed")
	_sh(mine, ["config", "--unset", "core.autocrlf"])


func _test_lists_branches(mine: String) -> void:
	var branches: PackedStringArray = Runner.list_branches(mine)
	_check("main" in branches and "feature" in branches, "lists remote branches (got %s)" % str(branches))
	_check(not ("HEAD" in branches), "HEAD is not listed as a branch")
	_check(Runner.current_branch(mine) == "main", "current branch is main")


func _test_switch_to_remote_branch(mine: String) -> void:
	var r: Dictionary = Runner.sync(mine, "feature")
	_check(r.ok, "switch to feature succeeds: %s" % "\n".join(r.log))
	_check(Runner.current_branch(mine) == "feature", "now on feature")
	_check(FileAccess.file_exists(mine.path_join("feature.txt")), "feature file present")


func _test_dirty_tree_is_stashed(mine: String) -> void:
	_write(mine, "a.txt", "local edit")
	var r: Dictionary = Runner.sync(mine, "main")
	_check(r.ok, "sync with local edits succeeds: %s" % "\n".join(r.log))
	_check(r.stashed != "", "local edits were stashed")
	_check(Runner.current_branch(mine) == "main", "switched to main after stash")
	_check(_read(mine, "a.txt") == "one", "working file matches main")
	var stash: String = _sh(mine, ["stash", "list"])
	_check("git-sync" in stash, "stash entry is labelled (got '%s')" % stash)


func _test_pulls_new_commits(author: String, mine: String) -> void:
	_write(author, "b.txt", "two")
	_commit(author, "second")
	_sh(author, ["push", "-q", "origin", "main"])
	var r: Dictionary = Runner.sync(mine, "main")
	_check(r.ok, "pull succeeds: %s" % "\n".join(r.log))
	_check(FileAccess.file_exists(mine.path_join("b.txt")), "new commit pulled")
	_check(r.stashed == "", "clean tree is not stashed")


func _test_diverged_fails_safely(author: String, mine: String) -> void:
	_write(mine, "local.txt", "mine")
	_commit(mine, "local commit")
	_write(author, "c.txt", "three")
	_commit(author, "third")
	_sh(author, ["push", "-q", "origin", "main"])
	var head_before: String = _sh(mine, ["rev-parse", "HEAD"])
	var r: Dictionary = Runner.sync(mine, "main")
	_check(not r.ok, "diverged branch reports failure")
	_check(_sh(mine, ["rev-parse", "HEAD"]) == head_before, "diverged sync leaves local commit untouched")


func _test_unknown_branch_fails(mine: String) -> void:
	var r: Dictionary = Runner.sync(mine, "does-not-exist")
	_check(not r.ok, "unknown branch reports failure")


func _test_not_a_repo_fails() -> void:
	var plain := _root.path_join("plain")
	DirAccess.make_dir_recursive_absolute(plain)
	var r: Dictionary = Runner.sync(plain, "main")
	_check(not r.ok, "non-repo folder reports failure")


# --- helpers ---------------------------------------------------------------

func _sh(dir: String, args: Array) -> String:
	var out: Array = []
	var full := PackedStringArray(["-C", dir, "-c", "user.name=t", "-c", "user.email=t@t"])
	full.append_array(PackedStringArray(args))
	var code := OS.execute("git", full, out, true)
	if code != 0:
		printerr("git %s failed: %s" % [" ".join(args), "".join(out)])
	return "".join(out).strip_edges()


func _commit(dir: String, msg: String) -> void:
	_sh(dir, ["add", "-A"])
	_sh(dir, ["commit", "-q", "-m", msg])


func _write(dir: String, name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)


func _read(dir: String, name: String) -> String:
	return FileAccess.get_file_as_string(dir.path_join(name))


func _rm_rf(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_rm_rf(path.path_join(sub))
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
