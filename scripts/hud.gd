extends Control

@onready var player = get_tree().get_first_node_in_group("player")
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_damage_bar: ProgressBar = $HPDamageBar
@onready var mp_bar: ProgressBar = $MPBar
@onready var mp_damage_bar: ProgressBar = $MPDamageBar
func _ready() -> void:
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health

	hp_damage_bar.max_value = player.max_health
	hp_damage_bar.value = player.health

	mp_bar.max_value = player.max_mp
	mp_bar.value = player.mp

	mp_damage_bar.max_value = player.max_mp
	mp_damage_bar.value = player.mp

	player.health_changed.connect(_on_player_health_changed)
	player.mp_changed.connect(_on_player_mp_changed)

func _on_player_health_changed(current_health, max_health) -> void:
	hp_bar.max_value = max_health
	hp_bar.value = current_health

	hp_damage_bar.max_value = max_health

	var tween := create_tween()
	tween.tween_property(
		hp_damage_bar,
		"value",
		current_health,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_player_mp_changed(current_mp, max_mp) -> void:
	mp_bar.max_value = max_mp
	mp_bar.value = current_mp

	mp_damage_bar.max_value = max_mp

	var tween := create_tween()
	tween.tween_property(
		mp_damage_bar,
		"value",
		current_mp,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
