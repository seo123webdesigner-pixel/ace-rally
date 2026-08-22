class_name CourtSurfaceConfig
extends Resource

## Single responsibility: describe how one court surface changes a bounce.
##
## Pure data. The integrator reads it; it reads nothing back.

## Kept in sync with the surface_type argument of EventBus.ball_bounced, which is
## typed as int and was fixed in Sprint 0.
enum SurfaceType {
	HARD,
	CLAY,
	GRASS,
	INDOOR,
}

@export var surface_name: String = ""
@export var surface_type: SurfaceType = SurfaceType.HARD

## Fraction of downward speed returned as upward speed after a bounce.
@export var vertical_restitution: float = 0.75

## Fraction of horizontal speed KEPT after a bounce. Lower means the surface
## grabs more: clay slows the ball, grass skids it through.
@export var horizontal_friction: float = 0.72

## Fraction of the contact patch's surface speed (spin cross up, times radius)
## converted into horizontal velocity at the bounce. The same fraction is scrubbed
## off the spin, since that energy has left the ball's rotation.
@export var bounce_spin_transfer: float = 0.4
