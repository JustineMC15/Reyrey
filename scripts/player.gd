extends CharacterBody2D

signal health_changed(current_health, max_health)
signal mp_changed(current_mp, max_mp)

const DOUBLE_JUMP_MP_COST := 2
const DASH_MP_COST := 2
const SPEED := 420.0
const JUMP_VELOCITY := -1200.0
const GRAVITY_RISE := 3429.0
const GRAVITY_FALL := GRAVITY_RISE * 1.5
const SHORT_HOP_CUT := 0.5

var is_slowed := false
var slow_multiplier := 0.5

# How long the player can jump after leaving a platform.
const COYOTE_TIME = 0.13

# How long a jump press is remembered before landing.
const JUMP_BUFFER_TIME = 0.15

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false

var max_health := 5
var health := max_health
var is_dead: bool = false

var max_mp := 3
var mp := max_mp

var invincible := false
const INVINCIBILITY_TIME := 0.5

var sword_damage := 1
var sword_has_hit := false

var fire_damage := 3
var smoke_damage := 1
const DOUBLE_JUMP_VELOCITY := -1000.0
var jumps_used: int = 0

# Dash
const DASH_SPEED := 1600.0
const DASH_DURATION := 0.19
const DASH_COOLDOWN := 0.6

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: float = 1.0
var dash_damage := 3
var dash_hit_enemies: Array[Node] = []
var dash_empowered: bool = false

# Footsteps
@export var footstep_sounds: Array[AudioStream] = []
var last_footstep_frame: int = -1

# Player
@onready var detection_area: Area2D = $DetectionArea
@onready var standing_collision = $CollisionShape2D
@onready var air_collision = $AirCollisionShape2D

# Normal player animation
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Dash animation
@onready var dash_animation: AnimatedSprite2D = $DashAnimation

# Combat
@onready var dash_hitbox: Area2D = $DashHitbox
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var slash_effect = $SlashEffect

# Death
@onready var death_animation: AnimatedSprite2D = $DeathAnimation

# Jump / Double Jump
@onready var jump_effect: AnimatedSprite2D = $JumpEffect
@onready var double_jump_fire: Node2D = $DoubleJumpFire
@onready var fire_sprite: AnimatedSprite2D = $DoubleJumpFire/AnimatedSprite2D
@onready var fire_sound: AudioStreamPlayer2D = $DoubleJumpFire/AudioStreamPlayer2D
@onready var fire_hitbox: Area2D = $DoubleJumpFire/Area2D

# Audio
@onready var sword_sound: AudioStreamPlayer2D = $SwordSound
@onready var damage_sound: AudioStreamPlayer2D = $DamageSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var footstep_sound: AudioStreamPlayer2D = $FootstepSound

# Dash Effects
@onready var dash_effect: Node2D = $DashEffect
@onready var dash_sprite: AnimatedSprite2D = $DashEffect/HolyEffect
@onready var dash_effect_always: AnimatedSprite2D = $DashEffect/WindEffect
@onready var dash_sound: AudioStreamPlayer2D = $DashEffect/AudioStreamPlayer2D

var input_locked: bool = false


func lock_input() -> void:
	input_locked = true
	velocity = Vector2.ZERO


func unlock_input() -> void:
	input_locked = false


func cancel_attack() -> void:
	is_attacking = false
	sword_has_hit = false
	slash_effect.stop()
	slash_effect.visible = false
	sword_hitbox.monitoring = false


func play_footstep() -> void:
	if footstep_sounds.is_empty():
		return

	footstep_sound.stream = footstep_sounds.pick_random()
	footstep_sound.play()


func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == "attack":
		cancel_attack()


func _on_jump_effect_finished() -> void:
	if jump_effect.animation == "jumpwind":
		jump_effect.visible = false


func sword_attack() -> void:
	sword_hitbox.monitoring = true

	await get_tree().physics_frame

	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(sword_damage)

	sword_hitbox.monitoring = false


func fire_attack(damage: int) -> void:
	await get_tree().physics_frame

	for body in fire_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(damage)


func dash_attack() -> void:
	# An unpowered dash does not deal damage.
	if not dash_empowered:
		return

	for body in dash_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body in dash_hit_enemies:
			body.take_damage(dash_damage)
			dash_hit_enemies.append(body)


func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)

	await get_tree().create_timer(0.1).timeout

	if not is_dead:
		animated_sprite_2d.modulate = Color.WHITE


func take_damage(amount: int) -> void:
	if invincible or is_dead:
		return

	invincible = true
	damage_sound.play()

	health -= amount
	health_changed.emit(health, max_health)

	flash_damage()

	if health <= 0:
		die()
		return

	await get_tree().create_timer(INVINCIBILITY_TIME).timeout

	if not is_dead:
		invincible = false


