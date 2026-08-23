extends StaticBody2D
class_name CrumblingFloor

## Shakes while the player stands on it, then vanishes out from
## under them. Set respawn_delay = 0 to make it gone for the rest of
## the room visit; leave it positive to have it reform later so a
## careless second pass isn't punished forever.
##
## Scene children expected:
##   CollisionShape2D — collision_layer = 1
##   DetectionArea    — Area2D sitting just above the platform's
##                      surface, collision_layer = 4, mask = 5
##   TileMapLayer     — optional, shakes and fades with the tile
##   Sprite2D         — optional alternative to TileMapLayer
##   CrumbleSound     — optional AudioStreamPlayer2D, plays the
##                      instant it gives way

@export var stand_time_to_crumble: float = 0.6
@export var shake_strength: float = 3.0
@export var respawn_delay: float = 4.0

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


func _ready() -> void:
	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)

	if visual:
		_base_visual_position = visual.position


func _process(delta: float) -> void:
	if _crumbled or not _player_on_top:
		return

	_stand_timer += delta

	if visual:
		visual.position = _base_visual_position + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

	if _stand_timer >= stand_time_to_crumble:
		_crumble()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = true


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = false
	_stand_timer = 0.0

	if visual:
		visual.position = _base_visual_position


func _crumble() -> void:
	_crumbled = true
	collision_shape.set_deferred("disabled", true)

	if crumble_sound:
		crumble_sound.play()

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
	collision_shape.disabled = false

	if visual:
		visual.position = _base_visual_position

		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.2)
