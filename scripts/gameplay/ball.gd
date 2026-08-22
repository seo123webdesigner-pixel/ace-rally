class_name Ball
extends Node3D

## Single responsibility: drive a BallSimulator and show the result.
##
## This node is presentation plus a step() call. It owns no physics of its own:
## every number comes out of the simulator, and the simulator never reads back
## from the node. Deliberately NOT a RigidBody3D, per CLAUDE.md section 3 rule 1 -
## the AI has to be able to re-run this exact flight forward.

## Tunables the integrator reads. Assigned in ball.tscn.
@export var physics_config: BallPhysicsConfig

## Which surface the ball is currently bouncing on. Set this when the venue
## changes; the ball does not go looking for a Court.
@export var surface: CourtSurfaceConfig

## Visual inflation. The simulated radius is physics_config.radius and never this:
## a 3.35 cm ball is nearly invisible on a phone, so the mesh is drawn bigger.
@export var visual_radius: float = 0.05

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shadow: MeshInstance3D = $Shadow
@onready var _trail: GPUParticles3D = $Trail

var simulator: BallSimulator

## Height at which the shadow has shrunk to its smallest, so a lob reads as high.
const SHADOW_FADE_HEIGHT: float = 6.0


func _ready() -> void:
	if physics_config == null:
		physics_config = BallPhysicsConfig.new()
	simulator = BallSimulator.new(physics_config)
	_apply_visual_radius()
	_set_trail_active(false)


## Puts the ball at `pos` travelling at `vel` with angular velocity `spin`, live.
func launch(pos: Vector3, vel: Vector3, spin: Vector3) -> void:
	simulator.reset(pos, vel, spin)
	global_position = pos
	_update_shadow()
	_set_trail_active(true)


## Stops the ball where it stands without moving it.
func kill() -> void:
	simulator.is_live = false
	_set_trail_active(false)


func is_live() -> bool:
	return simulator != null and simulator.is_live


func _physics_process(delta: float) -> void:
	if simulator == null or not simulator.is_live:
		return
	if surface == null:
		push_warning("Ball has no CourtSurfaceConfig; cannot resolve a bounce.")
		return

	var events: Array[BounceEvent] = simulator.step(delta, surface)

	global_position = simulator.position
	_update_shadow()

	for event: BounceEvent in events:
		EventBus.ball_bounced.emit(event.position, int(event.surface_type))

	if not simulator.is_live:
		_set_trail_active(false)


## Keeps the blob under the ball. The shadow is a child of a node that moves in Y,
## so its own Y has to be cancelled out rather than inherited.
func _update_shadow() -> void:
	if _shadow == null:
		return
	var ground: Vector3 = simulator.position
	# Just proud of the painted lines, whose tops sit at y = 0.005.
	_shadow.global_position = Vector3(ground.x, 0.007, ground.z)
	var closeness: float = 1.0 - clampf(ground.y / SHADOW_FADE_HEIGHT, 0.0, 1.0)
	var scale_factor: float = lerpf(0.45, 1.0, closeness)
	_shadow.scale = Vector3(scale_factor, 1.0, scale_factor)


func _apply_visual_radius() -> void:
	if _mesh == null or physics_config == null or physics_config.radius <= 0.0:
		return
	var inflation: float = visual_radius / physics_config.radius
	_mesh.scale = Vector3.ONE * inflation


## The trail is one preallocated GPUParticles3D that is only ever switched on and
## off. Nothing is instantiated mid-rally, per CLAUDE.md section 8.
func _set_trail_active(active: bool) -> void:
	if _trail == null:
		return
	_trail.emitting = active
