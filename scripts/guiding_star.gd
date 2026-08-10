extends CharacterBody2D

var max_health := 3
var health := max_health
var base_damage := 1

@export var spin_speed: float = 2.0


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	rotation += spin_speed * delta


func take_damage(amount: int) -> void:
	health -= amount

	if health <= 0:
		die()


func die() -> void:
	queue_free()


func spin_once() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"rotation",
		rotation + TAU,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
