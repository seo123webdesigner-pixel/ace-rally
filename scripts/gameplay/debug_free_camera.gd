class_name DebugFreeCamera
extends Camera3D

## Single responsibility: let a human fly around the physics lab to look at an arc
## from any angle. Debug tooling, not shipped gameplay.
##
## Runs in _process, which is correct here and NOT a breach of CLAUDE.md section 3
## rule 7: that rule governs the simulation, and this camera affects nothing but
## what is on screen.
##
## Reads keys through Input.is_key_pressed rather than named actions, so the lab
## does not have to add anything to the project's input map.

@export var move_speed: float = 8.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.005

var _yaw: float = 0.0
var _pitch: float = 0.0
var _looking: bool = false


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	# Hold right mouse to look. Unhandled, so the control panel gets first refusal
	# on every click and dragging a slider never swings the camera.
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
			Input.set_mouse_mode(
				Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
			)
		return

	if event is InputEventMouseMotion and _looking:
		var motion: InputEventMouseMotion = event
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var direction: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= basis.z
	if Input.is_key_pressed(KEY_S):
		direction += basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= basis.x
	if Input.is_key_pressed(KEY_D):
		direction += basis.x
	if Input.is_key_pressed(KEY_E):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		direction -= Vector3.UP

	if direction == Vector3.ZERO:
		return

	var speed: float = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier
	position += direction.normalized() * speed * delta
