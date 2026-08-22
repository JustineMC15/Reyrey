extends StaticBody2D
class_name BreakableWall

## Takes hits from any player attack and disappears permanently once
## its hit points reach zero. Covers "attack wall until it breaks"
## and plain "breakable wall" — max_hits = 1 gives you the latter.
##
## Scene: CollisionShape2D on collision_layer = 3 (bit for "blocks
## the player" + bit for "hittable by weapons" — matches the value
## every weapon hitbox in the project scans). Optional Sprite2D.

@export var wall_id: String = ""
@export var max_hits: int = 3
@export var respawn_on_reload: bool = false  ## true = ignore saved broken state (re-blocks on room reload)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: CanvasItem = $Sprite2D if has_node("Sprite2D") else null

var hits_remaining: int


func _ready() -> void:
	add_to_group("attackable")

	if not respawn_on_reload and GameState.is_obstacle_broken(wall_id):
		queue_free()
		return

	hits_remaining = max_hits


func take_damage(_amount: int) -> void:
	hits_remaining -= 1
	_flash()

	if hits_remaining <= 0:
		_break()


func _flash() -> void:
	if not sprite:
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _break() -> void:
	if not respawn_on_reload:
		GameState.break_obstacle(wall_id)

	collision_shape.set_deferred("disabled", true)

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)
	else:
		queue_free()