func die() -> void:
	if is_dead:
		return

	is_dead = true
	invincible = true
	is_dashing = false
	velocity = Vector2.ZERO

	# Disable player interactions
	detection_area.monitoring = false
	sword_hitbox.monitoring = false
	fire_hitbox.monitoring = false
	dash_hitbox.monitoring = false

	# Disable collisions
	standing_collision.set_deferred("disabled", true)
	air_collision.set_deferred("disabled", true)

	# Stop player effects
	cancel_attack()

	double_jump_fire.visible = false
	dash_effect.visible = false
	dash_animation.visible = false

	# Hide normal player sprite
	animated_sprite_2d.visible = false

	# Show death animation
	death_animation.visible = true
	death_animation.flip_h = animated_sprite_2d.flip_h
	death_animation.play("death")

	# Play death sound
	death_sound.pitch_scale = 1.2
	death_sound.play()

	# Wait for the death sound to finish
	await death_sound.finished

	GameState.call_deferred("respawn_player")
	restore_full_mp()


func _on_fire_animation_finished() -> void:
	double_jump_fire.visible = false
	fire_hitbox.monitoring = false


func _ready() -> void:
	add_to_group("player")
	$DetectionArea.add_to_group("player_detection")

	max_mp = GameState.max_mp
	mp = GameState.current_mp

	floor_snap_length = 4.0

	# Hide effects
	slash_effect.visible = false
	sword_hitbox.monitoring = false

	double_jump_fire.visible = false
	fire_hitbox.monitoring = false

	dash_effect.visible = false
	dash_hitbox.monitoring = false

	# Hide dash animation until actually dashing
	dash_animation.visible = false

	death_animation.visible = false

	# Connect animation signals
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	fire_sprite.animation_finished.connect(_on_fire_animation_finished)
	jump_effect.animation_finished.connect(_on_jump_effect_finished)

	mp_changed.emit(mp, max_mp)


