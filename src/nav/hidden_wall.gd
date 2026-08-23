extends StaticBody2D
class_name HiddenWall

## Looks like ordinary terrain until the player gets close, at which
## point it fades into a passable, revealed state permanently for
## this save file — no re-hiding on reload.
##
## Scene children expected:
##   CollisionShape2D — the blocking shape, collision_layer = 1
##   DetectionArea    — Area2D covering the approach zone,
##                      collision_layer = 4, collision_mask = 5
##   TileMapLayer     — optional visual
##   RevealSound      — optional AudioStreamPlayer2D, the "ping" that
##                      plays the moment the wall is discovered
##                      (never plays on the silent reload-from-save path)

@export var secret_id: String = ""
@export var reveal_alpha: float = 0.15
@export var reveal_duration: float = 0.6

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = $TileMapLayer if has_node("TileMapLayer") else null
@onready var detection_area: Area2D = $DetectionArea
@onready var reveal_sound: AudioStreamPlayer2D = $RevealSound if has_node("RevealSound") else null

var _revealed := false


func _ready() -> void:
	detection_area.area_entered.connect(_on_area_entered)

	if GameState.is_secret_revealed(secret_id):
		_reveal(true)


func _on_area_entered(area: Area2D) -> void:
	if _revealed or not area.is_in_group("player_detection"):
		return

	GameState.reveal_secret(secret_id)
	_reveal(false)


func _reveal(instant: bool) -> void:
	_revealed = true
	collision_shape.set_deferred("disabled", true)

	if not instant and reveal_sound:
		reveal_sound.play()

	if not visual:
		return

	if instant:
		visual.modulate.a = reveal_alpha
		return

	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", reveal_alpha, reveal_duration)
