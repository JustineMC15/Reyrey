extends CharacterBody2D

signal health_changed(current_health, max_health)
signal mp_changed(current_mp, max_mp)
signal stamina_changed(current_stamina, max_stamina)
const DOUBLE_JUMP_MP_COST := 2
const DASH_MP_COST := 2
const SPEED := 420.0
const JUMP_VELOCITY := -1200.0
const GRAVITY_RISE := 3429.0
const GRAVITY_FALL := GRAVITY_RISE * 1.5
const SHORT_HOP_CUT := 0.5
const GRAVITY_GLIDE := GRAVITY_FALL * 0.18
const GLIDE_MAX_FALL_SPEED := 260.0
const WALL_SLIDE_GRAVITY := GRAVITY_FALL * 0.12
const WALL_SLIDE_MAX_SPEED := 220.0
const WALL_JUMP_HORIZONTAL_SPEED := 900.0
const WALL_JUMP_VERTICAL_VELOCITY := -1100.0
const WALL_JUMP_LOCK_TIME := 0.18
const STAMINA_REGEN_RATE := 40.0
const STAMINA_REGEN_DELAY := 0.4
const WALL_CLING_STAMINA_DRAIN_RATE := 30.0
const MIN_STAMINA_TO_WALL_CLING := 5.0
const DASH_CHAIN_STAMINA_COST := 25.0

var is_slowed := false
var slow_multiplier := 0.5

# How long the player can jump after leaving a platform.
const COYOTE_TIME = 0.13

# How long a jump press is remembered before landing.
const JUMP_BUFFER_TIME = 0.4

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
const DASH_CHAIN_COOLDOWN := 0.15
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: float = 1.0
var dash_damage := 3
var dash_hit_enemies: Array[Node] = []
var dash_empowered: bool = false

# Ground Slam
const GROUND_SLAM_FALL_SPEED := 3000.0
const GROUND_SLAM_ACCEL := 10000.0
const GROUND_SLAM_DAMAGE := 4
const GROUND_SLAM_IMPACT_RADIUS := 140.0
const GROUND_SLAM_HITSTOP_DURATION := 0.06
const GROUND_SLAM_SHAKE_STRENGTH := 16.0
const GROUND_SLAM_SHAKE_DURATION := 0.25

var is_ground_slamming: bool = false
var camera_base_offset: Vector2

# Glide
var is_gliding: bool = false
var was_gliding: bool = false

# Wall Cling
var is_wall_clinging: bool = false
var wall_jump_lock_timer: float = 0.0
var wall_normal_x: float = 0.0

# Stamina
var max_stamina := 100.0
var stamina := max_stamina
var stamina_regen_timer := 0.0

# Footsteps
@export var footstep_sounds: Array[AudioStream] = []
var last_footstep_frame: int = -1

# PLAYER

@onready var detection_area: Area2D = $DetectionArea
@onready var standing_collision = $CollisionShape2D
@onready var air_collision = $AirCollisionShape2D

# Normal player animation
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Dash animation
@onready var dash_animation: AnimatedSprite2D = $DashAnimation

# Glide animation
@onready var glide_animation: AnimatedSprite2D = $GlideAnimation

# Wall cling animation
@onready var wall_animation: AnimatedSprite2D = $WallAnimation

# COMBAT

@onready var dash_hitbox: Area2D = $DashHitbox
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var slash_effect = $SlashEffect

# DEATH

@onready var death_animation: AnimatedSprite2D = $DeathAnimation

# JUMP / DOUBLE JUMP

@onready var jump_effect: AnimatedSprite2D = $JumpEffect
@onready var double_jump_fire: Node2D = $DoubleJumpFire
@onready var fire_sprite: AnimatedSprite2D = $DoubleJumpFire/AnimatedSprite2D
@onready var fire_sound: AudioStreamPlayer2D = $DoubleJumpFire/AudioStreamPlayer2D
@onready var fire_hitbox: Area2D = $DoubleJumpFire/Area2D

# AUDIO

