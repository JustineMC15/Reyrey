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
##   TileMapLayer     — optional visual
##   Sprite2D         — optional alternative visual
##   OpenSound        — optional AudioStreamPlayer2D
##   CloseSound       — optional AudioStreamPlayer2D
##
## If using TileMapLayer, it should contain only this door's tiles.
## Sounds only play on real open()/close() calls, never on the silent
## state restore that happens at _ready() from start_open.

@export var start_open: bool = false
@export var fade_duration: float = 0.3
@export var reveal_alpha: float = 0.15
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var open_sound: AudioStreamPlayer2D = $OpenSound if has_node("OpenSound") else null
@onready var close_sound: AudioStreamPlayer2D = $CloseSound if has_node("CloseSound") else null

var is_open := false


func _ready() -> void:
	_apply_open(start_open, true)
	is_open = start_open


func open() -> void:
	if is_open:
		return

	is_open = true
	_apply_open(true, false)

	if open_sound:
		open_sound.play()


func close() -> void:
	if not is_open:
		return

	is_open = false
	_apply_open(false, false)

	if close_sound:
		close_sound.play()


func _apply_open(open_state: bool, instant: bool) -> void:
	collision_shape.set_deferred("disabled", open_state)

	if not visual:
		return
	var target_alpha := reveal_alpha if open_state else 1.0

	if instant:
		visual.modulate.a = target_alpha
		return

	var tween := create_tween()
	tween.tween_property(
		visual,
		"modulate:a",
		target_alpha,
		fade_duration
	)
