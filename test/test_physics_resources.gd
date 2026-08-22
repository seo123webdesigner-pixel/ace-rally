extends GutTest

## Pins the numbers that actually ship.
##
## This is the file a tuning pass is EXPECTED to break. test_ball_simulator.gd
## builds its own config so that retuning gravity or drag by eye cannot make the
## physics suite go red; the cost of that is that nothing would otherwise notice
## the shipped values changing. So this file asserts them explicitly. If a test
## here fails, read the diff, confirm it was a deliberate tune, and update both
## the expected value and the Sprint entry in NOTES.md.

const PHYSICS_PATH: String = "res://resources/ball_physics_default.tres"
const SURFACE_DIR: String = "res://resources/surfaces/"


func _physics() -> BallPhysicsConfig:
	return load(PHYSICS_PATH) as BallPhysicsConfig


func _surface(file_name: String) -> CourtSurfaceConfig:
	return load(SURFACE_DIR + file_name) as CourtSurfaceConfig


func test_default_ball_physics_resource_exists_and_is_typed() -> void:
	var config: BallPhysicsConfig = _physics()
	assert_not_null(config, "%s should load as a BallPhysicsConfig" % PHYSICS_PATH)


func test_default_ball_physics_values_are_the_sprint_1_values() -> void:
	var config: BallPhysicsConfig = _physics()
	if config == null:
		return
	assert_almost_eq(config.gravity, 13.5, 1e-9, "gravity")
	assert_almost_eq(config.mass, 0.057, 1e-9, "mass")
	assert_almost_eq(config.radius, 0.0335, 1e-9, "radius")
	assert_almost_eq(config.drag_coefficient, 0.55, 1e-9, "drag_coefficient")
	assert_almost_eq(config.air_density, 1.21, 1e-9, "air_density")
	assert_almost_eq(config.magnus_coefficient, 0.000045, 1e-12, "magnus_coefficient")
	assert_almost_eq(config.spin_decay_per_second, 0.85, 1e-9, "spin_decay_per_second")
	assert_almost_eq(config.min_bounce_speed, 0.4, 1e-9, "min_bounce_speed")


func test_ball_mass_and_radius_are_the_real_regulation_values() -> void:
	# These two are not tuning knobs. CLAUDE.md section 6 fixes them, and the court
	# is built around the radius.
	var config: BallPhysicsConfig = _physics()
	if config == null:
		return
	assert_almost_eq(config.mass, 0.057, 1e-9, "a real tennis ball weighs 57 g")
	assert_almost_eq(config.radius, 0.0335, 1e-9, "and is 67 mm across")


func test_every_surface_resource_exists_with_its_specified_values() -> void:
	# name, file, restitution, friction
	var expected: Array = [
		["Hard", "hard_court.tres", 0.75, 0.72, CourtSurfaceConfig.SurfaceType.HARD],
		["Clay", "clay_court.tres", 0.70, 0.58, CourtSurfaceConfig.SurfaceType.CLAY],
		["Grass", "grass_court.tres", 0.78, 0.82, CourtSurfaceConfig.SurfaceType.GRASS],
		["Indoor", "indoor_court.tres", 0.77, 0.75, CourtSurfaceConfig.SurfaceType.INDOOR],
	]

	for row: Array in expected:
		var surface: CourtSurfaceConfig = _surface(row[1])
		assert_not_null(surface, "%s should load" % row[1])
		if surface == null:
			continue
		assert_eq(surface.surface_name, row[0], "%s: surface_name" % row[1])
		assert_almost_eq(surface.vertical_restitution, row[2], 1e-9,
			"%s: vertical_restitution" % row[1])
		assert_almost_eq(surface.horizontal_friction, row[3], 1e-9,
			"%s: horizontal_friction" % row[1])
		assert_eq(surface.surface_type, row[4], "%s: surface_type" % row[1])
		assert_almost_eq(surface.bounce_spin_transfer, 0.4, 1e-9,
			"%s: bounce_spin_transfer" % row[1])