@onready var sword_sound: AudioStreamPlayer2D = $SwordSound
@onready var damage_sound: AudioStreamPlayer2D = $DamageSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var footstep_sound: AudioStreamPlayer2D = $FootstepSound

# DASH EFFECTS

@onready var dash_effect: Node2D = $DashEffect
@onready var dash_sprite: AnimatedSprite2D = $DashEffect/HolyEffect
@onready var dash_effect_always: AnimatedSprite2D = $DashEffect/WindEffect
@onready var dash_sound: AudioStreamPlayer2D = $DashEffect/AudioStreamPlayer2D

# GROUND SLAM

@onready var camera: Camera2D = $Camera2D
@onready var ground_slam_effect: Node2D = $GroundSlamEffect
@onready var ground_slam_sprite: AnimatedSprite2D = $GroundSlamEffect/AnimatedSprite2D
@onready var ground_slam_sound: AudioStreamPlayer2D = $GroundSlamEffect/AudioStreamPlayer2D

var input_locked: bool = false


# INPUT LOCK

func lock_input() -> void:
	input_locked = true
	velocity = Vector2.ZERO


func unlock_input() -> void:
	input_locked = false


# ATTACK

func cancel_attack() -> void:
	is_attacking = false
	sword_has_hit = false
	slash_effect.stop()
	slash_effect.visible = false
	sword_hitbox.monitoring = false


# FOOTSTEPS

func play_footstep() -> void:
	if footstep_sounds.is_empty():
		return

	footstep_sound.stream = footstep_sounds.pick_random()
	footstep_sound.play()


# ANIMATION SIGNALS

func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == "attack":
		cancel_attack()


func _on_jump_effect_finished() -> void:
	if jump_effect.animation == "jumpwind":
		jump_effect.visible = false


# SWORD ATTACK

func sword_attack() -> void:
	sword_hitbox.monitoring = true

	await get_tree().physics_frame

	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(sword_damage)

	sword_hitbox.monitoring = false


# FIRE ATTACK

func fire_attack(damage: int) -> void:
	await get_tree().physics_frame

	for body in fire_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(damage)


# DASH ATTACK

func dash_attack() -> void:
	# An unpowered dash does not deal damage.
	if not dash_empowered:
		return

	for body in dash_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body in dash_hit_enemies:
			body.take_damage(dash_damage)
			dash_hit_enemies.append(body)


# GROUND SLAM

func ground_slam_impact() -> void:
	is_ground_slamming = false
	velocity = Vector2.ZERO

	deal_ground_slam_damage()

	ground_slam_effect.visible = true
	ground_slam_sprite.stop()
	ground_slam_sprite.frame = 0
	ground_slam_sprite.play("impact")

	ground_slam_sound.play()

	_ground_slam_hitstop()

	_camera_shake(
		GROUND_SLAM_SHAKE_STRENGTH,
		GROUND_SLAM_SHAKE_DURATION
	)


func deal_ground_slam_damage() -> void:
	for body in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(body):
			continue

		if global_position.distance_to(body.global_position) <= GROUND_SLAM_IMPACT_RADIUS:
			if body.has_method("take_damage"):
				body.take_damage(GROUND_SLAM_DAMAGE)


func _ground_slam_hitstop() -> void:
	Engine.time_scale = 0.05

	await get_tree().create_timer(
		GROUND_SLAM_HITSTOP_DURATION,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0


func _camera_shake(strength: float, duration: float) -> void:
	if not camera:
		return

	var shake_tween := create_tween()
	var steps := 6

	for i in steps:
		var random_offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)

		shake_tween.tween_property(
			camera,
			"offset",
			camera_base_offset + random_offset,
			duration / float(steps)
		)

	shake_tween.tween_property(
		camera,
		"offset",
		camera_base_offset,
		0.05
	)


func _on_ground_slam_effect_finished() -> void:
	if ground_slam_sprite.animation == "impact":
		ground_slam_effect.visible = false


# DAMAGE

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


# DEATH

