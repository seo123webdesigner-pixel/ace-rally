class_name PhysicsLab
extends Node3D

## Single responsibility: a bench for firing shots and watching the arc.
##
## This scene exists because the ball has to be tuned by eye and nobody can tune
## by eye from a test log. It fires a shot on demand, draws the PREDICTED landing
## point as a ring the moment the ball leaves, and then reports how far the real
## first bounce missed that ring. If that error is ever non-zero, prediction and
## simulation have drifted apart and the AI cannot be trusted.
##
## Debug tooling. Nothing here ships.

## Ball leaves from the player's baseline at roughly waist height, travelling -Z.
const LAUNCH_HEIGHT: float = 1.0

## Prediction search window. A rally shot lands in under 2 s.
const PREDICT_WINDOW: float = 6.0

@export var surfaces: Array[CourtSurfaceConfig] = []

@onready var _ball: Ball = $Ball
@onready var _court: Court = $Court
@onready var _ring: MeshInstance3D = $LandingRing
@onready var _ring_material: StandardMaterial3D = _ring.get_surface_override_material(0)

@onready var _speed_slider: HSlider = $UI/Panel/VBox/SpeedRow/Slider
@onready var _angle_slider: HSlider = $UI/Panel/VBox/AngleRow/Slider
@onready var _spin_slider: HSlider = $UI/Panel/VBox/SpinRow/Slider
@onready var _axis_slider: HSlider = $UI/Panel/VBox/AxisRow/Slider
@onready var _speed_value: Label = $UI/Panel/VBox/SpeedRow/Value
@onready var _angle_value: Label = $UI/Panel/VBox/AngleRow/Value
@onready var _spin_value: Label = $UI/Panel/VBox/SpinRow/Value
@onready var _axis_value: Label = $UI/Panel/VBox/AxisRow/Value
@onready var _surface_picker: OptionButton = $UI/Panel/VBox/SurfaceRow/Picker
@onready var _fire_button: Button = $UI/Panel/VBox/FireButton
@onready var _readout: Label = $UI/Panel/VBox/Readout
@onready var _stats: Label = $UI/Stats

var _prediction: LandingPrediction
var _awaiting_bounce: bool = false

## Distance in metres between the predicted ring and the real first bounce, or -1
## before the first shot has landed. The label below is for the human; this is
## here so a headless test can assert the ring really does sit under the ball.
var last_landing_error: float = -1.0

var _launch_time_msec: int = 0
var _last_report: String = "Fire a shot."


func _ready() -> void:
	for slider: HSlider in [_speed_slider, _angle_slider, _spin_slider, _axis_slider]:
		slider.value_changed.connect(_on_any_slider_changed)
	_fire_button.pressed.connect(_fire)
	_surface_picker.item_selected.connect(_on_surface_selected)
	EventBus.ball_bounced.connect(_on_ball_bounced)

	for surface: CourtSurfaceConfig in surfaces:
		_surface_picker.add_item(surface.surface_name)
	if not surfaces.is_empty():
		_surface_picker.select(0)
		_on_surface_selected(0)

	_ring.visible = false
	_refresh_slider_labels()
	_readout.text = _last_report


func _process(_delta: float) -> void:
	# Frame cost readout. The acceptance criterion is under 5 ms and this is the
	# only place a human can read it, since the window is not observable from a test.
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_stats.text = "%d fps   process %.2f ms   physics %.2f ms   draw calls %d" % [
		Engine.get_frames_per_second(),
		process_ms,
		physics_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	]


