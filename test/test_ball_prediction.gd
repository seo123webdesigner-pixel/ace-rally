extends "res://test/ball_test_case.gd"

## The contract the AI depends on: predict_landing() must agree with actually
## stepping the ball forward, and it must never disturb the live ball.
##
## Also covers bounce resolution, because the contact point prediction reports is
## the point a line call is judged against.
##
## Flight behaviour is in test_ball_flight.gd; fixtures in ball_test_case.gd.


# -----------------------------------------------------------------------------
# Prediction
# -----------------------------------------------------------------------------

func test_prediction_matches_a_stepped_simulation_on_every_surface() -> void:
	# The brief asks for agreement within 0.05 m over a 20 m shot. Because the
	# simulator runs prediction through the same _substep at the same SIM_DT, the
	# measured error is 0.000000000 m on all three surfaces.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)
	var spin: Vector3 = Vector3(-250.0, 0.0, 0.0)

	for entry: Array in [["hard", hard()], ["clay", clay()], ["grass", grass()]]:
		var sim: BallSimulator = BallSimulator.new(config)
		sim.reset(LAUNCH_POS, velocity, spin)
		var prediction: LandingPrediction = sim.predict_landing(10.0, entry[1])

		assert_true(prediction.found, "%s: the shot should be predicted to land" % entry[0])
		if not prediction.found:
			continue

		var actual: BounceEvent = first_bounce(config, entry[1], velocity, spin)
		assert_not_null(actual)
		if actual == null:
			continue

		var travelled: float = LAUNCH_POS.z - actual.position.z
		assert_gt(travelled, 15.0, "%s: this should be a long shot to be a fair test" % entry[0])

		var error: float = (prediction.position - actual.position).length()
		assert_lt(error, 0.05,
			"%s: prediction missed the real bounce by %.9f m" % [entry[0], error])
		assert_almost_eq(prediction.time, actual.time, 0.001,
			"%s: predicted time of flight should match" % entry[0])


func test_prediction_stays_exact_when_called_mid_flight() -> void:
	# The AI does not only predict at launch; it re-predicts while the ball is in
	# the air. Measured worst error across a whole flight: 0.000000000 m.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)
	var spin: Vector3 = Vector3(-200.0, 30.0, 0.0)

	var truth: BounceEvent = first_bounce(config, hard(), velocity, spin)
	assert_not_null(truth)
	if truth == null:
		return

	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(LAUNCH_POS, velocity, spin)

	var worst: float = 0.0
	for i: int in 1200:
		var prediction: LandingPrediction = sim.predict_landing(6.0, hard())
		if prediction.found:
			worst = maxf(worst, (prediction.position - truth.position).length())
		if not sim.step(DT, hard()).is_empty():
			break

	assert_lt(worst, 0.05,
		"re-predicting mid-flight drifted by %.9f m from the real landing point" % worst)


func test_prediction_does_not_disturb_the_live_ball() -> void:
	var config: BallPhysicsConfig = pinned_config()
	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(LAUNCH_POS, launch_velocity(30.0, 12.0), Vector3(-200.0, 0.0, 0.0))

	for i: int in 20:
		sim.step(DT, hard())

	var position_before: Vector3 = sim.position
	var velocity_before: Vector3 = sim.velocity
	var spin_before: Vector3 = sim.spin
	var elapsed_before: float = sim.elapsed

	sim.predict_landing(6.0, hard())
	sim.predict_position_at_time(0.5, hard())

	assert_eq(sim.position, position_before, "prediction must not move the ball")
	assert_eq(sim.velocity, velocity_before, "prediction must not change velocity")
	assert_eq(sim.spin, spin_before, "prediction must not change spin")
	assert_eq(sim.elapsed, elapsed_before, "prediction must not advance the clock")


func test_predict_position_at_time_matches_a_stepped_simulation() -> void:
	# Measured error at 0.25 / 0.50 / 0.75 s: 0.000000000000 m.
	var config: BallPhysicsConfig = pinned_config()
	var velocity: Vector3 = launch_velocity(30.0, 12.0)
	var spin: Vector3 = Vector3(-200.0, 0.0, 0.0)

	for target: float in [0.25, 0.5, 0.75]:
		var predictor: BallSimulator = BallSimulator.new(config)
		predictor.reset(LAUNCH_POS, velocity, spin)
		var predicted: Vector3 = predictor.predict_position_at_time(target, hard())

		var walker: BallSimulator = BallSimulator.new(config)
		walker.reset(LAUNCH_POS, velocity, spin)
		for i: int in int(round(target / DT)):
			walker.step(DT, hard())

		assert_lt((predicted - walker.position).length(), 0.001,
			"predict_position_at_time(%.2f) disagreed with stepping there" % target)


func test_prediction_reports_a_ball_that_never_lands_as_not_found() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(LAUNCH_POS, Vector3(0.0, 40.0, 0.0), Vector3.ZERO)

	var prediction: LandingPrediction = sim.predict_landing(0.1, hard())
	assert_false(prediction.found, "a ball still climbing after 0.1 s has not landed")


func test_prediction_flags_a_shot_that_lands_out() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	# Wide enough to miss the singles sideline by a clear margin.
	sim.reset(LAUNCH_POS, Vector3(12.0, 6.0, -22.0), Vector3.ZERO)

	var prediction: LandingPrediction = sim.predict_landing(6.0, hard())
	assert_true(prediction.found, "the shot should land somewhere")
	if not prediction.found:
		return
	assert_false(prediction.in_bounds, "a shot this wide should be called out")
	assert_gt(absf(prediction.position.x), CourtDimensions.SINGLES_HALF_WIDTH,
		"and it should actually be outside the singles sideline")


