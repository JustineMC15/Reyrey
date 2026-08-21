extends Panel

const TUTORIAL_ID := "movement"

var has_shown_move := false

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	if GameState.has_seen_tutorial(TUTORIAL_ID):
		queue_free()
		return

	modulate.a = 0.0

	await get_tree().create_timer(1.0).timeout

	if not is_inside_tree():
		return

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func _process(_delta: float) -> void:
	if not has_shown_move and abs(player.velocity.x) > 0.0:
		has_shown_move = true
		dismiss_prompt()


func dismiss_prompt() -> void:
	GameState.mark_tutorial_seen(TUTORIAL_ID)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