## Builds the launch vector from the panel and fires, drawing the prediction ring
## before the ball has travelled a single frame.
func _fire() -> void:
	var surface: CourtSurfaceConfig = _current_surface()
	if surface == null:
		return

	var origin: Vector3 = Vector3(0.0, LAUNCH_HEIGHT, CourtDimensions.BASELINE_Z)
	var angle: float = deg_to_rad(_angle_slider.value)
	var speed: float = _speed_slider.value
	var velocity: Vector3 = Vector3(0.0, speed * sin(angle), -speed * cos(angle))

	_ball.surface = surface
	_ball.launch(origin, velocity, _spin_vector())

	_prediction = _ball.simulator.predict_landing(PREDICT_WINDOW, surface)
	_show_ring(_prediction)
	_awaiting_bounce = true
	_launch_time_msec = Time.get_ticks_msec()
	_readout.text = "In flight..."


## Spin axis as an angle around the direction of travel, so one slider covers the
## whole family: 0 deg topspin, 180 backspin, 90 and 270 the two sidespins.
func _spin_vector() -> Vector3:
	var magnitude: float = _spin_slider.value
	if is_zero_approx(magnitude):
		return Vector3.ZERO
	var theta: float = deg_to_rad(_axis_slider.value)
	# Travelling -Z, topspin is angular velocity about -X.
	var axis: Vector3 = Vector3(-cos(theta), sin(theta), 0.0)
	return axis.normalized() * magnitude


func _show_ring(prediction: LandingPrediction) -> void:
	_ring.visible = prediction.found
	if not prediction.found:
		return
	_ring.global_position = Vector3(prediction.position.x, 0.01, prediction.position.z)
	_ring_material.albedo_color = (
		Color(0.2, 0.9, 0.35) if prediction.in_bounds else Color(0.95, 0.3, 0.25)
	)


func _on_ball_bounced(position: Vector3, _surface_type: int) -> void:
	if not _awaiting_bounce:
		return
	_awaiting_bounce = false

	if _prediction == null or not _prediction.found:
		_readout.text = "Bounced at %s but nothing was predicted." % _format_xz(position)
		return

	var error: float = (
		Vector2(position.x, position.z) - Vector2(_prediction.position.x, _prediction.position.z)
	).length()
	last_landing_error = error
	var wall_ms: float = float(Time.get_ticks_msec() - _launch_time_msec)

	_last_report = "\n".join([
		"predicted  %s   t %.3f s   %s" % [
			_format_xz(_prediction.position),
			_prediction.time,
			"IN" if _prediction.in_bounds else "OUT",
		],
		"actual     %s   t %.3f s   %s" % [
			_format_xz(position),
			wall_ms / 1000.0,
			"IN" if _court.is_in_bounds(position) else "OUT",
		],
		"error      %.4f m" % error,
		"depth from far baseline  %.2f m" % (position.z + CourtDimensions.BASELINE_Z),
	])
	_readout.text = _last_report


func _on_surface_selected(index: int) -> void:
	var surface: CourtSurfaceConfig = _current_surface_at(index)
	if surface == null:
		return
	_ball.surface = surface
	_court.surface = surface


func _on_any_slider_changed(_value: float) -> void:
	_refresh_slider_labels()


func _refresh_slider_labels() -> void:
	_speed_value.text = "%.1f m/s" % _speed_slider.value
	_angle_value.text = "%.1f deg" % _angle_slider.value
	_spin_value.text = "%.0f rad/s" % _spin_slider.value
	_axis_value.text = "%.0f deg (%s)" % [_axis_slider.value, _axis_name(_axis_slider.value)]


func _axis_name(degrees: float) -> String:
	var wrapped: float = fposmod(degrees, 360.0)
	if wrapped < 45.0 or wrapped >= 315.0:
		return "topspin"
	if wrapped < 135.0:
		return "side L"
	if wrapped < 225.0:
		return "backspin"
	return "side R"


func _current_surface() -> CourtSurfaceConfig:
	return _current_surface_at(_surface_picker.selected)


func _current_surface_at(index: int) -> CourtSurfaceConfig:
	if index < 0 or index >= surfaces.size():
		return null
	return surfaces[index]


func _format_xz(p: Vector3) -> String:
	return "x %+7.3f  z %+8.3f" % [p.x, p.z]
