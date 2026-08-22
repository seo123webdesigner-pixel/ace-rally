extends "res://test/ball_test_case.gd"

## How the ball behaves in the air and off the ground: gravity, drag, spin,
## surfaces, and settling to rest.
##
## The prediction contract lives in test_ball_prediction.gd. Fixtures are in
## ball_test_case.gd, which explains why these tests build their own config
## instead of loading the shipped resource.
##
## Comments record what each quantity actually measured on 4.7.2, so a change that
## shifts a number shows up as a diff against a real figure.


# -----------------------------------------------------------------------------
# Vertical launch
# -----------------------------------------------------------------------------

func test_ball_launched_straight_up_returns_to_launch_height() -> void:
	# Measured: apex 2.3873 m against a vacuum apex of 2.4259 m, 1.59% low, and a
	# round trip of 0.72501 s against a vacuum 2v/g of 0.74074 s, 2.12% short.
	# 5 m/s is chosen because drag is quadratic: at 15 m/s the same launch comes in
	# 12.6% under the vacuum apex, and no fixed tolerance would mean anything.
	var config: BallPhysicsConfig = pinned_config()
	var launch_y: float = 1.5
	var speed: float = 5.0

	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(Vector3(0.0, launch_y, 0.0), Vector3(0.0, speed, 0.0), Vector3.ZERO)

	var apex: float = launch_y
	var elapsed: float = 0.0
	var round_trip: float = -1.0
	var falling: bool = false
	var previous_y: float = launch_y

	for i: int in 1200:
		previous_y = sim.position.y
		sim.step(DT, hard())
		elapsed += DT
		apex = maxf(apex, sim.position.y)
		if sim.velocity.y < 0.0:
			falling = true
		if falling and sim.position.y <= launch_y and previous_y > launch_y:
			# Interpolate the crossing: one 1/60 frame is 2.3% of this flight, the
			# same order as the tolerance being measured.
			var fraction: float = (previous_y - launch_y) / (previous_y - sim.position.y)
			round_trip = elapsed - DT + fraction * DT
			break

	assert_gt(round_trip, 0.0, "the ball should come back down through its launch height")

	var vacuum_apex: float = launch_y + speed * speed / (2.0 * config.gravity)
	var vacuum_time: float = 2.0 * speed / config.gravity

	assert_almost_eq(apex, vacuum_apex, vacuum_apex * 0.02,
		"apex should sit within 2% of the vacuum apex at this speed")
	assert_lt(apex, vacuum_apex, "drag must make the apex lower than vacuum, never higher")
	assert_almost_eq(round_trip, vacuum_time, vacuum_time * 0.03,
		"round trip should sit within 3% of the vacuum 2v/g")
	assert_lt(round_trip, vacuum_time, "drag lowers the apex, so the round trip is shorter")


# -----------------------------------------------------------------------------
# Drag
# -----------------------------------------------------------------------------

func test_drag_makes_a_flat_drive_fall_short_of_the_vacuum_prediction() -> void:
	# Measured: 22.7548 m with drag against a 31.0825 m vacuum range. Drag takes
	# roughly 8.3 m off a 30 m/s drive, which is most of a service box.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)

	var bounce: BounceEvent = first_bounce(config, hard(), velocity, Vector3.ZERO)
	assert_not_null(bounce, "a 30 m/s drive should land")
	if bounce == null:
		return

	var actual_range: float = LAUNCH_POS.z - bounce.position.z

	# Vacuum: solve for the time to fall from launch height to the ball's radius.
	var vy: float = velocity.y
	var vx: float = absf(velocity.z)
	var drop: float = LAUNCH_POS.y - config.radius
	var vacuum_time: float = (vy + sqrt(vy * vy + 2.0 * config.gravity * drop)) / config.gravity
	var vacuum_range: float = vx * vacuum_time

	assert_lt(actual_range, vacuum_range,
		"drag must shorten the shot: got %.4f m against a vacuum %.4f m" % [actual_range, vacuum_range])
	assert_gt(actual_range, vacuum_range * 0.5,
		"drag should cost part of the range, not most of it")


# -----------------------------------------------------------------------------
# Spin in flight
# -----------------------------------------------------------------------------

