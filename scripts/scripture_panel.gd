extends Area2D
class_name Scripture

@export var ability_id: String = "double_jump"
@export var claim_icon: Texture2D
@onready var prompt_panel: Panel = $"../TutorialUI/Control/ScripturePanel"

var activated: bool = false
var player_inside := false
var player_ref: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_panel.modulate.a = 0.0
	prompt_panel.hide()

func _on_body_entered(body: Node2D) -> void:
	if activated or not body.is_in_group("player"):
		return
	player_inside = true
	player_ref = body
	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)

func _on_body_exited(body: Node2D) -> void:
	if activated or not body.is_in_group("player"):
		return
	player_inside = false
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)

func _process(_delta: float) -> void:
	if activated or not player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		activated = true
		prompt_panel.hide()
		GameState.claim_ability(ability_id, player_ref, claim_icon)
		queue_free()
