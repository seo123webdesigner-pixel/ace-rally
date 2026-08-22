class_name Court
extends Node3D

## Single responsibility: be the scene-side face of the court. It answers where the
## lines are and which surface is underfoot.
##
## All the geometry lives in CourtDimensions, which is a pure class, so the AI can
## ask the same questions without a scene tree. This node holds no measurements of
## its own; it delegates every one of them. Do not add a number to this file.

## Which surface this court plays like. Swapped per venue; drives every bounce.
@export var surface: CourtSurfaceConfig


func _ready() -> void:
	if surface == null:
		push_warning("Court has no CourtSurfaceConfig assigned; bounces cannot be resolved.")


## True if a bounce at `pos` is in. Judged strictly against the contact point:
## the real "any part of the ball touching the line is in" rule would pass the ball
## radius as a tolerance, which is a gameplay-feel call for the line-call sprint.
func is_in_bounds(pos: Vector3, singles: bool = true) -> bool:
	return CourtDimensions.is_in_bounds(pos, singles)


## True if a bounce at `pos` is inside one specific service box. Both booleans
## describe the box being tested, not the server; see CourtDimensions for the
## full convention and for which box a given serve has to find.
func is_in_service_box(pos: Vector3, serving_from_right: bool, is_player_side: bool) -> bool:
	return CourtDimensions.is_in_service_box(pos, serving_from_right, is_player_side)


func get_surface() -> CourtSurfaceConfig:
	return surface


## True if the straight segment from -> to passes through the plane of the net.
func crosses_net_plane(from: Vector3, to: Vector3) -> bool:
	return CourtDimensions.crosses_net_plane(from, to)
