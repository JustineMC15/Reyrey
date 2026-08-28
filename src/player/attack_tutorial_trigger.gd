extends Area2D

const TUTORIAL_ID := "attack"
@onready var attack_panel: Panel = $"../TutorialUI/Control/AttackPanel"

var has_finished := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	attack_panel.modulate.a = 0.0
	attack_panel.hide()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection") or has_finished:
		return

	attack_panel.show()

	var tween := create_tween()
	tween.tween_property(attack_panel, "modulate:a", 1.0, 0.25)

func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection") or has_finished:
		return

	has_finished = true

	var tween := create_tween()
	tween.tween_property(attack_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(attack_panel.hide)