func test_topspin_drops_the_ball_shorter_than_no_spin() -> void:
	# Measured at 314 rad/s (about 3000 rpm): 17.7401 m against 22.7548 m unspun.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)

	# Travelling -Z, topspin is angular velocity about -X.
	var topspin: BounceEvent = first_bounce(config, hard(), velocity, Vector3(-314.0, 0.0, 0.0))
	var unspun: BounceEvent = first_bounce(config, hard(), velocity, Vector3.ZERO)
	assert_not_null(topspin)
	assert_not_null(unspun)
	if topspin == null or unspun == null:
		return

	var topspin_range: float = LAUNCH_POS.z - topspin.position.z
	var unspun_range: float = LAUNCH_POS.z - unspun.position.z
	assert_lt(topspin_range, unspun_range,
		"topspin must land shorter: %.4f m against %.4f m unspun" % [topspin_range, unspun_range])


func test_backspin_carries_the_ball_longer_than_no_spin() -> void:
	# Measured at 314 rad/s: 30.7296 m against 22.7548 m unspun.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)

	var backspin: BounceEvent = first_bounce(config, hard(), velocity, Vector3(314.0, 0.0, 0.0))
	var unspun: BounceEvent = first_bounce(config, hard(), velocity, Vector3.ZERO)
	assert_not_null(backspin)
	assert_not_null(unspun)
	if backspin == null or unspun == null:
		return

	var backspin_range: float = LAUNCH_POS.z - backspin.position.z
	var unspun_range: float = LAUNCH_POS.z - unspun.position.z
	assert_gt(backspin_range, unspun_range,
		"backspin must carry further: %.4f m against %.4f m unspun" % [backspin_range, unspun_range])


# -----------------------------------------------------------------------------
# Surfaces
# -----------------------------------------------------------------------------

func test_clay_retains_less_horizontal_speed_than_grass() -> void:
	# Same ball arriving identically. Measured outgoing horizontal speed:
	# clay 10.8208 m/s, grass 15.2984 m/s.
	var config: BallPhysicsConfig = pinned_config()
	var arrival: Vector3 = Vector3(0.0, -5.0, -20.0)

	var on_clay: BounceEvent = first_bounce(
		config, clay(), arrival, Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	var on_grass: BounceEvent = first_bounce(
		config, grass(), arrival, Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	assert_not_null(on_clay)
	assert_not_null(on_grass)
	if on_clay == null or on_grass == null:
		return

	var clay_speed: float = Vector2(on_clay.outgoing_velocity.x, on_clay.outgoing_velocity.z).length()
	var grass_speed: float = Vector2(on_grass.outgoing_velocity.x, on_grass.outgoing_velocity.z).length()

	assert_lt(clay_speed, grass_speed,
		"clay must grab more than grass: %.4f m/s against %.4f m/s" % [clay_speed, grass_speed])


# -----------------------------------------------------------------------------
# Settling
# -----------------------------------------------------------------------------

func test_ball_goes_dead_after_repeated_bounces() -> void:
	# Measured on hard: dead after 10 bounces and 3.72 s.
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 0.0, -8.0), Vector3.ZERO)

	var bounces: int = 0
	for i: int in 3600:
		bounces += sim.step(DT, hard()).size()
		if not sim.is_live:
			break

	assert_false(sim.is_live, "a bouncing ball must eventually settle")
	assert_gt(bounces, 1, "it should bounce more than once on the way down")


func test_ball_goes_dead_even_when_carrying_heavy_topspin() -> void:
	# The case that hangs if a bounce adds spin-driven horizontal speed without
	# also scrubbing the spin. Bounce intervals shrink geometrically so the total
	# remaining flight time converges, meaning spin never fully decays; the kick
	# then re-feeds horizontal speed against friction and settles at a rolling
	# ~5.5 m/s that never falls under min_bounce_speed. Gating is_live on the
	# post-bounce VERTICAL speed is what guarantees termination, because that
	# decays geometrically whatever the spin does.
	# Measured: hard 10 bounces, clay 9, grass 12, all inside 4.2 s.
	var config: BallPhysicsConfig = pinned_config()
	for entry: Array in [["hard", hard()], ["clay", clay()], ["grass", grass()]]:
		var sim: BallSimulator = BallSimulator.new(config)
		sim.reset(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -25.0), Vector3(-400.0, 0.0, 0.0))

		var ticks: int = 0
		for i: int in 7200:
			sim.step(DT, entry[1])
			ticks += 1
			if not sim.is_live:
				break

		assert_false(sim.is_live,
			"%s: a heavily spinning ball must settle, not roll forever" % entry[0])
		assert_lt(ticks * DT, 10.0, "%s: it should settle inside 10 s" % entry[0])
