class_name LandingPrediction
extends RefCounted

## Single responsibility: the answer to "where and when does this ball first land".
##
## Produced by BallSimulator.predict_landing() by re-running the same integrator
## forward on a copy of the state. This is what the AI moves toward and what the
## physics lab draws its ring at.

## True if a bounce was actually found inside the search window. When false, every
## other field is meaningless: the ball was still airborne when the search ran out.
var found: bool = false

var position: Vector3 = Vector3.ZERO

## Seconds from now until the bounce, not an absolute timestamp.
var time: float = 0.0

## Judged singles, strictly against the contact point. See CourtDimensions.is_in_bounds.
var in_bounds: bool = false

## Velocity the ball will be carrying as it arrives.
var incoming_velocity: Vector3 = Vector3.ZERO
