extends Area2D
class_name Anvil

@export var anvil_id: String = ""

@onready var prompt_panel: Panel = $CollisionShape2D/PromptPanel
var activated: bool = false
var player_inside := false
var player_ref: Node2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	prompt_panel.modulate.a = 0.0
	prompt_panel.hide()

	if GameState.is_anvil_claimed(anvil_id):
		queue_free()
		return


func _process(_delta: float) -> void:
	if activated or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		activated = true
		player_inside = false

		prompt_panel.hide()

		await GameState.claim_anvil(anvil_id, player_ref)

		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true
	player_ref = area.get_parent()

	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false
	player_ref = null

	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
