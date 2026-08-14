extends Area2D

@onready var jump_panel: Panel = $"../TutorialUI/Control/JumpPanel"

var has_finished := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	jump_panel.modulate.a = 0.0
	jump_panel.hide()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection") or has_finished:
		return

	jump_panel.show()

	var tween := create_tween()
	tween.tween_property(jump_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection") or has_finished:
		return

	has_finished = true

	var tween := create_tween()
	tween.tween_property(jump_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(jump_panel.hide)
