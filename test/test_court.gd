extends GutTest

## Court geometry. These are line calls, so they are asserted to the centimetre
## against the real dimensions in CLAUDE.md section 6.
##
## World frame: origin at the centre of the net, +Z toward the player's baseline,
## +Y up, +X court right from the player's view.

const COURT_SCENE: String = "res://scenes/court/court.tscn"


func _court() -> Court:
	var instance: Court = load(COURT_SCENE).instantiate()
	add_child_autofree(instance)
	return instance


# -----------------------------------------------------------------------------
# Dimensions
# -----------------------------------------------------------------------------

func test_dimensions_match_the_specification() -> void:
	assert_almost_eq(CourtDimensions.COURT_LENGTH, 23.77, 1e-9)
	assert_almost_eq(CourtDimensions.SINGLES_WIDTH, 8.23, 1e-9)
	assert_almost_eq(CourtDimensions.DOUBLES_WIDTH, 10.97, 1e-9)
	assert_almost_eq(CourtDimensions.BASELINE_Z, 11.885, 1e-9)
	assert_almost_eq(CourtDimensions.SINGLES_HALF_WIDTH, 4.115, 1e-9)
	assert_almost_eq(CourtDimensions.DOUBLES_HALF_WIDTH, 5.485, 1e-9)
	assert_almost_eq(CourtDimensions.SERVICE_LINE_Z, 6.40, 1e-9)
	assert_almost_eq(CourtDimensions.NET_HEIGHT_AT_POST, 1.07, 1e-9)
	assert_almost_eq(CourtDimensions.NET_HEIGHT_AT_CENTRE, 0.914, 1e-9)


# -----------------------------------------------------------------------------
# In and out
# -----------------------------------------------------------------------------

func test_a_ball_inside_the_lines_is_in() -> void:
	assert_true(CourtDimensions.is_in_bounds(Vector3(0.0, 0.0, 0.0)))
	assert_true(CourtDimensions.is_in_bounds(Vector3(4.0, 0.0, 11.8)))
	assert_true(CourtDimensions.is_in_bounds(Vector3(-4.0, 0.0, -11.8)))


func test_a_ball_past_the_baseline_is_out() -> void:
	assert_true(CourtDimensions.is_in_bounds(Vector3(0.0, 0.0, 11.885)),
		"exactly on the baseline is in")
	assert_false(CourtDimensions.is_in_bounds(Vector3(0.0, 0.0, 11.886)),
		"a millimetre past it is out")
	assert_false(CourtDimensions.is_in_bounds(Vector3(0.0, 0.0, -12.5)))


func test_the_doubles_alley_is_out_for_singles_and_in_for_doubles() -> void:
	var in_the_alley: Vector3 = Vector3(4.8, 0.0, 3.0)
	assert_false(CourtDimensions.is_in_bounds(in_the_alley, true),
		"the alley is out in a singles match")
	assert_true(CourtDimensions.is_in_bounds(in_the_alley, false),
		"and in for doubles")


func test_the_singles_sideline_itself_is_in() -> void:
	assert_true(CourtDimensions.is_in_bounds(Vector3(4.115, 0.0, 0.0), true))
	assert_false(CourtDimensions.is_in_bounds(Vector3(4.116, 0.0, 0.0), true))


func test_tolerance_widens_every_boundary() -> void:
	var just_out: Vector3 = Vector3(4.14, 0.0, 0.0)
	assert_false(CourtDimensions.is_in_bounds(just_out, true, 0.0))
	assert_true(CourtDimensions.is_in_bounds(just_out, true, 0.0335),
		"passing the ball radius reproduces the real touching-the-line rule")


# -----------------------------------------------------------------------------
# Service boxes
# -----------------------------------------------------------------------------

func test_each_service_box_occupies_its_own_quarter() -> void:
	# Player half is +Z and its right is +X; the opponent half faces the other way,
	# so its right is -X.
	var player_right: Vector3 = Vector3(2.0, 0.0, 3.0)
	var player_left: Vector3 = Vector3(-2.0, 0.0, 3.0)
	var opponent_right: Vector3 = Vector3(-2.0, 0.0, -3.0)
	var opponent_left: Vector3 = Vector3(2.0, 0.0, -3.0)

	assert_true(CourtDimensions.is_in_service_box(player_right, true, true))
	assert_false(CourtDimensions.is_in_service_box(player_left, true, true))
	assert_true(CourtDimensions.is_in_service_box(player_left, false, true))

	assert_true(CourtDimensions.is_in_service_box(opponent_right, true, false))
	assert_false(CourtDimensions.is_in_service_box(opponent_left, true, false))
	assert_true(CourtDimensions.is_in_service_box(opponent_left, false, false))


