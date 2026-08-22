class_name BallPhysicsConfig
extends Resource

## Single responsibility: hold every tunable number the ball integrator reads.
##
## Nothing in here is a node reference and nothing reads the scene tree, so the
## same resource drives the live ball and the AI's forward prediction. Designers
## tune these in the inspector; no script may hardcode an equivalent constant.

## Deliberately above the real 9.81. A real tennis arc reads as floaty on a phone
## screen, so the ball is pulled down harder to keep rallies quick.
@export var gravity: float = 13.5

## Real regulation tennis ball, per CLAUDE.md section 6.
@export var mass: float = 0.057
@export var radius: float = 0.0335

@export var drag_coefficient: float = 0.55
@export var air_density: float = 1.21

## Lumped empirical constant for the Magnus term, not a physical lift coefficient.
## See NOTES.md, Sprint 1: this model is linear in speed where reality is quadratic.
@export var magnus_coefficient: float = 0.000045

## Fraction of spin retained after one second of flight. Applied as
## pow(value, delta) so it is framerate independent.
@export var spin_decay_per_second: float = 0.85

## Below this speed the ball is considered dead and stops simulating.
@export var min_bounce_speed: float = 0.4


## Frontal area used by the drag term. Split out so the integrator reads as the
## textbook formula rather than an inlined pile of multiplications.
func cross_section_area() -> float:
	return PI * radius * radius
