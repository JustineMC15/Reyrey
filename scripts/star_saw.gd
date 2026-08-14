extends CharacterBody2D

var max_health := 7
var health := max_health
var base_damage := 2

@export var spin_speed: float = 2.0

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
var is_dying := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_effect: AnimatedSprite2D = $DeathEffect
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound


func _ready() -> void:
	add_to_group("enemies")
	start_position = position
	
	death_effect.visible = false


func _physics_process(delta: float) -> void:
	if is_dying:
		return

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
	if is_dying:
		return

	health -= amount

	# Play hit sound
	hit_sound.play()

	# Flash white
	flash_damage()

	if health <= 0:
		die()


func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)
	await get_tree().create_timer(0.1).timeout

	if not is_dying:
		animated_sprite_2d.modulate = Color.WHITE


func die() -> void:
	if is_dying:
		return

	is_dying = true

	# Hide normal enemy sprite
	animated_sprite_2d.visible = false

	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)

	# Stop movement
	velocity = Vector2.ZERO

	# Play death effect
	death_effect.visible = true
	death_effect.play("death")

	# Play death sound
	death_sound.play()

	# Wait for death animation
	await death_effect.animation_finished

	queue_free()


func spin_once() -> void:
	var tween = create_tween()

	tween.tween_property(
		self,
		"rotation",
		rotation + TAU,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
