extends CharacterBody2D
@export var enemy_id: String = ""
var max_health := 3
var health := max_health
var base_damage := 1
@export var star_fragment_reward: int = 3
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
# This version respects walls
#func _physics_process(delta: float) -> void:
	#if is_dying:
		#return
#
	#rotation += spin_speed * delta
#
	#movement_time += delta * movement_speed
	#var wave_velocity := cos(movement_time) * movement_distance * movement_speed
#
	#match movement_type:
		#MovementType.VERTICAL:
			#velocity = Vector2(0, wave_velocity)
#
		#MovementType.HORIZONTAL:
			#velocity = Vector2(wave_velocity, 0)
#
		#MovementType.DIAGONAL:
			#velocity = Vector2(-wave_velocity, wave_velocity)
#
	#move_and_slide()
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

	# Hide normal enemy sprite
	animated_sprite_2d.visible = false

	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)

	# Disable contact damage
	var killzone := get_node_or_null("Killzone")
	if killzone:
		killzone.set_deferred("monitoring", false)
		var kz_collision = killzone.get_node_or_null("CollisionShape2D")
		if kz_collision:
			kz_collision.set_deferred("disabled", true)

	# Stop movement
	velocity = Vector2.ZERO

	# Play death effect
	death_effect.visible = true
	death_effect.play("death")

	# Play death sound
	death_sound.play()

	# Wait for death animation
	await death_effect.animation_finished

	death_effect.visible = false
	set_physics_process(false)


func respawn() -> void:
	if not is_dying:
		return

	is_dying = false
	health = max_health

	position = start_position
	movement_time = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE

	death_effect.visible = false
	death_effect.stop()

	$CollisionShape2D.set_deferred("disabled", false)

	var killzone := get_node_or_null("Killzone")
	if killzone:
		killzone.set_deferred("monitoring", true)
		var kz_collision = killzone.get_node_or_null("CollisionShape2D")
		if kz_collision:
			kz_collision.set_deferred("disabled", false)

	set_physics_process(true)
