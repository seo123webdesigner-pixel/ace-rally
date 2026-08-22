class_name BallState
extends RefCounted

## Single responsibility: the mutable state one integration substep operates on.
##
## This exists so that the live ball and a throwaway prediction copy are the exact
## same kind of thing, and BallSimulator._substep() can be a single static function
## that both go through. There is deliberately only one copy of the integrator in
## this project; that is what makes the AI's prediction trustworthy.

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var is_live: bool = false

## Seconds integrated since the last reset. Timestamps bounce events and anchors
## predict_position_at_time().
var elapsed: float = 0.0


func duplicate_state() -> BallState:
	var copy: BallState = BallState.new()
	copy.position = position
	copy.velocity = velocity
	copy.spin = spin
	copy.is_live = is_live
	copy.elapsed = elapsed
	return copy