func _physics_process(delta: float) -> void:
	# Stop ALL player processing while dead.
	if is_dead:
		return

	# Dash cooldown
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# ============================================================
	# DASH START
	# ============================================================

	if Input.is_action_just_pressed("dash") \
	and GameState.has_ability("dash") \
	and dash_cooldown_timer <= 0.0 \
	and not is_dashing:

		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

		# Cancel any ongoing attack.
		cancel_attack()

		# Determine dash direction from current facing direction.
		dash_direction = -1.0 if animated_sprite_2d.flip_h else 1.0

		# Check if the player has enough MP for an empowered dash.
		dash_empowered = mp >= DASH_MP_COST

		if dash_empowered:
			# Spend 2 MP.
			mp -= DASH_MP_COST
			mp_changed.emit(mp, max_mp)
			GameState.current_mp = mp

			# Empowered dash gets i-frames and damage.
			invincible = true
			dash_hitbox.monitoring = true

			# Allow every enemy to be hit once during this dash.
			dash_hit_enemies.clear()

		else:
			# Not enough MP:
			# normal dash with no damage and no i-frames.
			invincible = false
			dash_hitbox.monitoring = false

		# --------------------------------------------------------
		# NEW DASH ANIMATION
		# --------------------------------------------------------

		# Hide the normal player sprite.
		animated_sprite_2d.visible = false

		# Show the dedicated dash animation.
		dash_animation.visible = true

		# Match the player's facing direction.
		dash_animation.flip_h = animated_sprite_2d.flip_h

		dash_animation.play("dash")

		# --------------------------------------------------------
		# DASH EFFECTS
		# --------------------------------------------------------

		dash_effect.visible = true
		dash_effect.scale.x = -1.0 if animated_sprite_2d.flip_h else 1.0

		# Wind effect always plays.
		dash_effect_always.visible = true
		dash_effect_always.play("wind")

		# Holy effect only plays on empowered dash.
		if dash_empowered:
			dash_sprite.visible = true
			dash_sprite.play("dash")
		else:
			dash_sprite.visible = false

		dash_sound.play()

	# ============================================================
	# DURING DASH
	# ============================================================

	if is_dashing:
		dash_timer -= delta

		velocity = Vector2(dash_direction * DASH_SPEED, 0)

		move_and_slide()

		dash_attack()

		if dash_timer <= 0.0:
			is_dashing = false

			# Always remove dash i-frames when the dash ends.
			invincible = false
			dash_hitbox.monitoring = false
			dash_empowered = false

			# Stop dash animation.
			dash_animation.stop()
			dash_animation.visible = false

			# Show normal player sprite again.
			animated_sprite_2d.visible = true

			# Stop dash effects.
			dash_sprite.stop()
			dash_effect_always.stop()

			dash_sprite.visible = false
			dash_effect_always.visible = false
			dash_effect.visible = false

		return

	# ============================================================
	# INPUT LOCKED
	# ============================================================

	if input_locked:
		velocity.x = move_toward(velocity.x, 0, SPEED)

		if not is_on_floor():
			velocity.y += (
				GRAVITY_FALL if velocity.y > 0 else GRAVITY_RISE
			) * delta

		move_and_slide()

		if not is_attacking:
			animated_sprite_2d.play(
				"idle" if is_on_floor() else "fall"
			)

		return

	# ============================================================
	# COYOTE TIMER
	# ============================================================

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jumps_used = 0
	else:
		coyote_timer -= delta

	# ============================================================
	# JUMP BUFFER
	# ============================================================

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# ============================================================
	# SHORT HOP
	# ============================================================

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= SHORT_HOP_CUT

	# ============================================================
	# GROUND / COYOTE JUMP
	# ============================================================

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY

		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jumps_used = 1

		jump_sound.play()

		jump_effect.visible = true
		jump_effect.play("jumpwind")

	# ============================================================
	# AIR JUMP / DOUBLE JUMP
	# ============================================================

	elif jump_buffer_timer > 0.0 \
	and jumps_used < 2 \
	and not is_on_floor() \
	and GameState.has_ability("double_jump"):

		velocity.y = DOUBLE_JUMP_VELOCITY

		jump_buffer_timer = 0.0
		jumps_used = 2

		jump_effect.visible = true
		jump_effect.play("jumpwind")

		if mp >= DOUBLE_JUMP_MP_COST:
			# 2+ MP: enhanced double jump with fire.
			mp -= DOUBLE_JUMP_MP_COST

			mp_changed.emit(mp, max_mp)
			GameState.current_mp = mp

			double_jump_fire.visible = true
			double_jump_fire.modulate = Color.WHITE

			fire_sprite.stop()
			fire_sprite.frame = 0
			fire_sprite.play("fire")

			fire_sound.play()

			fire_hitbox.monitoring = true
			fire_attack(fire_damage)

		else:
			# 0 or 1 MP: weaker smoke fallback.
			double_jump_fire.visible = true
			double_jump_fire.modulate = Color(
				0.405,
				0.405,
				0.405,
				0.3
			)

			fire_sprite.stop()
			fire_sprite.frame = 0
			fire_sprite.play("fire")

			fire_sound.play()

			fire_hitbox.monitoring = true
			fire_attack(smoke_damage)

	# ============================================================
	# GRAVITY
	# ============================================================

	if not is_on_floor():
		if coyote_timer > 0.0:
			velocity.y = 0.0
		else:
			velocity.y += (
				GRAVITY_FALL if velocity.y > 0 else GRAVITY_RISE
			) * delta

	# ============================================================
	# INPUT DIRECTION
	# ============================================================

	var direction := Input.get_axis("move_left", "move_right")

	# Flip sprite
	if direction > 0:
		animated_sprite_2d.flip_h = false
		sword_hitbox.scale.x = 1

	elif direction < 0:
		animated_sprite_2d.flip_h = true
		sword_hitbox.scale.x = -1

	# ============================================================
	# MOVEMENT
	# ============================================================

	var current_speed := SPEED

	if is_slowed:
		current_speed *= slow_multiplier

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(
			velocity.x,
			0,
			current_speed
		)

	# ============================================================
	# COLLISION SWITCHING
	# ============================================================

	standing_collision.disabled = not is_on_floor()
	air_collision.disabled = is_on_floor()

	move_and_slide()

	# ============================================================
	# ATTACK
	# ============================================================

	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		sword_has_hit = false

		animated_sprite_2d.play("attack")

		slash_effect.visible = true
		slash_effect.flip_h = animated_sprite_2d.flip_h
		slash_effect.play("slash")

		sword_sound.play()

	# ============================================================
	# SWORD HIT DETECTION
	# ============================================================

	if is_attacking and animated_sprite_2d.animation == "attack":
		if animated_sprite_2d.frame >= 1 \
		and animated_sprite_2d.frame <= 5 \
		and not sword_has_hit:

			sword_has_hit = true
			sword_attack()

	# ============================================================
	# ANIMATIONS
	# ============================================================

	if not is_attacking:

		if is_on_floor():

			if direction == 0:
				animated_sprite_2d.play("idle")
				last_footstep_frame = -1

			else:
				animated_sprite_2d.play("run")

				# Footstep frames
				if animated_sprite_2d.frame in [5, 13, 22]:
					if last_footstep_frame != animated_sprite_2d.frame:
						last_footstep_frame = animated_sprite_2d.frame
						play_footstep()

		elif coyote_timer > 0.0:

			if direction == 0:
				animated_sprite_2d.play("idle")
				last_footstep_frame = -1

			else:
				animated_sprite_2d.play("run")

		else:

			if velocity.y < 0:
				animated_sprite_2d.play("jump")

			else:
				if animated_sprite_2d.animation != "fall_loop":
					animated_sprite_2d.play("fall")

				if animated_sprite_2d.animation == "fall" \
				and animated_sprite_2d.frame >= 4:
					animated_sprite_2d.play("fall_loop")


func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func restore_full_mp() -> void:
	mp = max_mp
	mp_changed.emit(mp, max_mp)
	GameState.current_mp = mp


func increase_max_mp(amount: int) -> void:
	print("MP BEFORE: ", max_mp)
	print("GAIN: ", amount)

	max_mp += amount

	print("MP AFTER: ", max_mp)

	mp_changed.emit(mp, max_mp)


func set_slowed(slowed: bool) -> void:
	is_slowed = slowed
