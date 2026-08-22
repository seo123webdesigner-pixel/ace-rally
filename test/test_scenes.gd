extends GutTest

## Proves the .tscn files this sprint added are actually valid.
##
## They were authored as text without an editor, so loading and instantiating them
## here is the only evidence they parse, wire up and run. GUT fails a test on any
## engine error or push_error raised inside it, so "no error" is enforced by the
## runner rather than by an assertion.

const BALL_SCENE: String = "res://scenes/ball/ball.tscn"
const COURT_SCENE: String = "res://scenes/court/court.tscn"
const LAB_SCENE: String = "res://scenes/core/physics_lab.tscn"


func _instantiate(path: String) -> Node:
	var packed: PackedScene = load(path)
	assert_not_null(packed, "%s should load as a PackedScene" % path)
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	assert_not_null(instance, "%s should instantiate" % path)
	if instance == null:
		return null
	add_child_autofree(instance)
	return instance


# -----------------------------------------------------------------------------
# Ball
# -----------------------------------------------------------------------------

func test_ball_scene_instantiates_with_its_parts_wired_up() -> void:
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	await wait_physics_frames(1)

	assert_not_null(ball.physics_config, "ball.tscn ships with a BallPhysicsConfig")
	assert_not_null(ball.surface, "and a starting surface")
	assert_not_null(ball.simulator, "and builds its simulator on ready")
	assert_not_null(ball.get_node_or_null("Mesh"), "mesh")
	assert_not_null(ball.get_node_or_null("Shadow"), "shadow blob")
	assert_not_null(ball.get_node_or_null("Trail"), "trail")


func test_ball_is_not_a_physics_body() -> void:
	# CLAUDE.md section 3 rule 1. If this ever fails, prediction is dead.
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	# is_class() rather than `is`: the compiler can prove a Ball is never a
	# RigidBody3D and rejects the static form outright, which would only assert
	# that today's class hierarchy compiles. This asserts the running node.
	assert_false(ball.is_class("RigidBody3D"), "the ball must never become a RigidBody3D")
	assert_false(ball.is_class("PhysicsBody3D"), "nor any other physics body")
	assert_true(ball.is_class("Node3D"), "it is a plain Node3D with manual integration")
	for child: Node in ball.get_children():
		assert_false(child is CollisionObject3D,
			"%s: the ball resolves its own collisions, it does not use Godot's" % child.name)


func test_the_mesh_is_inflated_without_touching_the_simulated_radius() -> void:
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	await wait_physics_frames(1)

	var mesh: MeshInstance3D = ball.get_node("Mesh")
	var expected: float = ball.visual_radius / ball.physics_config.radius
	assert_almost_eq(mesh.scale.x, expected, 1e-6,
		"the mesh is scaled up so the ball reads on a phone")
	assert_almost_eq(ball.physics_config.radius, 0.0335, 1e-9,
		"but the simulated radius is still the real one")


func test_ball_flies_and_reports_its_bounce_on_the_event_bus() -> void:
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	await wait_physics_frames(1)

	var bounces: Array = []
	var handler: Callable = func(pos: Vector3, surface_type: int) -> void:
		bounces.append({"position": pos, "surface_type": surface_type})
	EventBus.ball_bounced.connect(handler)

	var angle: float = deg_to_rad(12.0)
	ball.launch(
		Vector3(0.0, 1.0, CourtDimensions.BASELINE_Z),
		Vector3(0.0, 30.0 * sin(angle), -30.0 * cos(angle)),
		Vector3.ZERO
	)
	assert_true(ball.is_live(), "the ball should be live straight after launch")

	# Roughly a second of flight; the drive lands in 0.995 s.
	await wait_physics_frames(90)
	EventBus.ball_bounced.disconnect(handler)

	assert_gt(bounces.size(), 0, "the flight should have produced at least one bounce")
	if bounces.is_empty():
		return

	var first: Dictionary = bounces[0]
	assert_eq(first["surface_type"], int(ball.surface.surface_type),
		"the event should name the surface it bounced on")
	assert_lt(first["position"].z, 0.0, "and the drive should land past the net")
	assert_almost_eq(first["position"].y, ball.physics_config.radius, 1e-6,
		"contact is reported at the ball's underside")


