extends Area2D
class_name Scripture

@export var ability_id: String = "double_jump"
@export var claim_icon: Texture2D  # drag the pickup's sprite texture in here
var activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	if body.is_in_group("player"):
		activated = true
		GameState.claim_ability(ability_id, body, claim_icon)
		queue_free()
