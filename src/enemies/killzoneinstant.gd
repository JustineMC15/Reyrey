extends Area2D


@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	print(
		"KILLZONE READY: ",
		get_path(),
		" ID: ",
		get_instance_id(),
		" AREA GLOBAL: ",
		global_position,
		" SHAPE GLOBAL: ",
		collision_shape.global_position
	)

	if collision_shape.shape is RectangleShape2D:
		print(
			"SHAPE SIZE: ",
			collision_shape.shape.size
		)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			print(
				"OVERLAP CONFIRMED",
				" KILLZONE SHAPE: ",
				collision_shape.global_position,
				" PLAYER: ",
				body.global_position
			)

			if not body.is_dead and not body.invincible:
				body.die()
