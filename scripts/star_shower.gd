extends CharacterBody2D

var max_health := 4
var health := max_health
var base_damage := 1

@export var spin_speed: float = 2.0

@export var bullet_scene: PackedScene

var player: Node2D = null
enum MovementType {
	VERTICAL,
	HORIZONTAL,
	DIAGONAL
}
@export var movement_type: MovementType = MovementType.VERTICAL
@export var movement_distance: float = 50.0
@export var movement_speed: float = 2.0
var start_position: Vector2
var movement_time: float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	start_position = position

func _physics_process(delta: float) -> void:
	# Spin
	rotation += spin_speed * delta
	# Floating movement
	movement_time += delta * movement_speed
	var offset := sin(movement_time) * movement_distance
	match movement_type:
		MovementType.VERTICAL:
			position = start_position + Vector2(0, offset)
		MovementType.HORIZONTAL:
			position = start_position + Vector2(offset, 0)
		MovementType.DIAGONAL:
			position = start_position + Vector2(-offset, offset)

func take_damage(amount: int) -> void:
	health -= amount
	flash_damage()
	if health <= 0:
		die()

func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)
	await get_tree().create_timer(0.1).timeout
	animated_sprite_2d.modulate = Color.WHITE

func die() -> void:
	queue_free()

func spin_once() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"rotation",
		rotation + TAU,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)




func _on_shoot_timer_timeout() -> void:
	pass # Replace with function body.
	
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		$ShootTimer.start()
		print("PLAYER DETECTED")


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		$ShootTimer.stop()
		print("PLAYER LEFT")
