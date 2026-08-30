extends Area2D
class_name AreaTitle

## Displays an area name when the player enters this Area2D.
## Each area only appears once per save file.

@export_category("Area")
@export var area_id: int = -1

@export_category("Animation")
@export var fade_in_duration: float = 1.0
@export var hold_duration: float = 3.0
@export var fade_out_duration: float = 1.0

@onready var label: Label = $CanvasLayer/Label

var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	label.modulate.a = 0.0


func _on_body_entered(body: Node2D) -> void:
	if has_triggered:
		return

	if not body is CharacterBody2D:
		return

	if area_id < 0:
		push_warning("AreaTitle: Area ID is not set.")
		return

	var seen_key := str(area_id)

	if GameState.area_names_seen.get(seen_key, false):
		has_triggered = true
		return

	GameState.area_names_seen[seen_key] = true
	has_triggered = true

	label.text = SaveManager.get_area_name(area_id).to_upper()
	label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(label, "modulate:a", 0.0, fade_out_duration)
