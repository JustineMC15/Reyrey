
## Environmental hazard (spikes, lava, fall-off-world) that damages
## the player ignoring i-frames, then teleports them back to the
## last "safe ground" position they stood on, with a screen fade and
## a fresh window of invincibility.
##
## Set pogoable = true for hazards the player should bounce off with
## a pogo attack instead of taking damage (spikes). Leave it false
## for hazards that should always hurt regardless of attack type
## (water, fall-off-world, lava).
##
## Scene: one or more CollisionShape2D children covering the hazard
## (leave collision_layer/mask at project defaults so it still
## detects the player's CharacterBody2D). Drop a Marker2D near each
## safe spot as a FALLBACK ONLY — under normal play, respawn uses the
## player's own tracked last-safe-ground position instead, so these
## markers only matter if the player never touched solid ground in
## this room yet (e.g. dropped in mid-air and hit a hazard instantly).
##
## Optional PogoBounceSound (AudioStreamPlayer2D child) plays when a
## pogoable hazard is bounced off instead of hurting the player.
extends Area2D
class_name HazardZone

@export var damage_amount: int = 1
@export var fade_duration: float = 0.25
@export var invincibility_after: float = 1.0
@export var pogoable: bool = false

const POGO_BOUNCE_SHAKE_STRENGTH := 4.0
const POGO_BOUNCE_SHAKE_DURATION := 0.1

@onready var pogo_bounce_sound: AudioStreamPlayer2D = (
	$PogoBounceSound if has_node("PogoBounceSound") else null
)

var respawn_points: Array[Marker2D] = []
var _busy := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if pogoable:
		add_to_group("pogoable_hazard")

	for child in get_children():
		if child is Marker2D:
			respawn_points.append(child)

func _on_body_entered(body: Node2D) -> void:
	if _busy or not body.is_in_group("player"):
		return

	if pogoable and body.has_method("is_pogo_bounce_active") and body.is_pogo_bounce_active():
		_bounce_off(body)
		return

	if not body.has_method("take_hazard_damage"):
		return

	var target: Variant = _get_respawn_position(body)

	if target == null:
		push_error("HazardZone: no fallback Marker2D respawn points found.")
		return

	_busy = true

	await body.take_hazard_damage(
		damage_amount,
		target,
		fade_duration,
		invincibility_after
	)

	_busy = false


func _bounce_off(body: Node) -> void:
	if body.has_method("bounce_off_hazard"):
		body.bounce_off_hazard()

	if pogo_bounce_sound:
		pogo_bounce_sound.play()

	if body.has_method("camera_shake"):
		body.camera_shake(POGO_BOUNCE_SHAKE_STRENGTH, POGO_BOUNCE_SHAKE_DURATION)


func _get_respawn_position(body: Node) -> Variant:
	var fallback: Variant = _nearest_respawn_point(body.global_position)

	if body.has_method("get_hazard_respawn_position"):
		return body.get_hazard_respawn_position(fallback)

	return fallback


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