# -----------------------------------------------------------------------------
# Bounce resolution
# -----------------------------------------------------------------------------

func test_bounce_is_reported_at_the_contact_point_not_the_end_of_the_substep() -> void:
	# Without the sub-step rewind the reported bounce would sit wherever the ball
	# happened to be when the substep ended - up to v_x * dt long, a quarter of a
	# metre at 30 m/s. That is the point a line call is judged against.
	var config: BallPhysicsConfig = pinned_config()
	var sim: BallSimulator = BallSimulator.new(config)
	sim.reset(LAUNCH_POS, launch_velocity(30.0, 12.0), Vector3.ZERO)

	var before: Vector3 = sim.position
	var bounce: BounceEvent = null
	for i: int in 1200:
		before = sim.position
		var events: Array[BounceEvent] = sim.step(DT, hard())
		if not events.is_empty():
			bounce = events[0]
			break

	assert_not_null(bounce)
	if bounce == null:
		return

	assert_almost_eq(bounce.position.y, config.radius, 1e-6,
		"contact happens exactly when the ball's underside reaches the ground")
	assert_lt(bounce.time, sim.elapsed,
		"contact must be timestamped before the end of the step that found it")
	assert_gt(bounce.time, sim.elapsed - 2.0 * BallSimulator.SIM_DT,
		"and within the step that found it")
	# Travelling -Z, so the contact z sits between the previous frame and the current one.
	assert_lt(bounce.position.z, before.z, "contact is ahead of where the ball was")
	assert_gt(bounce.position.z, sim.position.z, "and behind where it ended up")


func test_bounce_event_carries_the_incoming_and_outgoing_velocity() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -6.0, -18.0), Vector3.ZERO)

	var bounce: BounceEvent = null
	for i: int in 600:
		var events: Array[BounceEvent] = sim.step(DT, hard())
		if not events.is_empty():
			bounce = events[0]
			break

	assert_not_null(bounce)
	if bounce == null:
		return

	assert_lt(bounce.incoming_velocity.y, 0.0, "the ball arrives travelling down")
	assert_gt(bounce.outgoing_velocity.y, 0.0, "and leaves travelling up")
	assert_almost_eq(bounce.outgoing_velocity.y, -bounce.incoming_velocity.y * 0.75, 1e-6,
		"vertical restitution should be applied exactly")
	assert_gt(bounce.impact_speed(), 0.0, "impact speed drives audio and particles")
	assert_true(bounce.still_live, "a bounce this fast does not kill the ball")


func test_topspin_kicks_the_ball_forward_out_of_the_bounce() -> void:
	# Measured on hard at 314 rad/s: outgoing horizontal 17.63 m/s where friction
	# alone would have given 13.50 m/s.
	var config: BallPhysicsConfig = pinned_config()
	var arrival: Vector3 = Vector3(0.0, -8.0, -20.0)

	var spun: BounceEvent = first_bounce(
		config, hard(), arrival, Vector3(-314.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	var unspun: BounceEvent = first_bounce(
		config, hard(), arrival, Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	assert_not_null(spun)
	assert_not_null(unspun)
	if spun == null or unspun == null:
		return

	assert_lt(spun.outgoing_velocity.z, unspun.outgoing_velocity.z,
		"topspin should leave the bounce travelling faster in -Z than an unspun ball")


func test_bounce_scrubs_spin_off_the_ball() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -6.0, -15.0), Vector3(-300.0, 0.0, 0.0))

	var spin_before: float = 0.0
	for i: int in 600:
		spin_before = sim.spin.length()
		var events: Array[BounceEvent] = sim.step(DT, hard())
		if not events.is_empty():
			break

	assert_lt(sim.spin.length(), spin_before,
		"the bounce takes spin off the ball, which is what makes it settle")


# -----------------------------------------------------------------------------
# Housekeeping
# -----------------------------------------------------------------------------

func test_reset_makes_a_dead_ball_live_again() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ZERO)
	for i: int in 3600:
		sim.step(DT, hard())
		if not sim.is_live:
			break
	assert_false(sim.is_live, "precondition: the ball should have settled")

	sim.reset(LAUNCH_POS, launch_velocity(25.0, 15.0), Vector3.ZERO)
	assert_true(sim.is_live, "reset should bring it back")
	assert_eq(sim.position, LAUNCH_POS, "and put it where it was told")
	assert_eq(sim.elapsed, 0.0, "and restart the clock")


func test_a_dead_ball_does_not_move() -> void:
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(LAUNCH_POS, launch_velocity(30.0, 12.0), Vector3.ZERO)
	sim.is_live = false

	var resting: Vector3 = sim.position
	var events: Array[BounceEvent] = sim.step(DT, hard())

	assert_eq(sim.position, resting, "a dead ball stays put")
	assert_true(events.is_empty(), "and reports nothing")


func test_stepping_at_the_physics_rate_leaves_no_leftover_time() -> void:
	# SIM_DT is exactly half of a 60 Hz frame, and halving is exact in binary
	# floating point, so the accumulator returns to exactly zero every frame.
	# If this ever fails, prediction and simulation are running out of phase.
	var sim: BallSimulator = BallSimulator.new(pinned_config())
	sim.reset(LAUNCH_POS, launch_velocity(30.0, 12.0), Vector3.ZERO)

	for i: int in 30:
		sim.step(DT, hard())

	assert_almost_eq(sim.elapsed, 30.0 * DT, 1e-12,
		"30 frames at 1/60 should integrate exactly half a second")
