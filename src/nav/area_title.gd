extends Area2D
class_name AreaTitle

## Displays an area name when the player enters this Area2D.
## Each area only appears once per save file.

@export_category("Area")
@export var area_id: String = ""
@export var area_name: String = ""

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

	# Only react to the player.
	if not body is CharacterBody2D:
		return

	if area_id == "":
		push_warning("AreaTitle: Area ID is empty.")
		return

	if area_name == "":
		push_warning("AreaTitle: Area Name is empty.")
		return

	# Check whether this area has already been shown
	# in the current save file.
	if GameState.area_names_seen.get(area_id, false):
		has_triggered = true
		return

	# Mark this area as seen immediately.
	# This prevents the title from triggering more than once.
	GameState.area_names_seen[area_id] = true
	has_triggered = true

	label.text = area_name
	label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Fade in.
	tween.tween_property(
		label,
		"modulate:a",
		1.0,
		fade_in_duration
	)

	# Hold.
	tween.tween_interval(hold_duration)

	# Fade out.
	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		fade_out_duration
	)
