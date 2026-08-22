class_name BounceEvent
extends RefCounted

## Single responsibility: describe one ball-ground contact, after the fact.
##
## Emitted by BallSimulator.step(). Carries everything a listener could want so
## that nothing has to reach back into the simulator and read state that has
## already moved on.

## Contact point, solved to the exact moment the ball crossed y = radius rather
## than the end of the substep it was noticed in. This is the point a line call
## is judged against.
var position: Vector3 = Vector3.ZERO

## Seconds since the simulator was last reset, at the moment of contact.
var time: float = 0.0

var incoming_velocity: Vector3 = Vector3.ZERO
var outgoing_velocity: Vector3 = Vector3.ZERO
var incoming_spin: Vector3 = Vector3.ZERO

var surface_type: CourtSurfaceConfig.SurfaceType = CourtSurfaceConfig.SurfaceType.HARD

## False if this contact killed the ball, i.e. it was too slow to bounce again.
var still_live: bool = true


## Downward speed at contact. The usual input to bounce audio and impact particles.
func impact_speed() -> float:
	return absf(incoming_velocity.y)
