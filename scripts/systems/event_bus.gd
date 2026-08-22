class_name EventBusSingleton
extends Node

## Single responsibility: carry cross-system gameplay events between systems that
## must not hold references to each other. Signals only, no state and no logic.

signal ball_bounced(position: Vector3, surface_type: int)
signal ball_hit(by_player: bool, shot_quality: int)
signal point_ended(winner_is_player: bool, reason: int)
signal game_ended(winner_is_player: bool)
signal set_ended(winner_is_player: bool)
signal match_ended(winner_is_player: bool)
