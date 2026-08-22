extends GutTest

## Guards against a script that nothing references yet quietly failing to parse.
##
## `godot --headless --quit --path .` only touches scripts reachable from the main
## scene and the autoloads, and it exits 0 regardless. Checking each file with
## `--check-only` from outside does not work either, because autoload identifiers
## such as GameLog are not registered in that mode. Loading them from inside a
## running project is the check that actually holds.

const SEARCH_ROOTS: Array[String] = ["res://scripts", "res://test"]


func test_every_project_script_loads() -> void:
	var paths: PackedStringArray = _collect_scripts()
	assert_gt(paths.size(), 0, "should have found at least one script to check")

	var failed: PackedStringArray = PackedStringArray()
	for path in paths:
		var script: Resource = load(path)
		if script == null or not (script is GDScript):
			failed.append(path)

	assert_eq(
		", ".join(failed),
		"",
		"every script under %s should load as a GDScript" % ", ".join(SEARCH_ROOTS)
	)


func _collect_scripts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = SEARCH_ROOTS.duplicate()

	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				pending.append(full_path)
			elif entry.ends_with(".gd"):
				found.append(full_path)
			entry = dir.get_next()
		dir.list_dir_end()

	found.sort()
	return found
