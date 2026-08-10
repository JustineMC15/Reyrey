extends Area2D
@export var base_damage := 1
var player_inside := false
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		body.take_damage(base_damage)
		$DamageTimer.start()
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$DamageTimer.stop()
func _on_damage_timer_timeout() -> void:
	if player_inside:
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(base_damage)
