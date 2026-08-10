extends CharacterBody2D
signal health_changed(current_health, max_health)
const SPEED := 400.0
const JUMP_VELOCITY := -1200.0
const GRAVITY_RISE := 3429.0
const GRAVITY_FALL := GRAVITY_RISE * 1.5  # snappier fall, common feel trick
const SHORT_HOP_CUT := 0.5               # variable jump height on early release

# How long the player can jump after leaving a platform.
const COYOTE_TIME = 0.15

# How long a jump press is remembered before landing.
const JUMP_BUFFER_TIME = 0.15

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var max_health := 5
var health := max_health
var invincible := false
const INVINCIBILITY_TIME := 0.5
var sword_damage := 1
var sword_has_hit := false
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var slash_effect = $SlashEffect
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == "attack":
		is_attacking = false
		slash_effect.stop()
		slash_effect.visible = false
func sword_attack() -> void:
	sword_hitbox.monitoring = true
	await get_tree().physics_frame
	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(sword_damage)
	sword_hitbox.monitoring = false
func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)
	await get_tree().create_timer(0.1).timeout
	animated_sprite_2d.modulate = Color.WHITE
func take_damage(amount: int) -> void:
	if invincible:
		return
	invincible = true
	health -= amount
	health_changed.emit(health, max_health)
	print("Player HP: ", health)
	flash_damage()
	if health <= 0:
		die()
		return
	await get_tree().create_timer(INVINCIBILITY_TIME).timeout
	invincible = false
func die() -> void:
	get_tree().reload_current_scene.call_deferred()
func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 9.0
	slash_effect.visible = false
	sword_hitbox.monitoring = false
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
func _physics_process(delta: float) -> void:
	# Coyote Timer
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# Jump Buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity.y += (GRAVITY_FALL if velocity.y > 0 else GRAVITY_RISE) * delta
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= SHORT_HOP_CUT

	# Handle jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY

		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Input direction
	var direction := Input.get_axis("move_left", "move_right")

	# Flip sprite
	if direction > 0:
		animated_sprite_2d.flip_h = false
		sword_hitbox.scale.x = 1
	elif direction < 0:
		animated_sprite_2d.flip_h = true
		sword_hitbox.scale.x = -1
	# Movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	# Move
	move_and_slide()
	# Animations
	# Attack
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		sword_has_hit = false
		animated_sprite_2d.play("attack")
		slash_effect.visible = true
		slash_effect.flip_h = animated_sprite_2d.flip_h
		slash_effect.play("slash")
	if is_attacking and animated_sprite_2d.animation == "attack":
		if animated_sprite_2d.frame == 3 and not sword_has_hit:
			sword_has_hit = true
			sword_attack()
	if not is_attacking:
		if is_on_floor():
			if direction == 0:
				animated_sprite_2d.play("idle")
			else:
				animated_sprite_2d.play("run")
		else:
			if velocity.y < 0:
				animated_sprite_2d.play("jump")
			else:
				if animated_sprite_2d.animation != "fall_loop":
					animated_sprite_2d.play("fall")
				if animated_sprite_2d.animation == "fall" and animated_sprite_2d.frame >= 4:
					animated_sprite_2d.play("fall_loop")
