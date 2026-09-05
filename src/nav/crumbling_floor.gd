extends StaticBody2D
class_name CrumblingFloor

## Shakes while the player stands on it, then vanishes out from
## under them. Set respawn_delay = 0 to make it gone for the rest of
## the room visit; leave it positive to have it reform later.
##
## guaranteed_break_time > 0 makes this a "guaranteed break" floor:
## touching it starts a countdown that always ends in a crumble, and
## the floor shakes continuously from that first touch all the way
## to the break — leaving early does NOT stop the shake or reset
## anything, so it reads as one uninterrupted event.
##
## Set guaranteed_break_time = 0 to disable that and get the plain
## behavior instead: stand > shake > leave > shake stops and resets,
## only breaking if the player stands continuously for
## stand_time_to_crumble.

@export var stand_time_to_crumble: float = 0.6
@export var shake_strength: float = 3.0
@export var respawn_delay: float = 4.0

## Time after first touch before a guaranteed break fires. 0 disables
## guaranteed breaking (plain stand/leave/reset behavior instead).
@export var guaranteed_break_time: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var detection_area: Area2D = $DetectionArea
@onready var crumble_sound: AudioStreamPlayer2D = $CrumbleSound if has_node("CrumbleSound") else null

var _stand_timer := 0.0
var _player_on_top := false
var _crumbled := false
var _base_visual_position: Vector2

var _touched := false
var _guaranteed_timer := 0.0
var _has_guaranteed_break := false


func _ready() -> void:
	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)

	_has_guaranteed_break = guaranteed_break_time > 0.0

	if visual:
		_base_visual_position = visual.position


func _process(delta: float) -> void:
	if _crumbled:
		return

	if _touched and _has_guaranteed_break:
		_guaranteed_timer -= delta
		_shake_visual()

		if _guaranteed_timer <= 0.0:
			_crumble()
			return

		if _player_on_top:
			_stand_timer += delta

			if _stand_timer >= stand_time_to_crumble:
				_crumble()

		return

	if not _player_on_top:
		return

	_stand_timer += delta
	_shake_visual()

	if _stand_timer >= stand_time_to_crumble:
		_crumble()


func _shake_visual() -> void:
	if not visual:
		return

	visual.position = _base_visual_position + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = true

	if not _touched:
		_touched = true
		_guaranteed_timer = guaranteed_break_time

		if crumble_sound:
			crumble_sound.play()

func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = false

	# Guaranteed-break floors keep shaking/counting after the player
	# leaves — only plain floors reset here.
	if _has_guaranteed_break:
		return

	_stand_timer = 0.0

	if visual:
		visual.position = _base_visual_position


func _crumble() -> void:
	_crumbled = true
	collision_shape.set_deferred("disabled", true)

	if visual:
		visual.position = _base_visual_position

	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.2)

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout
		_respawn()

func _respawn() -> void:
	_crumbled = false
	_stand_timer = 0.0
	_player_on_top = false

	_touched = false
	_guaranteed_timer = 0.0

	collision_shape.disabled = false

	if visual:
		visual.position = _base_visual_position

		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.2)
