extends GutTest

## Cost of the simulation, headlessly.
##
## This is the half of "frame time stays under 5 ms" that can be proven without
## seeing the window. It measures the integrator and the prediction call only.
## Render cost is a human check; see NEEDS_HUMAN_CHECK.md.
##
## Bounds are deliberately generous against the measured figures, because CI
## hardware varies and a timing test that fails on a slow runner gets ignored.
## The measured values are recorded next to each so a real regression is obvious.

const DT: float = 1.0 / 60.0
const FRAME_BUDGET_USEC: float = 16666.0

const STEP_SAMPLES: int = 20000
const PREDICT_SAMPLES: int = 2000


func _config() -> BallPhysicsConfig:
	return BallPhysicsConfig.new()


func _hard() -> CourtSurfaceConfig:
	var s: CourtSurfaceConfig = CourtSurfaceConfig.new()
	s.vertical_restitution = 0.75
	s.horizontal_friction = 0.72
	return s


func _launch(sim: BallSimulator) -> void:
	var angle: float = deg_to_rad(12.0)
	sim.reset(
		Vector3(0.0, 1.0, CourtDimensions.BASELINE_Z),
		Vector3(0.0, 30.0 * sin(angle), -30.0 * cos(angle)),
		Vector3(-200.0, 0.0, 0.0)
	)


func test_stepping_the_ball_is_a_rounding_error_in_the_frame_budget() -> void:
	# Measured on the development machine: 11.4 us per 1/60 frame, which is two
	# 1/120 substeps. That is 0.07% of a 60 fps frame.
	var sim: BallSimulator = BallSimulator.new(_config())
	var surface: CourtSurfaceConfig = _hard()
	_launch(sim)

	var started: int = Time.get_ticks_usec()
	for i: int in STEP_SAMPLES:
		if not sim.is_live:
			_launch(sim)
		sim.step(DT, surface)
	var per_step: float = float(Time.get_ticks_usec() - started) / float(STEP_SAMPLES)

	gut.p("ball step: %.3f us per physics frame" % per_step)
	assert_lt(per_step, FRAME_BUDGET_USEC * 0.02,
		"one ball step took %.3f us, over 2%% of a 60 fps frame" % per_step)


func test_predicting_a_landing_is_affordable_every_frame() -> void:
	# Measured: 426 us for a 5 s search window. The AI is expected to re-predict on
	# each hit rather than each frame, but even per-frame it fits, and this bound is
	# what keeps that true.
	var sim: BallSimulator = BallSimulator.new(_config())
	var surface: CourtSurfaceConfig = _hard()
	_launch(sim)

	var started: int = Time.get_ticks_usec()
	for i: int in PREDICT_SAMPLES:
		sim.predict_landing(5.0, surface)
	var per_call: float = float(Time.get_ticks_usec() - started) / float(PREDICT_SAMPLES)

	gut.p("predict_landing: %.3f us per call over a 5 s window" % per_call)
	assert_lt(per_call, FRAME_BUDGET_USEC * 0.25,
		"predict_landing took %.3f us, a quarter of a 60 fps frame" % per_call)


func test_prediction_stops_searching_instead_of_running_away() -> void:
	# A ball that never lands must not spin forever. MAX_PREDICTION_SUBSTEPS caps
	# the search whatever max_time is asked for.
	var sim: BallSimulator = BallSimulator.new(_config())
	var surface: CourtSurfaceConfig = _hard()
	# Straight up hard enough that it is still climbing when a sane window expires.
	sim.reset(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 60.0, 0.0), Vector3.ZERO)

	var started: int = Time.get_ticks_usec()
	var prediction: LandingPrediction = sim.predict_landing(9999.0, surface)
	var elapsed_usec: float = float(Time.get_ticks_usec() - started)

	gut.p("runaway prediction capped at %.3f us" % elapsed_usec)
	assert_lt(elapsed_usec, 100000.0,
		"an absurd max_time should be capped, not honoured (%.0f us)" % elapsed_usec)
	assert_true(prediction.found, "this ball does come down eventually")


func test_a_full_rally_length_flight_costs_less_than_one_frame() -> void:
	# End to end: launch, fly, bounce, settle. The whole thing should cost less
	# than a single frame's budget, so a rally never spikes.
	var sim: BallSimulator = BallSimulator.new(_config())
	var surface: CourtSurfaceConfig = _hard()

	var started: int = Time.get_ticks_usec()
	_launch(sim)
	var frames: int = 0
	while sim.is_live and frames < 3600:
		sim.step(DT, surface)
		frames += 1
	var elapsed_usec: float = float(Time.get_ticks_usec() - started)

	gut.p("full flight to rest: %d frames, %.1f us total" % [frames, elapsed_usec])
	assert_gt(frames, 60, "the flight should last more than a second of game time")
	assert_lt(elapsed_usec, FRAME_BUDGET_USEC,
		"simulating an entire flight cost %.1f us, more than one frame" % elapsed_usec)
