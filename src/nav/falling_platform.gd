extends AnimatableBody2D
class_name FallingPlatform

## A platform that shakes then drops once the player has stood on it
## for stand_time_before_fall seconds. Unlike CrumblingFloor, this
## one physically falls (and can crush enemies/be a hazard below) and
## always respawns at its start position rather than staying broken.
##
## Scene children expected:
##   CollisionShape2D — collision_layer = 1
##   DetectionArea    — Area2D flush with the platform's top surface,
##                      collision_layer = 4, mask = 5
##   Sprite2D         — optional

@export var stand_time_before_fall: float = 0.5
@export var fall_speed: float = 900.0
@export var shake_strength: float = 3.0
@export var respawn_delay: float = 3.0

@onready var sprite: CanvasItem = $Sprite2D if has_node("Sprite2D") else null
@onready var detection_area: Area2D = $DetectionArea

var _stand_timer := 0.0
var _player_on_top := false
var _falling := false
var _start_position: Vector2


func _ready() -> void:
	_start_position = global_position

	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if _falling:
		global_position.y += fall_speed * delta
		return

	if not _player_on_top:
		return

	_stand_timer += delta

	if sprite:
		sprite.position = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

	if _stand_timer >= stand_time_before_fall:
		_start_falling()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = true


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	_player_on_top = false
	_stand_timer = 0.0

	if sprite:
		sprite.position = Vector2.ZERO


func _start_falling() -> void:
	_falling = true

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout
		_respawn()


func _respawn() -> void:
	_falling = false
	_player_on_top = false
	_stand_timer = 0.0
	global_position = _start_position

	if sprite:
		sprite.position = Vector2.ZERO
