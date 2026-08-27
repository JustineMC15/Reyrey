extends Area2D
class_name PotionSlot

## One-time pickup unlocking a single Wondrous Star Potion mixing
## slot (Survival / Combat / Utility). Exactly three of these exist
## in the world — set `category` per instance in the Inspector.
##
## This does NOT grant an effect. Effects unlock separately through
## lifetime star fragment totals (see GameState.potion_effect_data).
## Picking this up only opens the category so an already-unlocked
## effect can be loaded into it at a checkpoint.
##
## Scene: same shape as starlight_shard.gd / anvil.gd — this node IS
## the Area2D, drag your own prompt Panel into `prompt_panel`.

@export_enum("survival", "combat", "utility") var category: String = "survival"
@export var prompt_panel: Panel

var activated: bool = false
var player_inside := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.is_potion_slot_unlocked(category):
		queue_free()


func _process(_delta: float) -> void:
	if activated or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		activated = true

		if prompt_panel:
			prompt_panel.hide()

		GameState.unlock_potion_slot(category)

		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