func die() -> void:
	if is_dead:
		return

	is_dead = true
	invincible = true
	is_dashing = false
	is_gliding = false
	was_gliding = false
	is_wall_clinging = false
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
	glide_animation.visible = false
	wall_animation.visible = false

	# Hide normal player sprite
	animated_sprite_2d.visible = false

	# Show death animation
	death_animation.visible = true
	death_animation.flip_h = animated_sprite_2d.flip_h
	death_animation.play("death")

	# Play death sound
	death_sound.pitch_scale = 1.2
	death_sound.play()

	# Wait for death sound to finish
	await death_sound.finished

	GameState.call_deferred("respawn_player")
	restore_full_mp()
	restore_full_stamina()


# FIRE ANIMATION

func _on_fire_animation_finished() -> void:
	double_jump_fire.visible = false
	fire_hitbox.monitoring = false


# READY

func _ready() -> void:
	add_to_group("player")
	$DetectionArea.add_to_group("player_detection")

	max_mp = GameState.max_mp
	mp = GameState.current_mp

	floor_snap_length = 4.0

	# GROUND SLAM

	camera_base_offset = camera.offset

	ground_slam_effect.visible = false

	ground_slam_sprite.animation_finished.connect(
		_on_ground_slam_effect_finished
	)

	# HIDE EFFECTS

	slash_effect.visible = false
	sword_hitbox.monitoring = false

	double_jump_fire.visible = false
	fire_hitbox.monitoring = false

	dash_effect.visible = false
	dash_hitbox.monitoring = false

	# Hide dash animation until actually dashing
	dash_animation.visible = false

	# Hide glide animation until actually gliding
	glide_animation.visible = false

	# Hide wall animation until actually wall clinging
	wall_animation.visible = false

	# Hide death animation
	death_animation.visible = false

	# CONNECT ANIMATION SIGNALS

	animated_sprite_2d.animation_finished.connect(
		_on_animation_finished
	)

	fire_sprite.animation_finished.connect(
		_on_fire_animation_finished
	)

	jump_effect.animation_finished.connect(
		_on_jump_effect_finished
	)

	mp_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)

# PHYSICS PROCESS

