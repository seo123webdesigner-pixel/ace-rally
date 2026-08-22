extends GutTest

## Smoke tests. These exist to prove the toolchain itself works, not the game.

const MAIN_SCENE_PATH: String = "res://scenes/core/main.tscn"


func test_runner_executes_a_trivial_assertion() -> void:
	assert_eq(2 + 2, 4, "GUT is running and assertions are evaluated")


func test_main_scene_instantiates_and_enters_tree_without_error() -> void:
	# main.tscn is authored as text without an editor, so loading it here is the
	# only proof the file is actually valid. GUT registers an engine error
	# tracker for the duration of each test and treats any engine error or
	# push_error raised in here as a failure, so "no error" is enforced by the
	# runner rather than by an assertion of our own.
	var packed: PackedScene = load(MAIN_SCENE_PATH)
	assert_not_null(packed, "main.tscn should load as a PackedScene")
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	assert_not_null(instance, "main.tscn should instantiate")
	if instance == null:
		return

	add_child_autofree(instance)
	await wait_physics_frames(2)

	assert_true(instance.is_inside_tree(), "the instance should be in the scene tree")
	assert_not_null(instance.get_script(), "the root node should have its script attached")
	assert_eq(instance.name, &"Main", "root node should be named Main")


func test_main_reports_its_runtime_environment() -> void:
	# describe_environment() is what _ready() feeds to the logger. Asserting on it
	# here proves the entry point's log line is populated, which is otherwise only
	# observable by reading stdout.
	var instance: Node = load(MAIN_SCENE_PATH).instantiate()
	add_child_autofree(instance)
	await wait_physics_frames(1)

	var lines: PackedStringArray = instance.describe_environment()
	assert_eq(lines.size(), 4, "should report version, tick rate, renderer and headless flag")
	assert_string_contains(lines[0], "godot version:")
	assert_string_contains(lines[1], "physics ticks per second: 60")
	assert_string_contains(lines[2], "renderer: mobile")
	assert_string_contains(lines[3], "headless:")
