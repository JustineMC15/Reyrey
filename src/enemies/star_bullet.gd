extends Area2D

@export var speed := 500.0
@export var max_distance := 1200.0
@export var damage := 1
@export var spin_speed := 5.0

var direction := Vector2.ZERO
var start_position := Vector2.ZERO
var has_hit := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_sound: AudioStreamPlayer2D = $HitSound


func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	global_position += direction * speed * delta
	rotation += spin_speed * delta

	if global_position.distance_to(start_position) >= max_distance:
		_start_poof()


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.is_in_group("player"):
		body.take_damage(damage)

	_start_poof(true)


func _start_poof(play_sound: bool = false) -> void:
	if has_hit:
		return

	has_hit = true

	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	if play_sound:
		hit_sound.play()

	animated_sprite.visible = false

	$HitEffect.visible = true
	$HitEffect.play("poof")

	await $HitEffect.animation_finished

	queue_free()
