class_name Main
extends Node3D

## Single responsibility: the project entry point. It reports the runtime
## environment on ready and owns nothing else yet.

const SYSTEM: String = "main"


func _ready() -> void:
	for line in describe_environment():
		GameLog.info(SYSTEM, line)


## Returns the environment facts as plain strings. Split out from _ready so a
## headless test can assert on the contents without capturing stdout.
func describe_environment() -> PackedStringArray:
	var version: Dictionary = Engine.get_version_info()
	return PackedStringArray([
		"godot version: %s" % version.get("string", "unknown"),
		"physics ticks per second: %d" % Engine.physics_ticks_per_second,
		"renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"headless: %s" % str(DisplayServer.get_name() == "headless"),
	])
