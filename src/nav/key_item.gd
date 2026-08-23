extends Area2D
class_name KeyItem

## A pickup that unlocks any LockedDoor sharing its key_id. Press E
## while standing in it to collect. Won't respawn once collected —
## GameState remembers it across saves.
##
## Scene: this node IS the Area2D (collision_layer = 4,
## collision_mask = 5, matching every other player-detecting trigger
## in the project). Drag your own prompt Panel into `prompt_panel`.
##
## Visual can be either TileMapLayer or Sprite2D. Optional
## PickupSound (AudioStreamPlayer2D) plays on collect.

@export var key_id: String = ""
@export var prompt_panel: Panel

@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var pickup_sound: AudioStreamPlayer2D = $PickupSound if has_node("PickupSound") else null

var activated := false
var player_inside := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.has_key(key_id):
		queue_free()


func _process(_delta: float) -> void:
	if activated or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		activated = true
		player_inside = false

		if prompt_panel:
			prompt_panel.hide()

		GameState.collect_key(key_id)

		if pickup_sound:
			pickup_sound.play()
			await pickup_sound.finished

		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