func test_a_serve_from_the_players_right_must_land_diagonally_opposite() -> void:
	# Pins the diagonal so a later serve validator cannot get it backwards. A serve
	# struck from the player's right-hand (deuce) court has to find the box given
	# by is_in_service_box(pos, true, false): the opponent half, its right side.
	var target: Vector3 = Vector3(-2.0, 0.0, -3.0)
	assert_true(CourtDimensions.is_in_service_box(target, true, false),
		"the target box is on the opponent's half")
	assert_lt(target.x, 0.0, "and diagonally across from a server standing at +X")
	assert_lt(target.z, 0.0, "and on the far side of the net")


func test_a_ball_past_the_service_line_is_not_in_the_box() -> void:
	assert_true(CourtDimensions.is_in_service_box(Vector3(2.0, 0.0, 6.4), true, true),
		"exactly on the service line is in")
	assert_false(CourtDimensions.is_in_service_box(Vector3(2.0, 0.0, 6.41), true, true))
	assert_false(CourtDimensions.is_in_service_box(Vector3(2.0, 0.0, 9.0), true, true))


func test_a_serve_into_the_doubles_alley_is_not_in_the_box() -> void:
	# Service boxes are always singles width, whatever match is being played.
	assert_false(CourtDimensions.is_in_service_box(Vector3(4.8, 0.0, 3.0), true, true))


func test_a_ball_on_the_wrong_side_of_the_net_is_not_in_the_box() -> void:
	assert_false(CourtDimensions.is_in_service_box(Vector3(2.0, 0.0, -3.0), true, true),
		"a -Z bounce cannot be in a player-side box")


# -----------------------------------------------------------------------------
# The net
# -----------------------------------------------------------------------------

func test_crossing_the_net_plane_is_detected() -> void:
	assert_true(CourtDimensions.crosses_net_plane(Vector3(0, 1, 5), Vector3(0, 1, -5)))
	assert_true(CourtDimensions.crosses_net_plane(Vector3(0, 1, -5), Vector3(0, 1, 5)))
	assert_false(CourtDimensions.crosses_net_plane(Vector3(0, 1, 11), Vector3(0, 1, 3)),
		"both ends on the player's side is not a crossing")
	assert_false(CourtDimensions.crosses_net_plane(Vector3(0, 1, -11), Vector3(0, 1, -3)))


func test_net_height_sags_from_the_posts_to_the_centre() -> void:
	assert_almost_eq(CourtDimensions.net_height_at(0.0), 0.914, 1e-9,
		"lowest at the centre")
	assert_almost_eq(CourtDimensions.net_height_at(CourtDimensions.NET_POST_X), 1.07, 1e-9,
		"highest at the posts")
	var midway: float = CourtDimensions.net_height_at(CourtDimensions.NET_POST_X * 0.5)
	assert_gt(midway, 0.914, "and in between it is somewhere between the two")
	assert_lt(midway, 1.07)
	assert_almost_eq(CourtDimensions.net_height_at(-3.0), CourtDimensions.net_height_at(3.0), 1e-9,
		"the sag is symmetric")


func test_the_posts_stand_outside_the_doubles_sidelines() -> void:
	assert_gt(CourtDimensions.NET_POST_X, CourtDimensions.DOUBLES_HALF_WIDTH,
		"posts are outside the court, as in the real game")
	assert_almost_eq(CourtDimensions.NET_POST_X, 6.399, 1e-9)


# -----------------------------------------------------------------------------
# The node
# -----------------------------------------------------------------------------

func test_court_scene_loads_and_carries_a_surface() -> void:
	var court: Court = _court()
	assert_not_null(court.get_surface(), "court.tscn should ship with a surface assigned")
	assert_eq(court.get_surface().surface_name, "Hard")
	assert_eq(court.name, &"Court")


func test_court_node_delegates_to_the_shared_dimensions() -> void:
	# The node must not hold measurements of its own; it should give exactly the
	# same answers as the pure class the AI uses.
	var court: Court = _court()
	for point: Vector3 in [
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.2, 0.0, 3.0),
		Vector3(0.0, 0.0, 12.4),
		Vector3(-3.0, 0.0, -8.0),
	]:
		assert_eq(court.is_in_bounds(point), CourtDimensions.is_in_bounds(point),
			"is_in_bounds disagreed at %s" % point)
		assert_eq(
			court.is_in_service_box(point, true, true),
			CourtDimensions.is_in_service_box(point, true, true),
			"is_in_service_box disagreed at %s" % point
		)

	assert_eq(
		court.crosses_net_plane(Vector3(0, 1, 5), Vector3(0, 1, -5)),
		CourtDimensions.crosses_net_plane(Vector3(0, 1, 5), Vector3(0, 1, -5))
	)
