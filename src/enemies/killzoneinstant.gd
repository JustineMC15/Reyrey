
## Environmental hazard (spikes, lava, fall-off-world) that damages
## the player ignoring i-frames, then teleports them to the nearest
## assigned respawn point with a screen fade and a fresh window of
## invincibility.
##
## Scene: one or more CollisionShape2D children covering the hazard
## (leave collision_layer/mask at project defaults so it still
## detects the player's CharacterBody2D). Drop a Marker2D near each
## safe spot this hazard should kick the player back to and drag
## them all into `respawn_points` — the nearest one to the player at
## contact is used, so one zone can cover several spike clusters or
## a whole fall-off-world strip.
extends Area2D
class_name HazardZone

@export var damage_amount: int = 1
@export var fade_duration: float = 0.25
@export var invincibility_after: float = 1.0

var respawn_points: Array[Marker2D] = []
var _busy := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	for child in get_children():
		if child is Marker2D:
			respawn_points.append(child)


func _on_body_entered(body: Node2D) -> void:
	if _busy or not body.is_in_group("player"):
		return

	if not body.has_method("take_hazard_damage"):
		return

	var target: Variant = _nearest_respawn_point(body.global_position)

	if target == null:
		push_error("HazardZone: no Marker2D respawn points found.")
		return

	_busy = true

	await body.take_hazard_damage(
		damage_amount,
		target,
		fade_duration,
		invincibility_after
	)

	_busy = false


func _nearest_respawn_point(from_position: Vector2) -> Variant:
	var nearest: Marker2D = null
	var nearest_dist := INF

	for point in respawn_points:
		if point == null:
			continue

		var dist := from_position.distance_squared_to(point.global_position)

		if dist < nearest_dist:
			nearest = point
			nearest_dist = dist

	return nearest.global_position if nearest else null
