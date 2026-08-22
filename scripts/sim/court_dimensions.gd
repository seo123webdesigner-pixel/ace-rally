class_name CourtDimensions
extends RefCounted

## Single responsibility: own the court's measurements and the geometric queries
## that follow from them. The one place CLAUDE.md section 6 is written down.
##
## This lives in scripts/sim/ rather than scripts/gameplay/ on purpose: the AI's
## landing prediction has to answer "is that in?" without a scene tree to ask.
## The Court node delegates to these functions so the numbers exist once.
##
## World frame: origin at the centre of the net, +Z toward the player's baseline,
## +Y up, +X court right from the player's view.

const COURT_LENGTH: float = 23.77
const SINGLES_WIDTH: float = 8.23
const DOUBLES_WIDTH: float = 10.97

## Baselines sit at +/- this on Z.
const BASELINE_Z: float = COURT_LENGTH * 0.5

## Sidelines sit at +/- these on X.
const SINGLES_HALF_WIDTH: float = SINGLES_WIDTH * 0.5
const DOUBLES_HALF_WIDTH: float = DOUBLES_WIDTH * 0.5

## Service lines sit at +/- this on Z. Service boxes are always singles width.
const SERVICE_LINE_Z: float = 6.40

const NET_HEIGHT_AT_POST: float = 1.07
const NET_HEIGHT_AT_CENTRE: float = 0.914

## Posts stand 0.914 m outside the doubles sidelines, as in the real game.
const NET_POST_X: float = DOUBLES_HALF_WIDTH + 0.914

## Run-off, for the visual court only. Never used by a line call.
const RUNOFF_BEHIND_BASELINE: float = 5.5
const RUNOFF_BESIDE_SIDELINE: float = 3.5

## Painted lines are 0.05 m wide, drawn inside the court so their OUTER edge is
## the boundary. That is what makes a ball on the line in.
const LINE_WIDTH: float = 0.05

## Slop absorbed by every boundary comparison below.
##
## Vector3 stores 32-bit floats while these constants are 64-bit, so a bounce sitting
## "exactly" on a line arrives here a fraction of a micrometre to one side of it:
## Vector3(0, 0, 11.885).z reads back as 11.88500022, which is past the baseline.
## Without this, whether a ball on the line is in would be decided by rounding.
## 0.1 mm is orders of magnitude below anything that matters on a tennis court, and
## it makes a ball on the line reliably IN, which is the real rule.
const LINE_CALL_EPSILON: float = 0.0001


## True if a bounce at `pos` is in. Only X and Z are read.
##
## `tolerance` widens every boundary. Pass the ball radius to reproduce the real
## rule that a ball touching any part of the line is in; the default of 0.0 judges
## the contact point strictly, which is what the tests assert against.
static func is_in_bounds(pos: Vector3, singles: bool = true, tolerance: float = 0.0) -> bool:
	var half_width: float = SINGLES_HALF_WIDTH if singles else DOUBLES_HALF_WIDTH
	var slack: float = tolerance + LINE_CALL_EPSILON
	if absf(pos.x) > half_width + slack:
		return false
	return absf(pos.z) <= BASELINE_Z + slack


## True if a bounce at `pos` is inside one specific service box.
##
## Both booleans describe THE BOX BEING TESTED, not the server:
##   is_player_side      - the box is on the player's half (+Z), else the opponent's (-Z)
##   serving_from_right  - the right-hand box of that half, "right" seen by someone
##                         standing on that half facing the net (so +X on the player
##                         side, -X on the opponent side)
##
## A serve from the player's right-hand court must land in the box selected by
## is_in_service_box(pos, true, false) - diagonally opposite, and the caller is
## the one that works that diagonal out.
static func is_in_service_box(
	pos: Vector3,
	serving_from_right: bool,
	is_player_side: bool,
	tolerance: float = 0.0
) -> bool:
	var slack: float = tolerance + LINE_CALL_EPSILON
	if absf(pos.x) > SINGLES_HALF_WIDTH + slack:
		return false

	if is_player_side:
		if pos.z < -slack or pos.z > SERVICE_LINE_Z + slack:
			return false
	elif pos.z > slack or pos.z < -SERVICE_LINE_Z - slack:
		return false

	# Flip the notion of "right" for the far half, which faces the other way.
	var right_sign: float = 1.0 if is_player_side else -1.0
	var x_from_right: float = pos.x * right_sign
	if serving_from_right:
		return x_from_right >= -slack
	return x_from_right <= slack


## True if the straight segment from -> to passes through the plane of the net.
## Says nothing about whether the ball cleared the net; that is a later sprint.
static func crosses_net_plane(from: Vector3, to: Vector3) -> bool:
	return (from.z >= 0.0) != (to.z >= 0.0)


## Height of the net at a given X, as the parabolic sag used by both the collision
## maths and the three visual segments in court.tscn.
static func net_height_at(x: float) -> float:
	var t: float = clampf(absf(x) / NET_POST_X, 0.0, 1.0)
	return NET_HEIGHT_AT_CENTRE + (NET_HEIGHT_AT_POST - NET_HEIGHT_AT_CENTRE) * t * t
