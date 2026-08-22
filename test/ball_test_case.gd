extends GutTest

## Shared fixtures for the ball physics suites. Not a test script itself.
##
## Deliberately named WITHOUT the "test_" prefix so GUT's collector never picks it
## up as a suite of its own; the subclasses inherit these helpers. Extended by
## path rather than class_name so test-only code stays out of the global namespace.
##
## Every helper here builds its OWN config rather than loading
## resources/ball_physics_default.tres. That is the point: this sprint ends with a
## human tuning gravity, drag and Magnus by eye, and a suite that breaks the moment
## somebody tunes is a suite people delete. These fixtures pin the INTEGRATOR.
## test_physics_resources.gd pins the shipped numbers, and that is the one file a
## retune is meant to touch.

const DT: float = 1.0 / 60.0

## Player's baseline, roughly waist height. The far baseline is 23.77 m away.
const LAUNCH_POS: Vector3 = Vector3(0.0, 1.0, 11.885)


## The Sprint 1 values, set explicitly so this is immune to both a retuned .tres
## and an edited script default.
func pinned_config() -> BallPhysicsConfig:
	var c: BallPhysicsConfig = BallPhysicsConfig.new()
	c.gravity = 13.5
	c.mass = 0.057
	c.radius = 0.0335
	c.drag_coefficient = 0.55
	c.air_density = 1.21
	c.magnus_coefficient = 0.000045
	c.spin_decay_per_second = 0.85
	c.min_bounce_speed = 0.4
	return c


func make_surface(
	restitution: float,
	friction: float,
	spin_transfer: float = 0.4
) -> CourtSurfaceConfig:
	var s: CourtSurfaceConfig = CourtSurfaceConfig.new()
	s.vertical_restitution = restitution
	s.horizontal_friction = friction
	s.bounce_spin_transfer = spin_transfer
	return s


func hard() -> CourtSurfaceConfig:
	return make_surface(0.75, 0.72)


func clay() -> CourtSurfaceConfig:
	return make_surface(0.70, 0.58)


func grass() -> CourtSurfaceConfig:
	return make_surface(0.78, 0.82)


## Launch vector for `speed` at `degrees` of elevation, travelling toward -Z.
func launch_velocity(speed: float, degrees: float) -> Vector3:
	var r: float = deg_to_rad(degrees)
	return Vector3(0.0, speed * sin(r), -speed * cos(r))


## Steps at the real physics rate until the first bounce. Returns null if the ball
## never lands, so a broken integrator fails loudly instead of hanging the suite.
func first_bounce(
	config: BallPhysicsConfig,
	surface: CourtSurfaceConfig,
	velocity: Vector3,
	spin: Vector3,
	pos: Vector3 = LAUNCH_POS
) -> BounceEvent:
	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(pos, velocity, spin)
	for i: int in 1200:
		var events: Array[BounceEvent] = sim.step(DT, surface)
		if not events.is_empty():
			return events[0]
	return null