func _physics_process(delta: float) -> void:

	# STOP ALL PLAYER PROCESSING WHILE DEAD

	if is_dead:
		return
	# STAMINA REGEN
	_process_stamina_regen(delta)
	# DASH COOLDOWN

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# DASH START

	if Input.is_action_just_pressed("dash") \
	and GameState.has_ability("dash") \
	and dash_cooldown_timer <= 0.0 \
	and not is_dashing:

		var dash_chained := GameState.has_ability("dash_chain") \
			and spend_stamina(DASH_CHAIN_STAMINA_COST)

		is_dashing = true
		is_gliding = false
		was_gliding = false
		is_wall_clinging = false

		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_CHAIN_COOLDOWN if dash_chained else DASH_COOLDOWN

		# Cancel ongoing attack
		cancel_attack()

		# Hide glide animation
		glide_animation.visible = false

		# Hide wall animation
		wall_animation.visible = false

		# Show normal sprite temporarily
		animated_sprite_2d.visible = true

		# Determine dash direction from current facing direction
		dash_direction = -1.0 if animated_sprite_2d.flip_h else 1.0

		# Check if player has enough MP for empowered dash
		dash_empowered = mp >= DASH_MP_COST

		if dash_empowered:
			# Spend 2 MP
			mp -= DASH_MP_COST

			mp_changed.emit(mp, max_mp)
			GameState.current_mp = mp

			# Empowered dash gets i-frames and damage
			invincible = true
			dash_hitbox.monitoring = true

			# Allow every enemy to be hit once during this dash
			dash_hit_enemies.clear()

		else:
			# Normal dash:
			# no damage
			# no i-frames
			invincible = false
			dash_hitbox.monitoring = false

		# DASH ANIMATION

		# Hide normal player sprite
		animated_sprite_2d.visible = false

		# Show dedicated dash animation
		dash_animation.visible = true

		# Match player's facing direction
		dash_animation.flip_h = animated_sprite_2d.flip_h

		dash_animation.play("dash")

		# DASH EFFECTS

		dash_effect.visible = true

		dash_effect.scale.x = (
			-1.0 if animated_sprite_2d.flip_h else 1.0
		)

		# Wind effect always plays
		dash_effect_always.visible = true
		dash_effect_always.play("wind")

		# Holy effect only plays on empowered dash
		if dash_empowered:
			dash_sprite.visible = true
			dash_sprite.play("dash")
		else:
			dash_sprite.visible = false

		dash_sound.play()

	# GROUND SLAM START

	if Input.is_action_just_pressed("ground_slam") \
	and GameState.has_ability("ground_slam") \
	and not is_on_floor() \
	and not is_dashing \
	and not is_ground_slamming:

		is_ground_slamming = true
		is_gliding = false
		was_gliding = false
		is_wall_clinging = false

		cancel_attack()

		# Hide glide animation
		glide_animation.visible = false

		# Hide wall animation
		wall_animation.visible = false

		animated_sprite_2d.visible = true

		velocity.y = 0.0

		animated_sprite_2d.play("fall_loop")

	# DASH PROCESS

	if is_dashing:
		dash_timer -= delta

		velocity = Vector2(
			dash_direction * DASH_SPEED,
			0
		)

		move_and_slide()

		dash_attack()

		if dash_timer <= 0.0:
			is_dashing = false

			# Always remove dash i-frames
			invincible = false
			dash_hitbox.monitoring = false
			dash_empowered = false

			# Stop dash animation
			dash_animation.stop()
			dash_animation.visible = false

			# Show normal player sprite again
			animated_sprite_2d.visible = true

			# Stop dash effects
			dash_sprite.stop()
			dash_effect_always.stop()

			dash_sprite.visible = false
			dash_effect_always.visible = false
			dash_effect.visible = false

		return

	# GROUND SLAM PROCESS

	if is_ground_slamming:
		velocity.y = move_toward(
			velocity.y,
			GROUND_SLAM_FALL_SPEED,
			GROUND_SLAM_ACCEL * delta
		)

		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)

		move_and_slide()

		if is_on_floor():
			ground_slam_impact()

		return

	# INPUT LOCK

	if input_locked:
		velocity.x = move_toward(
			velocity.x,
			0,
			SPEED
		)

		if not is_on_floor():
			velocity.y += (
				GRAVITY_FALL
				if velocity.y > 0
				else GRAVITY_RISE
			) * delta

		move_and_slide()

		if not is_attacking:
			animated_sprite_2d.visible = true
			glide_animation.visible = false
			wall_animation.visible = false

			animated_sprite_2d.play(
				"idle" if is_on_floor() else "fall"
			)

		return

	# COYOTE TIMER

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jumps_used = 0
	else:
		coyote_timer -= delta

