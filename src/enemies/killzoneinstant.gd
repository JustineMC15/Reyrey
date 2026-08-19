extends Area2D

func _ready() -> void:
	print(
		"KILLZONE READY: ",
		get_path(),
		" ID: ",
		get_instance_id()
	)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print(
			"KILLZONE HIT PLAYER: ",
			get_path(),
			" ID: ",
			get_instance_id(),
			" PLAYER POS: ",
			body.global_position
		)

		body.die()
