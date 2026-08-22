extends StaticBody2D
class_name ShortcutObject

## Any blocking piece — door, bridge, ladder, or breakable wall —
## that permanently opens once its shortcut_id has been activated by
## a ShortcutLever elsewhere in the world. Mechanically these are all
## the same thing (a blocker that becomes passable); only the sprite
## and CollisionShape2D you author differ per use.
##
## Scene: CollisionShape2D on collision_layer = 1. Optional Sprite2D.

@export var shortcut_id: String = ""
@export var fade_duration: float = 0.4

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: CanvasItem = $Sprite2D if has_node("Sprite2D") else null


func _ready() -> void:
	GameState.shortcut_activated.connect(_on_shortcut_activated)

	if GameState.is_shortcut_activated(shortcut_id):
		_open(true)


func _on_shortcut_activated(activated_id: String) -> void:
	if activated_id != shortcut_id:
		return

	_open(false)


func _open(instant: bool) -> void:
	collision_shape.set_deferred("disabled", true)

	if not sprite:
		return

	if instant:
		sprite.modulate.a = 0.15
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.15, fade_duration)
