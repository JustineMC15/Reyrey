extends Control

@onready var player = get_tree().get_first_node_in_group("player")
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_damage_bar: ProgressBar = $HPDamageBar


func _ready() -> void:
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health

	hp_damage_bar.max_value = player.max_health
	hp_damage_bar.value = player.health

	player.health_changed.connect(_on_player_health_changed)


func _on_player_health_changed(current_health, _max_health) -> void:
	hp_bar.value = current_health

	var tween := create_tween()
	tween.tween_property(
		hp_damage_bar,
		"value",
		current_health,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
