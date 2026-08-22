class_name BallSimulator
extends RefCounted

## Single responsibility: integrate one tennis ball through the air and off the
## ground, deterministically, with no reference to any node.
##
## The AI aims by re-running this integrator forward from the current state, so
## step() and predict_landing() must produce identical numbers. Two rules keep
## that true and both are load-bearing:
##
##   1. There is exactly ONE integrator, _substep(). Live stepping and prediction
##      both go through it. Never write a second copy "just for prediction".
##   2. The simulator owns its timestep. step() accumulates whatever delta it is
##      handed and runs whole SIM_DT substeps; prediction runs the same SIM_DT
##      substeps. Integrating the same flight at two different timesteps drifts by
##      roughly 0.1 m over a 20 m shot, which is a visible error on a line call.
##
## Prediction is side-effect free: it works on a duplicate of the state and never
## touches self.

## 120 Hz, deliberately twice the physics tick rate. See NOTES.md, Sprint 1.
const SIM_DT: float = 1.0 / 120.0

## Ceiling on substeps per predict_landing call, so a bad launch vector cannot
## spin forever. 20 s of flight at 120 Hz; a real rally shot is under 2 s.
const MAX_PREDICTION_SUBSTEPS: int = 2400

var config: BallPhysicsConfig

var _state: BallState = BallState.new()

## Unintegrated time left over from the last step(). Stays exactly 0.0 while the
## caller feeds whole multiples of SIM_DT, which a 60 Hz _physics_process does.
var _accumulator: float = 0.0

var position: Vector3:
	get:
		return _state.position
	set(value):
		_state.position = value

var velocity: Vector3:
	get:
		return _state.velocity
	set(value):
		_state.velocity = value

var spin: Vector3:
	get:
		return _state.spin
	set(value):
		_state.spin = value

var is_live: bool:
	get:
		return _state.is_live
	set(value):
		_state.is_live = value

## Seconds integrated since the last reset().
var elapsed: float:
	get:
		return _state.elapsed


func _init(p_config: BallPhysicsConfig = null) -> void:
	config = p_config if p_config != null else BallPhysicsConfig.new()


## Places the ball and makes it live. Clears the substep accumulator so a launch
## always starts on a substep boundary.
func reset(pos: Vector3, vel: Vector3, p_spin: Vector3) -> void:
	_state.position = pos
	_state.velocity = vel
	_state.spin = p_spin
	_state.is_live = true
	_state.elapsed = 0.0
	_accumulator = 0.0


## Advances the ball by `delta` seconds and returns every bounce that happened,
## in order. Returns an empty array when the ball is dead or nothing was hit.
func step(delta: float, surface: CourtSurfaceConfig) -> Array[BounceEvent]:
	var events: Array[BounceEvent] = []
	if not _state.is_live or delta <= 0.0:
		return events

	_accumulator += delta
	while _accumulator >= SIM_DT:
		_accumulator -= SIM_DT
		var event: BounceEvent = _substep(_state, SIM_DT, config, surface)
		if event != null:
			events.append(event)
		if not _state.is_live:
			_accumulator = 0.0
			break

	return events


## Re-runs the integrator forward on a copy of the state and reports the first
## bounce. Side-effect free. This is the method the AI depends on.
func predict_landing(max_time: float, surface: CourtSurfaceConfig) -> LandingPrediction:
	var prediction: LandingPrediction = LandingPrediction.new()
	if not _state.is_live:
		return prediction

	var state: BallState = _state.duplicate_state()
	var start_elapsed: float = state.elapsed
	var substeps: int = mini(int(ceilf(max_time / SIM_DT)), MAX_PREDICTION_SUBSTEPS)

	for i: int in substeps:
		var event: BounceEvent = _substep(state, SIM_DT, config, surface)
		if event == null:
			continue
		prediction.found = true
		prediction.position = event.position
		prediction.time = event.time - start_elapsed
		prediction.incoming_velocity = event.incoming_velocity
		prediction.in_bounds = CourtDimensions.is_in_bounds(event.position)
		return prediction

	return prediction


## Where the ball will be `t` seconds from now, side-effect free.
##
## Whole SIM_DT substeps plus one partial remainder, so a `t` that is a multiple
## of SIM_DT lands on exactly the state step() would have reached.
func predict_position_at_time(t: float, surface: CourtSurfaceConfig) -> Vector3:
	if t <= 0.0 or not _state.is_live:
		return _state.position

	var state: BallState = _state.duplicate_state()
	var full_substeps: int = mini(int(t / SIM_DT), MAX_PREDICTION_SUBSTEPS)

	for i: int in full_substeps:
		_substep(state, SIM_DT, config, surface)
		if not state.is_live:
			return state.position

	var remainder: float = t - float(full_substeps) * SIM_DT
	if remainder > 0.0:
		_substep(state, remainder, config, surface)

	return state.position


