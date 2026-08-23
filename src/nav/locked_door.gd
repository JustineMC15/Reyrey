extends StaticBody2D
class_name LockedDoor

## Physically blocks the path until the player is carrying the
## matching key (from a KeyItem with the same required_key_id).
## Opens permanently once unlocked, for the rest of the save file.
##
## Scene children expected:
##   CollisionShape2D  — the physical block, collision_layer = 1
##   DetectionArea     — Area2D, collision_layer = 4, collision_mask = 5
##   TileMapLayer      — optional visual
##   Sprite2D          — optional alternative visual
##   UnlockSound       — optional AudioStreamPlayer2D, plays on unlock
##   DeniedSound       — optional AudioStreamPlayer2D, plays when the
##                       player interacts without the right key
## Drag your prompt Panel into `prompt_panel`.
##
## If using TileMapLayer, it should contain only this door's tiles.

@export var door_id: String = ""
@export var required_key_id: String = ""
@export var consume_key: bool = false
@export var prompt_panel: Panel

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var unlock_sound: AudioStreamPlayer2D = $UnlockSound if has_node("UnlockSound") else null
@onready var denied_sound: AudioStreamPlayer2D = $DeniedSound if has_node("DeniedSound") else null

var player_inside := false


func _ready() -> void:
	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.is_door_open(door_id):
		_open(true)


func _process(_delta: float) -> void:
	if not player_inside or GameState.is_door_open(door_id):
		return

	if Input.is_action_just_pressed("interact"):
		_try_unlock()


func _try_unlock() -> void:
	if not GameState.has_key(required_key_id):
		if denied_sound:
			denied_sound.play()
		return

	if consume_key:
		GameState.consume_key(required_key_id)

	GameState.open_door_permanently(door_id)

	if unlock_sound:
		unlock_sound.play()

	_open(false)


func _open(instant: bool) -> void:
	collision_shape.set_deferred("disabled", true)

	if prompt_panel:
		prompt_panel.hide()

	if not visual:
		return

	if instant:
		visual.modulate.a = 0.0
		return

	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection") or GameState.is_door_open(door_id):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
