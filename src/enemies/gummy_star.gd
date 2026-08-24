extends CharacterBody2D

@export var enemy_id: String = ""

var max_health := 8
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


# =========================
# ATTACK SETTINGS
# =========================

@export var attack_cooldown: float = 2.0
@export var charge_time: float = 0.6
@export var field_duration: float = 2.0

var can_attack := true
var is_attacking := false


# =========================
# VARIABLES
# =========================

var start_position: Vector2
var movement_time: float = 0.0
var is_dying := false


# =========================
# NODES
# =========================

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var death_effect: AnimatedSprite2D = $DeathEffect
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

@onready var attack_area: Area2D = $AttackArea
@onready var attack_effect: AnimatedSprite2D = $AttackEffect/AnimatedSprite2D
@onready var slow_field: Area2D = $AttackEffect/SlowField
@onready var goo_sound: AudioStreamPlayer2D = $AttackEffect/Goo


func _ready() -> void:
	add_to_group("enemies")
	
	start_position = position

	death_effect.visible = false
	attack_effect.visible = false

	# Slow field starts inactive
	slow_field.monitoring = false
	slow_field.body_entered.connect(_on_slow_field_body_entered)
	slow_field.body_exited.connect(_on_slow_field_body_exited)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	# =========================
	# SPIN
	# =========================

	rotation += spin_speed * delta
	attack_effect.global_rotation = deg_to_rad(90)

	# =========================
	# FLOATING MOVEMENT
	# =========================

	movement_time += delta * movement_speed
	var offset := sin(movement_time) * movement_distance

	match movement_type:
		MovementType.VERTICAL:
			position = start_position + Vector2(0, offset)

		MovementType.HORIZONTAL:
			position = start_position + Vector2(offset, 0)

		MovementType.DIAGONAL:
			position = start_position + Vector2(-offset, offset)


	# =========================
	# CHECK FOR PLAYER
	# =========================

	if can_attack and not is_attacking:
		check_for_player()


# ============================================================
# ATTACK
# ============================================================

func check_for_player() -> void:
	var bodies := attack_area.get_overlapping_bodies()

	for body in bodies:
		if body.is_in_group("player"):
			attack()
			return


func attack() -> void:
	if is_attacking or not can_attack or is_dying:
		return

	is_attacking = true
	can_attack = false


	# --------------------------------
	# CHARGE
	# --------------------------------

	attack_effect.visible = true
	attack_effect.play("charge")

	# Glow white
	var glow_tween := create_tween()

	glow_tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color(5.0, 5.0, 5.0, 1.0),
		charge_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


	# Wait for charge
	await get_tree().create_timer(charge_time).timeout

	if is_dying:
		return


	# --------------------------------
	# ACTIVATE SLOW FIELD
	# --------------------------------

	attack_effect.play("explosion")

	goo_sound.play()

	slow_field.monitoring = true


	# Keep the slow field active
	await get_tree().create_timer(field_duration).timeout

	if is_dying:
		return


	# --------------------------------
	# DEACTIVATE SLOW FIELD
	# --------------------------------

	slow_field.monitoring = false


	# --------------------------------
	# REMOVE GLOW
	# --------------------------------

	var fade_tween := create_tween()

	fade_tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color.WHITE,
		0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await fade_tween.finished


	attack_effect.visible = false

	is_attacking = false


	# --------------------------------
	# COOLDOWN
	# --------------------------------

	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dying:
		can_attack = true


# ============================================================
# DAMAGE
# ============================================================

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

	if not is_dying and not is_attacking:
		animated_sprite_2d.modulate = Color.WHITE


# ============================================================
# DEATH
# ============================================================

func die() -> void:
	if is_dying:
		return

	is_dying = true
	GameState.add_star_fragments(star_fragment_reward)
	# Disable slow field
	slow_field.set_deferred("monitoring", false)

	# Hide normal enemy sprite
	animated_sprite_2d.visible = false

	# Hide attack effect
	attack_effect.visible = false

	# Disable enemy collision
	$CollisionShape2D.set_deferred("disabled", true)

	# Disable attack detection
	$AttackArea/CollisionShape2D.set_deferred("disabled", true)

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
	is_attacking = false
	can_attack = true

	position = start_position
	movement_time = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE

	death_effect.visible = false
	death_effect.stop()

	$CollisionShape2D.set_deferred("disabled", false)
	$AttackArea/CollisionShape2D.set_deferred("disabled", false)

	attack_effect.visible = false
	slow_field.set_deferred("monitoring", false)

	set_physics_process(true)
func _on_slow_field_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_slowed"):
			body.set_slowed(true)


func _on_slow_field_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_slowed"):
			body.set_slowed(false)
