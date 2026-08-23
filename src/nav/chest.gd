extends Area2D
class_name StarFragmentChest

enum ChestTier {
	WOOD,
	STONE,
	SILVER,
	GOLD
}

@export var chest_id: String = ""
@export var star_fragment_reward: int = 25
@export var chest_tier: ChestTier = ChestTier.WOOD
@export var prompt_panel: Panel
@export var opening_sound: AudioStreamPlayer2D = null

var activated: bool = false
var player_inside: bool = false
var player_ref: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if chest_id != "" and GameState.is_chest_opened(chest_id):
		activated = true
		_play_open_animation()
	else:
		_play_closed_animation()


func _process(_delta: float) -> void:
	if activated or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		activated = true

		if prompt_panel:
			prompt_panel.hide()

		_open_chest()


func _open_chest() -> void:
	if chest_id != "":
		GameState.open_chest(chest_id)

	GameState.add_star_fragments(star_fragment_reward)

	_play_open_animation()

	if opening_sound:
		opening_sound.play()


func _play_closed_animation() -> void:
	match chest_tier:
		ChestTier.WOOD:
			animated_sprite.play("wood_closed")

		ChestTier.STONE:
			animated_sprite.play("stone_closed")

		ChestTier.SILVER:
			animated_sprite.play("silver_closed")

		ChestTier.GOLD:
			animated_sprite.play("gold_closed")


func _play_open_animation() -> void:
	match chest_tier:
		ChestTier.WOOD:
			animated_sprite.play("wood_open")

		ChestTier.STONE:
			animated_sprite.play("stone_open")

		ChestTier.SILVER:
			animated_sprite.play("silver_open")

		ChestTier.GOLD:
			animated_sprite.play("gold_open")


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true
	player_ref = area.get_parent()

	if not prompt_panel:
		return

	prompt_panel.show()

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		1.0,
		0.25
	)


func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false
	player_ref = null

	if not prompt_panel:
		return

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		0.0,
		0.25
	)

	tween.tween_callback(prompt_panel.hide)
