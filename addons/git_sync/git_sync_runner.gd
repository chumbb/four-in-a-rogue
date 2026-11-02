@tool
extends RefCounted
## Git logic for the Git Sync editor plugin. No editor/UI code here, so it can
## be tested headlessly (tests/test_git_sync.gd). All calls are blocking —
## the plugin runs sync() on a worker thread.

const REMOTE := "origin"


## Fetch, switch to `branch` and fast-forward it to the remote.
## Tracked local edits are stashed first (recoverable with `git stash pop`);
## untracked files are left alone. Never merges, rebases or discards commits:
## if the branch has diverged, it stops and reports.
## Returns { ok: bool, log: PackedStringArray, stashed: String }.
static func sync(repo: String, branch: String) -> Dictionary:
	var result := {"ok": false, "log": PackedStringArray(), "stashed": ""}
	var log: PackedStringArray = result.log

	if not _step(repo, ["rev-parse", "--is-inside-work-tree"], log):
		log.append("Not a git repository: %s" % repo)
		return result

	# Compare content, not file stats: on Windows `git status` flags files
	# Godot re-saved with LF over a CRLF checkout even though nothing changed.
	# Exit code only (0 clean, 1 changed): git also prints CRLF warnings to
	# stderr, which must not count as changes.
	var dirty := git(repo, ["diff", "--quiet", "HEAD"])
	if dirty.code > 1:
		log.append(dirty.text)
		return result
	if dirty.code == 1:
		var label := "git-sync auto-stash %s" % Time.get_datetime_string_from_system(false, true)
		# Identity flags only matter if the user has none configured.
		if not _step(repo, ["-c", "user.name=git-sync", "-c", "user.email=git-sync@localhost",
				"stash", "push", "-m", label], log):
			return result
		result.stashed = label
		log.append("Stashed local changes as \"%s\" (restore with: git stash pop)." % label)

	if not _step(repo, ["fetch", REMOTE, "--prune"], log):
		return result

	if current_branch(repo) != branch:
		# Creates a tracking branch from origin/<branch> if needed.
		if not _step(repo, ["checkout", branch], log):
			return result

	if not _step(repo, ["pull", "--ff-only", REMOTE, branch], log):
		log.append("Could not fast-forward %s — local and remote have diverged. Nothing was changed." % branch)
		return result

	var head := git(repo, ["log", "-1", "--format=%h %s"])
	log.append("On %s at %s" % [branch, head.text])
	result.ok = true
	return result


## Remote branch names (without "origin/"), from the last fetch.
static func list_branches(repo: String) -> PackedStringArray:
	var names := PackedStringArray()
	var r := git(repo, ["for-each-ref", "--format=%(refname:lstrip=3)", "refs/remotes/%s" % REMOTE])
	if r.code != 0:
		return names
	var text: String = r.text
	for line in text.split("\n", false):
		var name: String = line.strip_edges()
		if name != "HEAD" and not name.is_empty():
			names.append(name)
	return names


static func current_branch(repo: String) -> String:
	return git(repo, ["rev-parse", "--abbrev-ref", "HEAD"]).text


static func fetch(repo: String) -> bool:
	return git(repo, ["fetch", REMOTE, "--prune"]).code == 0


## Runs `git -C repo <args>`. Returns { code: int, text: String } (stdout+stderr).
static func git(repo: String, args: Array) -> Dictionary:
	var full := PackedStringArray(["-C", repo])
	full.append_array(PackedStringArray(args))
	var out: Array = []
	var code := OS.execute("git", full, out, true)
	return {"code": code, "text": "".join(out).strip_edges()}


static func _step(repo: String, args: Array, log: PackedStringArray) -> bool:
	var r := git(repo, args)
	var shown := PackedStringArray(args)
	log.append("$ git %s" % " ".join(shown))
	if not r.text.is_empty():
		log.append(r.text)
	return r.code == 0