# WALL CLING DETECTION

	if GameState.has_ability("wall_cling") \
	and not is_on_floor() \
	and is_on_wall() \
	and not is_dashing \
	and not is_ground_slamming \
	and velocity.y >= 0.0 \
	and wall_jump_lock_timer <= 0.0 \
	and (is_wall_clinging or stamina > MIN_STAMINA_TO_WALL_CLING):

		var wall_normal := get_wall_normal()

		var pressing_into_wall := (
			(wall_normal.x > 0.0 and Input.get_axis("move_left", "move_right") < 0.0)
			or
			(wall_normal.x < 0.0 and Input.get_axis("move_left", "move_right") > 0.0)
		)

		if pressing_into_wall:

			is_wall_clinging = true
			wall_normal_x = wall_normal.x
			jumps_used = 0

		else:
			is_wall_clinging = false

	else:
		is_wall_clinging = false

	# WALL CLING STAMINA DRAIN

	if is_wall_clinging:
		if not drain_stamina(WALL_CLING_STAMINA_DRAIN_RATE * delta):
			is_wall_clinging = false
	# WALL JUMP LOCK TIMER

	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta

	# JUMP BUFFER

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# SHORT HOP

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= SHORT_HOP_CUT

	# WALL JUMP

	if is_wall_clinging and jump_buffer_timer > 0.0:

		velocity.x = wall_normal_x * WALL_JUMP_HORIZONTAL_SPEED
		velocity.y = WALL_JUMP_VERTICAL_VELOCITY

		jump_buffer_timer = 0.0
		jumps_used = 1

		is_wall_clinging = false

		# Hide wall animation
		wall_animation.visible = false

		wall_jump_lock_timer = WALL_JUMP_LOCK_TIME

		jump_sound.play()

		jump_effect.visible = true
		jump_effect.play("jumpwind")

	# GROUND / COYOTE JUMP

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:

		# Stop gliding
		is_gliding = false
		was_gliding = false

		# Stop wall cling
		is_wall_clinging = false

		glide_animation.visible = false
		wall_animation.visible = false

		animated_sprite_2d.visible = true

		velocity.y = JUMP_VELOCITY

		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jumps_used = 1

		jump_sound.play()

		jump_effect.visible = true
		jump_effect.play("jumpwind")

	# AIR JUMP / DOUBLE JUMP

	elif jump_buffer_timer > 0.0 \
	and jumps_used < 2 \
	and not is_on_floor() \
	and GameState.has_ability("double_jump"):

		# Stop gliding
		is_gliding = false
		was_gliding = false

		# Stop wall cling
		is_wall_clinging = false

		glide_animation.visible = false
		wall_animation.visible = false

		animated_sprite_2d.visible = true

		velocity.y = DOUBLE_JUMP_VELOCITY

		jump_buffer_timer = 0.0
		jumps_used = 2

		jump_effect.visible = true
		jump_effect.play("jumpwind")

		if mp >= DOUBLE_JUMP_MP_COST:
			# 2+ MP:
			# ENHANCED DOUBLE JUMP WITH FIRE

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
			# 0 OR 1 MP:
			# WEAKER SMOKE FALLBACK

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

	# GRAVITY / GLIDE

	if not is_on_floor():

		if is_wall_clinging:

			velocity.y = move_toward(
				velocity.y,
				WALL_SLIDE_MAX_SPEED,
				WALL_SLIDE_GRAVITY * delta
			)

		elif coyote_timer > 0.0:

			velocity.y = 0.0
			is_gliding = false

		elif GameState.has_ability("glide") \
		and Input.is_action_pressed("glide") \
		and velocity.y > 0.0 \
		and not is_ground_slamming:

			is_gliding = true

			velocity.y += GRAVITY_GLIDE * delta
			velocity.y = min(
				velocity.y,
				GLIDE_MAX_FALL_SPEED
			)

		else:

			is_gliding = false

			velocity.y += (
				GRAVITY_FALL
				if velocity.y > 0
				else GRAVITY_RISE
			) * delta

	else:

		is_gliding = false
		is_wall_clinging = false

	# INPUT DIRECTION

	var direction := Input.get_axis(
		"move_left",
		"move_right"
	)

	# FLIP SPRITES

	if direction > 0:

		animated_sprite_2d.flip_h = false
		sword_hitbox.scale.x = 1

	elif direction < 0:

		animated_sprite_2d.flip_h = true
		sword_hitbox.scale.x = -1

	# MOVEMENT

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

	# COLLISION SWITCHING

	standing_collision.disabled = not is_on_floor()
	air_collision.disabled = is_on_floor()

	move_and_slide()

	# ATTACK

	if Input.is_action_just_pressed("attack") and not is_attacking:

		is_attacking = true
		sword_has_hit = false

		# Stop glide
		is_gliding = false
		was_gliding = false

		# Stop wall cling
		is_wall_clinging = false

		# Hide special animations
		glide_animation.visible = false
		wall_animation.visible = false

		animated_sprite_2d.visible = true

		animated_sprite_2d.play("attack")

		slash_effect.visible = true
		slash_effect.flip_h = animated_sprite_2d.flip_h
		slash_effect.play("slash")

		sword_sound.play()

	# SWORD HIT DETECTION

	if is_attacking \
	and animated_sprite_2d.animation == "attack":

		if animated_sprite_2d.frame >= 1 \
		and animated_sprite_2d.frame <= 5 \
		and not sword_has_hit:

			sword_has_hit = true
			sword_attack()

	# ANIMATIONS

	if not is_attacking:

		# ON FLOOR

		if is_on_floor():

			# Hide special animations
			glide_animation.visible = false
			wall_animation.visible = false

			was_gliding = false

			# Normal sprite is active
			animated_sprite_2d.visible = true

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

		# COYOTE TIME

		elif coyote_timer > 0.0:

			# Hide special animations
			glide_animation.visible = false
			wall_animation.visible = false

			was_gliding = false

			# Normal sprite is active
			animated_sprite_2d.visible = true

			if direction == 0:

				animated_sprite_2d.play("idle")
				last_footstep_frame = -1

			else:

				animated_sprite_2d.play("run")

		# AIR

		else:

			# WALL CLING

			if is_wall_clinging:

				# Hide normal player sprite
				animated_sprite_2d.visible = false

				# Hide glide animation
				glide_animation.visible = false
				was_gliding = false

				# Show WallAnimation
				wall_animation.visible = true

				# Match facing direction
				# Same logic as GlideAnimation
				wall_animation.flip_h = not animated_sprite_2d.flip_h

				# Play wall cling animation
				if wall_animation.animation != "wall_cling":
					wall_animation.play("wall_cling")

			# GLIDING

			elif is_gliding:

				# Hide normal player sprite
				animated_sprite_2d.visible = false

				# Hide wall animation
				wall_animation.visible = false

				# Show GlideAnimation
				glide_animation.visible = true

				# Match facing direction
				glide_animation.flip_h = not animated_sprite_2d.flip_h

				if not was_gliding:

					glide_animation.stop()
					glide_animation.frame = 0
					glide_animation.play("glide")

					was_gliding = true

			# RISING / JUMPING

			elif velocity.y < 0:

				# Hide special animations
				glide_animation.visible = false
				wall_animation.visible = false

				was_gliding = false

				# Show normal sprite
				animated_sprite_2d.visible = true

				animated_sprite_2d.play("jump")

			# FALLING

			else:

				# Hide special animations
				glide_animation.visible = false
				wall_animation.visible = false

				was_gliding = false

				# Show normal sprite
				animated_sprite_2d.visible = true

				if animated_sprite_2d.animation != "fall_loop":

					animated_sprite_2d.play("fall")

				if animated_sprite_2d.animation == "fall" \
				and animated_sprite_2d.frame >= 4:

					animated_sprite_2d.play("fall_loop")


