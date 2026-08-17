extends Area2D
class_name Scripture

@export var ability_id: String = ""
@export var claim_icon: Texture2D
@export var prompt_panel: Panel

var activated: bool = false
var player_inside := false
var player_ref: Node2D

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.has_ability(ability_id):
		modulate.a = 3.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
		return

func _process(_delta: float) -> void:
	if activated or not player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		activated = true
		if prompt_panel:
			prompt_panel.hide()

		GameState.claim_ability(ability_id, player_ref, claim_icon)

		if player_ref.has_method("restore_full_mp"):
			player_ref.restore_full_mp()

		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true
	player_ref = area.get_parent()

	if not prompt_panel:
		return
	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)

func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false
	player_ref = null

	if not prompt_panel:
		return
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
