extends CharacterBody2D

@export var enemy_id: String = ""

var max_health := 7
var health := max_health
var base_damage := 2

@export var spin_speed: float = 2.0

enum MovementPattern {
	CIRCLE,
	SQUARE
}

@export var movement_pattern: MovementPattern = MovementPattern.CIRCLE
@export var movement_radius: float = 100.0
@export var movement_speed: float = 100.0


var start_position: Vector2
var movement_time: float = 0.0
var is_dying := false

var square_side: int = 0
var square_progress: float = 0.0
var square_initialized := false

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

	rotation += spin_speed * delta


	match movement_pattern:
		MovementPattern.CIRCLE:
			move_circle(delta)

		MovementPattern.SQUARE:
			move_square(delta)

func move_circle(delta: float) -> void:
	movement_time += movement_speed * delta

	var offset := Vector2(
		cos(movement_time),
		sin(movement_time)
	) * movement_radius

	position = start_position + offset

func move_square(delta: float) -> void:
	var side_length := movement_radius * 2.0
	var half := movement_radius

	# Initialize at the starting position
	if not square_initialized:
		square_initialized = true
		square_side = 0
		square_progress = 0.0

		# Start at the top-left corner.
		# This is calculated once so movement begins consistently.
		position = start_position + Vector2(-half, -half)

	square_progress += movement_speed * delta

	# Move to the next side
	if square_progress >= side_length:
		square_progress -= side_length
		square_side = (square_side + 1) % 4

	match square_side:

		# Top → Right
		0:
			position = start_position + Vector2(
				-half + square_progress,
				-half
			)

		# Right → Bottom
		1:
			position = start_position + Vector2(
				half,
				-half + square_progress
			)

		# Bottom → Left
		2:
			position = start_position + Vector2(
				half - square_progress,
				half
			)

		# Left → Top
		3:
			position = start_position + Vector2(
				-half,
				half - square_progress
			)

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

	# Disable contact damage
	$ContactDamage/CollisionShape2D.set_deferred("disabled", true)

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