func test_the_node_follows_the_simulation() -> void:
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	await wait_physics_frames(1)

	ball.launch(Vector3(0.0, 1.0, 5.0), Vector3(0.0, 4.0, -10.0), Vector3.ZERO)
	await wait_physics_frames(10)

	assert_almost_eq(ball.global_position.x, ball.simulator.position.x, 1e-6)
	assert_almost_eq(ball.global_position.y, ball.simulator.position.y, 1e-6)
	assert_almost_eq(ball.global_position.z, ball.simulator.position.z, 1e-6)

	var shadow: MeshInstance3D = ball.get_node("Shadow")
	assert_almost_eq(shadow.global_position.x, ball.simulator.position.x, 1e-6,
		"the shadow tracks the ball's ground position")
	assert_almost_eq(shadow.global_position.z, ball.simulator.position.z, 1e-6)
	assert_lt(shadow.global_position.y, 0.05, "and stays on the ground")


func test_kill_stops_the_ball_where_it_stands() -> void:
	var ball: Ball = _instantiate(BALL_SCENE)
	if ball == null:
		return
	await wait_physics_frames(1)

	ball.launch(Vector3(0.0, 2.0, 5.0), Vector3(0.0, 4.0, -10.0), Vector3.ZERO)
	await wait_physics_frames(5)
	var resting: Vector3 = ball.global_position
	ball.kill()
	await wait_physics_frames(10)

	assert_false(ball.is_live())
	assert_eq(ball.global_position, resting, "a killed ball does not drift")


# -----------------------------------------------------------------------------
# Court
# -----------------------------------------------------------------------------

func test_court_scene_is_built_from_primitives_within_the_draw_call_budget() -> void:
	var court: Court = _instantiate(COURT_SCENE)
	if court == null:
		return

	var meshes: int = 0
	var pending: Array[Node] = [court]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			meshes += 1
		for child: Node in node.get_children():
			pending.append(child)

	assert_gt(meshes, 0, "the court should actually have geometry")
	assert_lt(meshes, 150, "CLAUDE.md section 8 allows 150 draw calls for the whole frame")


func test_court_has_a_net_and_two_posts() -> void:
	var court: Court = _instantiate(COURT_SCENE)
	if court == null:
		return
	var net: Node = court.get_node_or_null("Net")
	var posts: Node = court.get_node_or_null("Posts")
	assert_not_null(net, "the court needs a net")
	assert_not_null(posts, "and posts")
	if net == null or posts == null:
		return
	assert_eq(net.get_child_count(), 3, "the sag is approximated by three segments")
	assert_eq(posts.get_child_count(), 2)


# -----------------------------------------------------------------------------
# Physics lab
# -----------------------------------------------------------------------------

func test_physics_lab_instantiates_with_its_controls_connected() -> void:
	var lab: PhysicsLab = _instantiate(LAB_SCENE)
	if lab == null:
		return
	await wait_physics_frames(1)

	assert_eq(lab.surfaces.size(), 4, "all four surfaces should be selectable")
	for surface: CourtSurfaceConfig in lab.surfaces:
		assert_not_null(surface, "every surface slot should be filled")


func test_physics_lab_draws_the_ring_where_the_ball_actually_lands() -> void:
	# The headless half of the acceptance criterion "the predicted landing ring sits
	# under the ball at the moment of first bounce, every time, on every surface".
	# This proves the lab reconciles prediction against reality correctly; whether
	# the ring is visually under the ball is in NEEDS_HUMAN_CHECK.md.
	var lab: PhysicsLab = _instantiate(LAB_SCENE)
	if lab == null:
		return
	await wait_physics_frames(1)

	for index: int in lab.surfaces.size():
		var surface_name: String = lab.surfaces[index].surface_name
		lab._surface_picker.select(index)
		lab._on_surface_selected(index)
		lab._fire()

		assert_true(lab._prediction != null and lab._prediction.found,
			"%s: firing should produce a prediction" % surface_name)
		if lab._prediction == null or not lab._prediction.found:
			continue

		var ring: MeshInstance3D = lab.get_node("LandingRing")
		assert_true(ring.visible, "%s: the ring should be shown on launch" % surface_name)
		assert_almost_eq(ring.global_position.x, lab._prediction.position.x, 1e-6,
			"%s: ring x" % surface_name)
		assert_almost_eq(ring.global_position.z, lab._prediction.position.z, 1e-6,
			"%s: ring z" % surface_name)

		await wait_physics_frames(180)

		assert_false(lab._awaiting_bounce,
			"%s: the ball should have bounced within 3 s" % surface_name)
		assert_almost_eq(lab.last_landing_error, 0.0, 0.05,
			"%s: the ring missed the real first bounce by %.9f m" % [
				surface_name, lab.last_landing_error
			])
