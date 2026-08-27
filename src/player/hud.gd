extends Control

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_damage_bar: ProgressBar = $HPDamageBar
@onready var mp_bar: ProgressBar = $MPBar
@onready var mp_damage_bar: ProgressBar = $MPDamageBar
@onready var stamina_bar: ProgressBar = $STBar
@onready var stamina_damage_bar: ProgressBar = $STDamageBar
@onready var star_fragment_reward: StarFragmentReward = $StarFragmentReward
var potion_indicator: Label

func _ready() -> void:
	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("HUD: Could not find Player in the 'player' group.")
		return

	hp_bar.max_value = player.max_health
	hp_bar.value = player.health

	hp_damage_bar.max_value = player.max_health
	hp_damage_bar.value = player.health

	mp_bar.max_value = player.max_mp
	mp_bar.value = player.mp

	mp_damage_bar.max_value = player.max_mp
	mp_damage_bar.value = player.mp

	if stamina_bar and stamina_damage_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.stamina

		stamina_damage_bar.max_value = player.max_stamina
		stamina_damage_bar.value = player.stamina

	# Initialize the Star Fragment display without showing it.
	star_fragment_reward.initialize_amount(
		GameState.star_fragments
	)

	# Listen for new Star Fragment rewards.
	if not GameState.star_fragments_changed.is_connected(
		_on_star_fragments_changed
	):
		GameState.star_fragments_changed.connect(
			_on_star_fragments_changed
		)

	player.health_changed.connect(_on_player_health_changed)
	player.mp_changed.connect(_on_player_mp_changed)
	player.stamina_changed.connect(_on_player_stamina_changed)
	potion_indicator = Label.new()
	potion_indicator.text = "POTION READY"
	potion_indicator.add_theme_font_size_override("font_size", 16)
	potion_indicator.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	potion_indicator.position = Vector2(20, 112)
	potion_indicator.visible = GameState.potion_charged
	add_child(potion_indicator)

	GameState.potion_mix_changed.connect(_on_potion_state_changed)
	GameState.potion_used.connect(_on_potion_state_changed)


func _on_potion_state_changed() -> void:
	if potion_indicator:
		potion_indicator.visible = GameState.potion_charged

func _on_star_fragments_changed(amount: int) -> void:
	star_fragment_reward.show_new_total(amount)


func _on_player_health_changed(
	current_health,
	max_health
) -> void:
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


func _on_player_mp_changed(
	current_mp,
	max_mp
) -> void:
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


func _on_player_stamina_changed(
	current_stamina,
	max_stamina
) -> void:
	if not stamina_bar:
		return

	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina

	stamina_damage_bar.max_value = max_stamina

	var tween := create_tween()

	tween.tween_property(
		stamina_damage_bar,
		"value",
		current_stamina,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
