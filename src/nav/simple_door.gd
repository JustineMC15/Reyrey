extends StaticBody2D
class_name SimpleDoor

## A plain obstacle other systems can open/close by calling open()
## and close() on it — point AttackSwitch.target_door,
## EnemyGauntlet.target_door, or a ShortcutObject at one of these.
## Carries no state of its own beyond is_open; whoever is driving it
## (AttackSwitch, GameState via a shortcut, etc.) decides whether that
## state should persist.
##
## Scene children expected:
##   CollisionShape2D — collision_layer = 1
##   Sprite2D         — optional, faded when open

@export var start_open: bool = false
@export var fade_duration: float = 0.3

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: CanvasItem = $Sprite2D if has_node("Sprite2D") else null

var is_open := false


func _ready() -> void:
	_apply_open(start_open, true)
	is_open = start_open


func open() -> void:
	if is_open:
		return

	is_open = true
	_apply_open(true, false)


func close() -> void:
	if not is_open:
		return

	is_open = false
	_apply_open(false, false)


func _apply_open(open_state: bool, instant: bool) -> void:
	collision_shape.set_deferred("disabled", open_state)

	if not sprite:
		return

	var target_alpha := 0.15 if open_state else 1.0

	if instant:
		sprite.modulate.a = target_alpha
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", target_alpha, fade_duration)