## One integration substep. Semi-implicit Euler, in the order given by the sprint
## brief. Mutates `state` and returns a BounceEvent, or null if nothing was hit.
##
## Static and taking its state as an argument on purpose: prediction hands it a
## throwaway copy, so there is no way for the two paths to diverge.
static func _substep(
	state: BallState,
	dt: float,
	physics: BallPhysicsConfig,
	surface: CourtSurfaceConfig
) -> BounceEvent:
	var v: Vector3 = state.velocity

	# 1. Quadratic drag, opposing travel. Guarded because Vector3.normalized()
	# returns zero at the apex of a vertical launch, where speed is exactly 0.
	var drag_accel: Vector3 = Vector3.ZERO
	var speed_squared: float = v.length_squared()
	if speed_squared > 0.0:
		var drag_force: float = (
			0.5 * physics.air_density * physics.drag_coefficient
			* physics.cross_section_area() * speed_squared
		)
		drag_accel = -v.normalized() * (drag_force / physics.mass)

	# 2. Magnus. Lumped empirical constant, linear in speed rather than quadratic.
	var magnus_accel: Vector3 = physics.magnus_coefficient * state.spin.cross(v) / physics.mass

	# 3. Gravity.
	var gravity_accel: Vector3 = Vector3(0.0, -physics.gravity, 0.0)

	# 4, 5. Velocity first, then position from the NEW velocity: semi-implicit.
	var previous_position: Vector3 = state.position
	state.velocity += (drag_accel + magnus_accel + gravity_accel) * dt
	state.position += state.velocity * dt

	# 6. Spin decay, framerate independent.
	state.spin *= pow(physics.spin_decay_per_second, dt)

	state.elapsed += dt

	# 7. Ground contact.
	if state.position.y <= physics.radius and state.velocity.y < 0.0:
		return _resolve_bounce(state, previous_position, dt, physics, surface)

	return null


## Resolves a ground contact at the exact moment y crossed the ball radius, not at
## the end of the substep that noticed it. Without the rewind every landing point
## reports up to v_x * dt long - a quarter of a metre at 30 m/s, which is several
## ball widths of error on a line call.
static func _resolve_bounce(
	state: BallState,
	previous_position: Vector3,
	dt: float,
	physics: BallPhysicsConfig,
	surface: CourtSurfaceConfig
) -> BounceEvent:
	var event: BounceEvent = BounceEvent.new()
	event.incoming_velocity = state.velocity
	event.incoming_spin = state.spin
	event.surface_type = surface.surface_type

	# Velocity is constant across a substep in semi-implicit Euler, so the crossing
	# is exact, not an approximation. Zero when the ball was already at or below
	# the ground when the substep began.
	var time_to_contact: float = 0.0
	if previous_position.y > physics.radius:
		time_to_contact = clampf(
			(physics.radius - previous_position.y) / state.velocity.y, 0.0, dt
		)
	var contact: Vector3 = previous_position + state.velocity * time_to_contact
	contact.y = physics.radius

	var vertical: float = -state.velocity.y * surface.vertical_restitution
	var horizontal: Vector3 = (
		Vector3(state.velocity.x, 0.0, state.velocity.z) * surface.horizontal_friction
	)
	# Topspin kick. spin.cross(UP) * radius is the contact patch's surface velocity,
	# so bounce_spin_transfer reads as the fraction of it that becomes travel.
	horizontal += state.spin.cross(Vector3.UP) * surface.bounce_spin_transfer * physics.radius

	state.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	# That kick came out of the ball's rotation, so take it off the spin. Also the
	# reason a spinning ball settles: without it, each bounce re-feeds the horizontal
	# speed and the ball never falls under min_bounce_speed.
	state.spin *= (1.0 - surface.bounce_spin_transfer)

	state.position = contact + state.velocity * (dt - time_to_contact)
	state.position.y = maxf(state.position.y, physics.radius)

	event.position = contact
	event.time = state.elapsed - dt + time_to_contact
	event.outgoing_velocity = state.velocity

	# Vertical speed is tested as well as total speed because it is the one that is
	# guaranteed to decay: restitution shrinks it every bounce whatever the spin is
	# doing, so this is what makes a settling ball terminate.
	if vertical < physics.min_bounce_speed or state.velocity.length() < physics.min_bounce_speed:
		state.is_live = false
		state.position = contact
		event.still_live = false

	return event