func test_surface_types_are_distinct() -> void:
	# surface_type is what EventBus.ball_bounced carries, so two surfaces sharing a
	# value would make bounce audio indistinguishable.
	var seen: Array[int] = []
	for file_name: String in ["hard_court.tres", "clay_court.tres", "grass_court.tres", "indoor_court.tres"]:
		var surface: CourtSurfaceConfig = _surface(file_name)
		if surface == null:
			continue
		assert_false(seen.has(int(surface.surface_type)),
			"%s reuses a surface_type already taken" % file_name)
		seen.append(int(surface.surface_type))


func test_surfaces_rank_the_way_the_real_ones_do() -> void:
	# Invariants that should survive any tuning: grass is the fastest through the
	# court, clay the slowest, and grass bounces highest.
	var hard: CourtSurfaceConfig = _surface("hard_court.tres")
	var clay: CourtSurfaceConfig = _surface("clay_court.tres")
	var grass: CourtSurfaceConfig = _surface("grass_court.tres")
	if hard == null or clay == null or grass == null:
		return

	assert_lt(clay.horizontal_friction, hard.horizontal_friction, "clay grabs more than hard")
	assert_lt(hard.horizontal_friction, grass.horizontal_friction, "hard grabs more than grass")
	assert_lt(clay.vertical_restitution, grass.vertical_restitution, "grass bounces higher than clay")


# -----------------------------------------------------------------------------
# Playability, against the resources that actually ship
# -----------------------------------------------------------------------------

func test_a_thirty_metre_per_second_drive_still_lands_in_the_court() -> void:
	# The acceptance criterion, checked against the LIVE resources rather than a
	# pinned config, with a deliberately loose bound. Its job is to catch a tune
	# that makes the game unplayable, not to freeze the feel. Measured at the
	# Sprint 1 defaults: lands 1.02 m inside the far baseline after 22.75 m.
	var config: BallPhysicsConfig = _physics()
	var surface: CourtSurfaceConfig = _surface("hard_court.tres")
	if config == null or surface == null:
		return

	var launch: Vector3 = Vector3(0.0, 1.0, CourtDimensions.BASELINE_Z)
	var angle: float = deg_to_rad(12.0)
	var velocity: Vector3 = Vector3(0.0, 30.0 * sin(angle), -30.0 * cos(angle))

	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(launch, velocity, Vector3.ZERO)
	var prediction: LandingPrediction = sim.predict_landing(6.0, surface)

	assert_true(prediction.found, "a 30 m/s drive has to land somewhere")
	if not prediction.found:
		return

	assert_lt(prediction.position.z, 0.0,
		"it should cross the net and land on the opponent's half, not fall short")
	assert_true(prediction.in_bounds,
		"and it should be in: landed at z %.3f, baseline is at %.3f" % [
			prediction.position.z, -CourtDimensions.BASELINE_Z
		])

	var depth: float = prediction.position.z + CourtDimensions.BASELINE_Z
	assert_lt(depth, 6.0,
		"a flat drive should be a deep ball, landing within 6 m of the far baseline (got %.2f m)" % depth)


func test_the_shipped_ball_clears_the_net_on_a_normal_drive() -> void:
	var config: BallPhysicsConfig = _physics()
	var surface: CourtSurfaceConfig = _surface("hard_court.tres")
	if config == null or surface == null:
		return

	var sim: BallSimulator = BallSimulator.new(config)
	var angle: float = deg_to_rad(12.0)
	sim.reset(
		Vector3(0.0, 1.0, CourtDimensions.BASELINE_Z),
		Vector3(0.0, 30.0 * sin(angle), -30.0 * cos(angle)),
		Vector3.ZERO
	)

	var previous: Vector3 = sim.position
	var height_at_net: float = -1.0
	for i: int in 1200:
		sim.step(1.0 / 60.0, surface)
		if CourtDimensions.crosses_net_plane(previous, sim.position):
			height_at_net = sim.position.y
			break
		previous = sim.position

	assert_gt(height_at_net, CourtDimensions.NET_HEIGHT_AT_CENTRE,
		"the drive has to clear the net: %.3f m against a net of %.3f m" % [
			height_at_net, CourtDimensions.NET_HEIGHT_AT_CENTRE
		])
