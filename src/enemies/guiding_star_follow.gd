extends CharacterBody2D

@export var enemy_id: String = ""

var max_health := 3
var health := max_health
var base_damage := 1
@export var star_fragment_reward: int = 4
@export var spin_speed: float = 2.0
@export var chase_speed: float = 300.0

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
var player: Node2D = null
var is_chasing := false
var is_dying := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_effect: AnimatedSprite2D = $DeathEffect
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound


func _ready() -> void:
	add_to_group("enemies")
	start_position = position

	death_effect.visible = false

	$DetectionArea.area_entered.connect(_on_detection_area_area_entered)
	$DetectionArea.area_exited.connect(_on_detection_area_area_exited)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	# Spin
	rotation += spin_speed * delta

	# Chase player when detected
	if is_chasing and player != null:
		var target_position := player.global_position + Vector2(0, -48)
		var direction := global_position.direction_to(target_position)

		velocity = direction * chase_speed
		move_and_slide()

		return

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
	GameState.add_star_fragments(star_fragment_reward)
	# Stop chasing
	player = null
	is_chasing = false

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


func _on_detection_area_area_entered(area: Area2D) -> void:
	if is_dying:
		return

	if not area.is_in_group("player_detection"):
		return

	player = area.get_parent()
	is_chasing = true


func _on_detection_area_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	if player != area.get_parent():
		return

	# Stop chasing
	player = null
	is_chasing = false

	# Resume floating from the enemy's current position
	start_position = position
	movement_time = 0.0