# HP / MP

func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func restore_full_mp() -> void:
	mp = max_mp
	mp_changed.emit(mp, max_mp)
	GameState.current_mp = mp

# STAMINA

func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false

	stamina -= amount
	stamina_regen_timer = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina)
	return true


func drain_stamina(amount: float) -> bool:
	# Per-frame continuous drain (wall cling), vs. spend_stamina's
	# flat one-time cost (dash chain). Returns false once empty.
	if stamina <= 0.0:
		return false

	stamina = max(stamina - amount, 0.0)
	stamina_regen_timer = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina)
	return stamina > 0.0


func restore_full_stamina() -> void:
	stamina = max_stamina
	stamina_regen_timer = 0.0
	stamina_changed.emit(stamina, max_stamina)


func _process_stamina_regen(delta: float) -> void:
	if stamina >= max_stamina:
		return

	if stamina_regen_timer > 0.0:
		stamina_regen_timer -= delta
		return

	stamina = min(stamina + STAMINA_REGEN_RATE * delta, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func increase_max_mp(amount: int) -> void:
	print("MP BEFORE: ", max_mp)
	print("GAIN: ", amount)

	max_mp += amount

	print("MP AFTER: ", max_mp)

	mp_changed.emit(mp, max_mp)


# SLOW EFFECT

func set_slowed(slowed: bool) -> void:
	is_slowed = slowed
