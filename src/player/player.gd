extends CharacterBody2D


class RecallAnchorMarker extends Node2D:
	var _pulse_time := 0.0

	func _process(delta: float) -> void:
		_pulse_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.85 + sin(_pulse_time * 4.0) * 0.15
		draw_circle(Vector2.ZERO, 10.0 * pulse, Color(1.3, 1.5, 2.2, 0.9))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(1.3, 1.5, 2.2, 0.5), 3.0)


signal health_changed(current_health, max_health)
signal mp_changed(current_mp, max_mp)
signal stamina_changed(current_stamina, max_stamina)
signal ability_used(ability_id: String)

const SPEED := 430.0
const HAZARD_INVINCIBILITY_TIME := 1.0
const JUMP_VELOCITY := -1200.0
const DOUBLE_JUMP_VELOCITY := -1000.0
const GRAVITY_RISE := 3429.0
const GRAVITY_FALL := GRAVITY_RISE * 1.2
const SHORT_HOP_CUT := 0.5
const GRAVITY_GLIDE := GRAVITY_FALL * 0.18
const GLIDE_MAX_FALL_SPEED := 260.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

const DOUBLE_JUMP_MP_COST := 2

# Dash
const DASH_SPEED := 1600.0
const DASH_DURATION := 0.19
const DASH_COOLDOWN := 0.6
const DASH_CHAIN_COOLDOWN := 0.15
const DASH_CHAIN_STAMINA_COST := 25.0
const DASH_MP_COST := 2

# Ground Slam
const GROUND_SLAM_FALL_SPEED := 3000.0
const GROUND_SLAM_ACCEL := 10000.0
const GROUND_SLAM_DAMAGE := 4
const GROUND_SLAM_IMPACT_RADIUS := 140.0
const GROUND_SLAM_HITSTOP_DURATION := 0.06
const GROUND_SLAM_SHAKE_STRENGTH := 16.0
const GROUND_SLAM_SHAKE_DURATION := 0.25

# Wall Cling
const WALL_SLIDE_GRAVITY := GRAVITY_FALL * 0.12
const WALL_SLIDE_MAX_SPEED := 220.0
const WALL_JUMP_HORIZONTAL_SPEED := 900.0
const WALL_JUMP_VERTICAL_VELOCITY := -1100.0
const WALL_JUMP_LOCK_TIME := 0.18
const WALL_CLING_STAMINA_DRAIN_RATE := 30.0
const MIN_STAMINA_TO_WALL_CLING := 5.0

# Ledge Grab
const LEDGE_GRAB_HANG_TIME := 1.5
const LEDGE_CHECK_DISTANCE := 34.0
const LEDGE_RAY_FRONT_Y := -118.0
const LEDGE_RAY_GAP := 46.0
const LEDGE_CLIMB_OFFSET := Vector2(40.0, -20.0)

# Recall
const RECALL_MP_COST := 2
const RECALL_LEASH_RANGE := 900.0

const INVINCIBILITY_TIME := 0.5
const STAMINA_REGEN_RATE := 40.0
const STAMINA_REGEN_DELAY := 0.4


var is_slowed := false
var slow_multiplier := 0.5

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var is_attacking := false

var max_health := 5
var health := max_health
var is_dead := false

var max_mp := 3
var mp := max_mp

var invincible := false

var sword_damage := 1
var sword_has_hit := false
var _sword_damage_base := 1

var damage_reduction_active := false
var damage_reduction_multiplier := 0.5

var speed_boost_active := false
var speed_boost_multiplier := 1.5

var infinite_stamina_active := false
var fire_damage := 3
var smoke_damage := 1
var jumps_used := 0

# Dash
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var is_dashing := false
var dash_direction := 1.0
var dash_damage := 3
var dash_damage_weak := 1
var dash_hit_enemies: Array[Node] = []
var dash_empowered := false

# Ground Slam
var is_ground_slamming := false
var camera_base_offset: Vector2

# Glide
var is_gliding := false
var was_gliding := false

# Wall Cling
var is_wall_clinging := false
var wall_jump_lock_timer := 0.0
var wall_normal_x := 0.0

# Ledge Grab
var is_ledge_grabbing := false
var ledge_hang_timer := 0.0
var ledge_facing_dir := 1.0
var ledge_ray_front: RayCast2D
var ledge_ray_above: RayCast2D

# Recall
var has_recall_anchor := false
var recall_anchor_position := Vector2.ZERO
var recall_anchor_marker: Node2D = null

# Stamina
var max_stamina := 100.0
var stamina := max_stamina
var stamina_regen_timer := 0.0

# Footsteps
@export var footstep_sounds: Array[AudioStream] = []
var last_footstep_frame := -1

var input_locked := false
var transition_movement: bool = false
var transition_walking := false
var transition_walk_direction := 1.0

# PLAYER

@onready var detection_area: Area2D = $DetectionArea
@onready var standing_collision: CollisionShape2D = $CollisionShape2D

# ALL PLAYER ANIMATIONS
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# CAMERA
@onready var camera: Camera2D = $Camera2D

# COLLISION
@onready var dash_hitbox: Area2D = $Collision/DashHitbox
@onready var sword_hitbox: Area2D = $Collision/SwordHitbox
@onready var fire_hitbox: Area2D = $Collision/DoubleJumpHitbox

# ANIMATION EFFECTS
@onready var double_jump_fire_1: AnimatedSprite2D = $AnimationEffects/DoubleJumpFire1
@onready var double_jump_fire_2: AnimatedSprite2D = $AnimationEffects/DoubleJumpFire2
@onready var holy_effect: AnimatedSprite2D = $AnimationEffects/HolyEffect
@onready var wind_effect: AnimatedSprite2D = $AnimationEffects/WindEffect
@onready var slash_effect: AnimatedSprite2D = $AnimationEffects/SlashEffect
@onready var death_animation: AnimatedSprite2D = $AnimationEffects/DeathAnimation
@onready var jump_effect: AnimatedSprite2D = $AnimationEffects/JumpEffect
@onready var slam_impact_effect: AnimatedSprite2D = $AnimationEffects/SlamImpactEffect

var _double_jump_fire_1_base_scale: Vector2
var _double_jump_fire_1_base_position: Vector2
var _double_jump_fire_2_base_scale: Vector2
var _double_jump_fire_2_base_position: Vector2
var _holy_effect_base_scale: Vector2
var _holy_effect_base_position: Vector2
var _wind_effect_base_scale: Vector2
var _wind_effect_base_position: Vector2

var facing_direction := 1.0
# SOUND
@onready var sword_sound: AudioStreamPlayer2D = $Sound/SwordSound
@onready var damage_sound: AudioStreamPlayer2D = $Sound/DamageSound
@onready var death_sound: AudioStreamPlayer2D = $Sound/DeathSound
@onready var dash_sound: AudioStreamPlayer2D = $Sound/DashSound
@onready var jump_sound: AudioStreamPlayer2D = $Sound/JumpSound
@onready var fire_sound: AudioStreamPlayer2D = $Sound/FireJumpSound
@onready var footstep_sound: AudioStreamPlayer2D = $Sound/FootstepSound
@onready var ground_slam_sound: AudioStreamPlayer2D = $Sound/SlamSound


# FACING
# All player animations are authored facing RIGHT.
# This is the only function that changes player-facing direction.
func _apply_direction_to_effects(direction: float) -> void:
	var sign_x := -1.0 if direction < 0.0 else 1.0

	double_jump_fire_1.scale.x = abs(_double_jump_fire_1_base_scale.x) * sign_x
	double_jump_fire_1.position.x = _double_jump_fire_1_base_position.x * sign_x

	double_jump_fire_2.scale.x = abs(_double_jump_fire_2_base_scale.x) * sign_x
	double_jump_fire_2.position.x = _double_jump_fire_2_base_position.x * sign_x

	holy_effect.scale.x = abs(_holy_effect_base_scale.x) * sign_x
	holy_effect.position.x = _holy_effect_base_position.x * sign_x

	wind_effect.scale.x = abs(_wind_effect_base_scale.x) * sign_x
	wind_effect.position.x = _wind_effect_base_position.x * sign_x
func _set_facing(direction: float) -> void:
	if direction > 0.0:
		facing_direction = 1.0
		animated_sprite_2d.flip_h = false
		sword_hitbox.scale.x = 1.0
		dash_hitbox.scale.x = 1.0

	elif direction < 0.0:
		facing_direction = -1.0
		animated_sprite_2d.flip_h = true
		sword_hitbox.scale.x = -1.0
		dash_hitbox.scale.x = -1.0

	_apply_direction_to_effects(facing_direction)
# DEATH RESET

func reset_after_death() -> void:
	is_dead = false
	invincible = false
	input_locked = false
	transition_walking = false
	transition_walk_direction = 1.0

	velocity = Vector2.ZERO

	health = max_health
	mp = max_mp
	stamina = max_stamina

	health_changed.emit(health, max_health)
	mp_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)

	# Reset movement states.
	is_dashing = false
	is_ground_slamming = false
	is_gliding = false
	was_gliding = false
	is_wall_clinging = false
	is_ledge_grabbing = false
	is_attacking = false

	jumps_used = 0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	wall_jump_lock_timer = 0.0
	ledge_hang_timer = 0.0

	# Reset combat.
	sword_has_hit = false
	dash_empowered = false
	dash_hit_enemies.clear()
	sword_damage = _sword_damage_base
	damage_reduction_active = false
	speed_boost_active = false
	infinite_stamina_active = false
	# Restore player interaction.
	detection_area.monitoring = true
	sword_hitbox.monitoring = false
	fire_hitbox.monitoring = false
	dash_hitbox.monitoring = false

	# Keep collision disabled until respawn is complete.
	standing_collision.disabled = true

	# Stop/hide death state.
	death_animation.stop()
	death_animation.visible = false

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE
	animated_sprite_2d.play("idle")

	double_jump_fire_1.visible = false
	double_jump_fire_2.visible = false
	holy_effect.visible = false
	wind_effect.visible = false
	slash_effect.visible = false
	jump_effect.visible = false
	slam_impact_effect.visible = false
	
	cancel_attack()

func disable_world_interaction() -> void:
	input_locked = true

	detection_area.monitoring = false
	sword_hitbox.monitoring = false
	fire_hitbox.monitoring = false
	dash_hitbox.monitoring = false

	standing_collision.disabled = true
func enable_collision_only() -> void:
	standing_collision.disabled = false

func enable_world_interaction() -> void:
	input_locked = false

	detection_area.monitoring = true
	standing_collision.disabled = false
func lock_input() -> void:
	input_locked = true
	velocity = Vector2.ZERO

func _process_transition_jump(delta: float) -> void:
	# Input remains locked during the room-entry jump.
	# We only handle the physical launch and gravity here.

	if is_on_floor():
		transition_movement = false
		velocity = Vector2.ZERO

		animated_sprite_2d.visible = true

		if not is_attacking:
			animated_sprite_2d.play("idle")

		return

	# Apply normal player gravity.

	if velocity.y > 0.0:
		velocity.y += GRAVITY_FALL * delta
	else:
		velocity.y += GRAVITY_RISE * delta

	# Face the direction of travel.

	if velocity.x != 0.0:
		_set_facing(signf(velocity.x))

	move_and_slide()

	# Transition animation.

	animated_sprite_2d.visible = true

	if velocity.y < 0.0:
		animated_sprite_2d.play("fall")
	else:
		animated_sprite_2d.play("falling")

func start_transition_walk(direction: float) -> void:
	transition_walking = true
	transition_walk_direction = direction

	_set_facing(direction)

	animated_sprite_2d.visible = true
	animated_sprite_2d.play("run")


func stop_transition_walk() -> void:
	transition_walking = false

	if is_on_floor():
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("fall")


func unlock_input() -> void:
	input_locked = false


# ATTACK

func cancel_attack() -> void:
	is_attacking = false
	sword_has_hit = false
	slash_effect.stop()
	slash_effect.visible = false
	sword_hitbox.monitoring = false

	if animated_sprite_2d.animation == "attack":
		animated_sprite_2d.play("idle")


func sword_attack() -> void:
	sword_hitbox.monitoring = true

	await get_tree().physics_frame

	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") or body.is_in_group("attackable"):
			body.take_damage(sword_damage)

	sword_hitbox.monitoring = false


func fire_attack(damage: int) -> void:
	await get_tree().physics_frame

	for body in fire_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") or body.is_in_group("attackable"):
			body.take_damage(damage)


func dash_attack() -> void:
	var damage := dash_damage if dash_empowered else dash_damage_weak

	for body in dash_hitbox.get_overlapping_bodies():
		if (body.is_in_group("enemies") or body.is_in_group("attackable")) \
		and not body in dash_hit_enemies:
			body.take_damage(damage)
			dash_hit_enemies.append(body)

# GROUND SLAM

func ground_slam_impact() -> void:
	is_ground_slamming = false
	velocity = Vector2.ZERO

	deal_ground_slam_damage()

	slam_impact_effect.visible = true
	slam_impact_effect.stop()
	slam_impact_effect.frame = 0
	slam_impact_effect.play("impact")

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

	for body in get_tree().get_nodes_in_group("attackable"):
		if not is_instance_valid(body):
			continue
		if global_position.distance_to(body.global_position) <= GROUND_SLAM_IMPACT_RADIUS:
			if body.has_method("take_damage"):
				body.take_damage(GROUND_SLAM_DAMAGE)

	for body in get_tree().get_nodes_in_group("slam_breakable"):
		if not is_instance_valid(body):
			continue
		if global_position.distance_to(body.global_position) <= GROUND_SLAM_IMPACT_RADIUS:
			if body.has_method("slam_break"):
				body.slam_break()


func _ground_slam_hitstop() -> void:
	Engine.time_scale = 0.05

	await get_tree().create_timer(
		GROUND_SLAM_HITSTOP_DURATION,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0

func camera_shake(strength: float, duration: float) -> void:
	_camera_shake(strength, duration)

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


func _on_slam_impact_finished() -> void:
	if slam_impact_effect.animation == "impact":
		slam_impact_effect.visible = false


# RECALL

func _place_recall_anchor() -> void:
	has_recall_anchor = true
	recall_anchor_position = global_position

	if recall_anchor_marker == null:
		recall_anchor_marker = RecallAnchorMarker.new()
		get_tree().current_scene.add_child(recall_anchor_marker)

	recall_anchor_marker.global_position = recall_anchor_position
	recall_anchor_marker.visible = true

	_flash_recall(Color(1.3, 1.5, 2.2, 1))


func _trigger_recall() -> void:
	if mp < RECALL_MP_COST:
		_flash_recall(Color(2.2, 1.3, 1.3, 1))
		return

	mp -= RECALL_MP_COST
	mp_changed.emit(mp, max_mp)
	GameState.current_mp = mp

	global_position = recall_anchor_position
	velocity = Vector2.ZERO

	_camera_shake(6.0, 0.15)
	_flash_recall(Color(1.3, 1.5, 2.2, 1))

	_clear_recall_anchor()


func _clear_recall_anchor() -> void:
	has_recall_anchor = false

	if recall_anchor_marker:
		recall_anchor_marker.queue_free()
		recall_anchor_marker = null


func _flash_recall(color: Color) -> void:
	animated_sprite_2d.modulate = color

	await get_tree().create_timer(0.12).timeout

	if not is_dead:
		animated_sprite_2d.modulate = Color.WHITE


# LEDGE GRAB

func _start_ledge_grab(dir: float) -> void:
	is_ledge_grabbing = true
	ledge_facing_dir = dir
	ledge_hang_timer = LEDGE_GRAB_HANG_TIME

	velocity = Vector2.ZERO

	var hit_point: Vector2 = ledge_ray_front.get_collision_point()

	global_position = Vector2(
		hit_point.x - (dir * 14.0),
		ledge_ray_above.global_position.y + 40.0
	)

	is_wall_clinging = false
	is_gliding = false
	was_gliding = false

	_set_facing(dir)

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE
	animated_sprite_2d.play("ledge")


func _climb_ledge() -> void:
	global_position += Vector2(
		LEDGE_CLIMB_OFFSET.x * ledge_facing_dir,
		LEDGE_CLIMB_OFFSET.y
	)

	velocity = Vector2.ZERO

	_end_ledge_grab()


func _release_ledge() -> void:
	velocity = Vector2(0.0, 40.0)

	_end_ledge_grab()


func _end_ledge_grab() -> void:
	is_ledge_grabbing = false

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE


# DAMAGE

func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)

	await get_tree().create_timer(0.1).timeout

	if not is_dead:
		animated_sprite_2d.modulate = Color.WHITE


func take_damage(amount: int) -> void:
	if invincible or is_dead:
		return

	if damage_reduction_active:
		amount = max(0, int(round(amount * damage_reduction_multiplier)))

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

func take_hazard_damage(
	amount: int,
	respawn_position: Vector2,
	fade_duration: float = 0.25,
	invincibility_after: float = HAZARD_INVINCIBILITY_TIME
) -> void:
	if is_dead:
		return

	damage_sound.play()

	health -= amount
	health_changed.emit(health, max_health)

	flash_damage()

	if health <= 0:
		die()
		return

	await GameState.respawn_at_position(
		self,
		respawn_position,
		fade_duration,
		invincibility_after
	)


func grant_temporary_invincibility(duration: float) -> void:
	invincible = true

	await get_tree().create_timer(duration).timeout

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

	# Disable player interactions.
	detection_area.monitoring = false
	sword_hitbox.monitoring = false
	fire_hitbox.monitoring = false
	dash_hitbox.monitoring = false

	# Disable collision.
	standing_collision.set_deferred("disabled", true)

	# Stop player effects.
	cancel_attack()
	_clear_recall_anchor()

	double_jump_fire_1.visible = false
	double_jump_fire_2.visible = false
	holy_effect.visible = false
	wind_effect.visible = false
	slash_effect.visible = false
	jump_effect.visible = false
	slam_impact_effect.visible = false

	is_ledge_grabbing = false

	# Hide normal player animation.
	animated_sprite_2d.visible = false

	# Show death animation effect.
	death_animation.visible = true
	death_animation.flip_h = animated_sprite_2d.flip_h
	death_animation.play("death")

	# Play death sound.
	death_sound.pitch_scale = 1.2
	death_sound.play()

	# Wait for death sound to finish.
	await death_sound.finished

	# Fully complete the respawn before die() finishes.
	await GameState.respawn_player()


# FIRE ANIMATION

func _on_fire_animation_finished() -> void:
	double_jump_fire_1.visible = false
	double_jump_fire_2.visible = false
	fire_hitbox.monitoring = false


# ANIMATION SIGNALS

func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == "attack":
		cancel_attack()


# FOOTSTEPS

func play_footstep() -> void:
	if footstep_sounds.is_empty():
		return

	footstep_sound.stream = footstep_sounds.pick_random()
	footstep_sound.play()


# READY

func _ready() -> void:
	add_to_group("player")
	$DetectionArea.add_to_group("player_detection")

	max_mp = GameState.max_mp
	mp = GameState.current_mp
	max_health = GameState.max_health
	health = max_health
	floor_snap_length = 4.0

	# CAMERA
	camera_base_offset = camera.offset

	# HIDE EFFECTS

	slash_effect.visible = false
	sword_hitbox.monitoring = false

	double_jump_fire_1.visible = false
	double_jump_fire_2.visible = false
	fire_hitbox.monitoring = false

	holy_effect.visible = false
	wind_effect.visible = false
	dash_hitbox.monitoring = false

	death_animation.visible = false
	jump_effect.visible = false
	slam_impact_effect.visible = false
	_double_jump_fire_1_base_scale = double_jump_fire_1.scale
	_double_jump_fire_1_base_position = double_jump_fire_1.position
	_double_jump_fire_2_base_scale = double_jump_fire_2.scale
	_double_jump_fire_2_base_position = double_jump_fire_2.position
	_holy_effect_base_scale = holy_effect.scale
	_holy_effect_base_position = holy_effect.position
	_wind_effect_base_scale = wind_effect.scale
	_wind_effect_base_position = wind_effect.position
	# LEDGE GRAB RAYS

	ledge_ray_front = RayCast2D.new()
	ledge_ray_front.position = Vector2(0, LEDGE_RAY_FRONT_Y)
	ledge_ray_front.collision_mask = 1
	add_child(ledge_ray_front)

	ledge_ray_above = RayCast2D.new()
	ledge_ray_above.position = Vector2(0, LEDGE_RAY_FRONT_Y - LEDGE_RAY_GAP)
	ledge_ray_above.collision_mask = 1
	add_child(ledge_ray_above)

	# CONNECT ANIMATION SIGNALS

	animated_sprite_2d.animation_finished.connect(
		_on_animation_finished
	)

	double_jump_fire_1.animation_finished.connect(
		_on_fire_animation_finished
	)

	double_jump_fire_2.animation_finished.connect(
		_on_fire_animation_finished
	)

	jump_effect.animation_finished.connect(
		_on_jump_effect_finished
	)

	slam_impact_effect.animation_finished.connect(
		_on_slam_impact_finished
	)

	mp_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)
	_sword_damage_base = sword_damage
# PHYSICS PROCESS

func _physics_process(delta: float) -> void:

	if is_dead:
		return

	# TRANSITION JUMP
	#
	# Input is locked, but the player must still be allowed
	# to move physically using the velocity assigned by GameState.
	if transition_movement:
		_process_transition_jump(delta)
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
		_end_ledge_grab()
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_CHAIN_COOLDOWN if dash_chained else DASH_COOLDOWN

		cancel_attack()

		# Determine dash direction from facing.
		dash_direction = -1.0 if animated_sprite_2d.flip_h else 1.0

		# Check if player has enough MP for empowered dash.
		dash_empowered = mp >= DASH_MP_COST

		ability_used.emit("dash")

		if dash_chained:
			ability_used.emit("dash_chain")

		if dash_empowered:
			mp -= DASH_MP_COST

			mp_changed.emit(mp, max_mp)
			GameState.current_mp = mp

			invincible = true
		else:
			invincible = false

		# Hitbox stays active either way now — an unempowered dash
		# still lands a weak hit, it just skips i-frames and the
		# MP spend. See dash_attack().
		dash_hitbox.monitoring = true
		dash_hit_enemies.clear()
		# DASH ANIMATION
		animated_sprite_2d.visible = true
		animated_sprite_2d.play("dash")

		# DASH EFFECTS

		# Wind effect always plays.
		wind_effect.visible = true
		wind_effect.play("wind")

		# Holy effect only plays on empowered dash.
		if dash_empowered:
			holy_effect.visible = true
			holy_effect.play("dash")
		else:
			holy_effect.visible = false

		dash_sound.play()

	# GROUND SLAM START

	if Input.is_action_just_pressed("ground_slam") \
	and GameState.has_ability("ground_slam") \
	and not is_on_floor() \
	and not is_dashing \
	and not is_ground_slamming:

		is_ground_slamming = true
		ability_used.emit("ground_slam")
		is_gliding = false
		was_gliding = false
		is_wall_clinging = false
		_end_ledge_grab()
		cancel_attack()

		animated_sprite_2d.visible = true
		animated_sprite_2d.play("slam")

		velocity.y = 0.0

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

			invincible = false
			dash_hitbox.monitoring = false
			dash_empowered = false

			animated_sprite_2d.play(
				"falling" if not is_on_floor() else "idle"
			)

			holy_effect.stop()
			wind_effect.stop()

			holy_effect.visible = false
			wind_effect.visible = false

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

	# LEDGE GRAB PROCESS

	if is_ledge_grabbing:
		ledge_hang_timer -= delta

		if Input.is_action_just_pressed("jump"):
			_climb_ledge()
			return

		var release_axis := Input.get_axis(
			"move_left",
			"move_right"
		)

		var pressing_away := (
			(ledge_facing_dir > 0.0 and release_axis < 0.0)
			or
			(ledge_facing_dir < 0.0 and release_axis > 0.0)
		)

		if pressing_away \
		or Input.is_action_just_pressed("ground_slam") \
		or ledge_hang_timer <= 0.0:
			_release_ledge()

		return

	# INPUT LOCK

	if input_locked:
		velocity = Vector2.ZERO

		if transition_walking:
			animated_sprite_2d.visible = true
			animated_sprite_2d.play("run")
		else:
			if not is_attacking:
				animated_sprite_2d.visible = true
				animated_sprite_2d.play("idle")

		return

	# RECALL LEASH CHECK

	if has_recall_anchor \
	and global_position.distance_to(recall_anchor_position) > RECALL_LEASH_RANGE:

		_flash_recall(Color(2.2, 1.3, 1.3, 1))
		_clear_recall_anchor()

	# RECALL INPUT

	if Input.is_action_just_pressed("recall") \
	and GameState.has_ability("recall") \
	and not is_dashing \
	and not is_ground_slamming:
		ability_used.emit("recall")
		if not has_recall_anchor:
			_place_recall_anchor()
		else:
			_trigger_recall()
# POTION INPUT

	if Input.is_action_just_pressed("use_potion") and GameState.potion_charged:
		GameState.use_potion(self)
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
			if not is_wall_clinging:
				ability_used.emit("wall_cling")
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

	# LEDGE GRAB DETECTION

	if GameState.has_ability("ledge_grab") \
	and not is_on_floor() \
	and not is_dashing \
	and not is_ground_slamming \
	and not is_ledge_grabbing \
	and velocity.y >= 0.0:

		var ledge_input := Input.get_axis(
			"move_left",
			"move_right"
		)

		if ledge_input != 0.0:
			var ledge_dir := signf(ledge_input)

			ledge_ray_front.target_position = Vector2(
				LEDGE_CHECK_DISTANCE * ledge_dir,
				0
			)

			ledge_ray_above.target_position = Vector2(
				LEDGE_CHECK_DISTANCE * ledge_dir,
				0
			)

			ledge_ray_front.force_raycast_update()
			ledge_ray_above.force_raycast_update()

			if ledge_ray_front.is_colliding() \
			and not ledge_ray_above.is_colliding():
				ability_used.emit("ledge_grab")
				_start_ledge_grab(ledge_dir)

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

		wall_jump_lock_timer = WALL_JUMP_LOCK_TIME

		jump_sound.play()

		jump_effect.visible = true
		jump_effect.play("jumpwind")

	# GROUND / COYOTE JUMP

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:

		is_gliding = false
		was_gliding = false
		is_wall_clinging = false

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

		is_gliding = false
		was_gliding = false
		is_wall_clinging = false

		animated_sprite_2d.visible = true

		velocity.y = DOUBLE_JUMP_VELOCITY

		jump_buffer_timer = 0.0
		jumps_used = 2
		ability_used.emit("double_jump")
		jump_effect.visible = true
		jump_effect.play("jumpwind")

		if mp >= DOUBLE_JUMP_MP_COST:

			# ENHANCED DOUBLE JUMP

			mp -= DOUBLE_JUMP_MP_COST

			mp_changed.emit(mp, max_mp)
			GameState.current_mp = mp

			double_jump_fire_1.visible = true
			double_jump_fire_2.visible = true

			double_jump_fire_1.modulate = Color.WHITE
			double_jump_fire_2.modulate = Color.WHITE

			double_jump_fire_1.stop()
			double_jump_fire_2.stop()

			double_jump_fire_1.frame = 0
			double_jump_fire_2.frame = 0

			double_jump_fire_1.play("fire")
			double_jump_fire_2.play("fire")

			fire_sound.play()

			fire_hitbox.monitoring = true
			fire_attack(fire_damage)

		else:

			# SMOKE FALLBACK

			var smoke_color := Color(
				0.405,
				0.405,
				0.405,
				0.3
			)

			double_jump_fire_1.visible = true
			double_jump_fire_2.visible = true

			double_jump_fire_1.modulate = smoke_color
			double_jump_fire_2.modulate = smoke_color

			double_jump_fire_1.stop()
			double_jump_fire_2.stop()

			double_jump_fire_1.frame = 0
			double_jump_fire_2.frame = 0

			double_jump_fire_1.play("fire")
			double_jump_fire_2.play("fire")

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
			if not is_gliding:
				ability_used.emit("glide")
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

	# FACINGF

	if direction != 0.0:
		_set_facing(direction)

	# MOVEMENT

	var current_speed := SPEED

	if is_slowed:
		current_speed *= slow_multiplier

	if speed_boost_active:
		current_speed *= speed_boost_multiplier
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(
			velocity.x,
			0,
			current_speed
		)

	move_and_slide()

	# ATTACK

	if Input.is_action_just_pressed("attack") and not is_attacking:

		is_attacking = true
		sword_has_hit = false

		is_gliding = false
		was_gliding = false
		is_wall_clinging = false

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

			was_gliding = false
			animated_sprite_2d.visible = true

			if direction == 0:

				animated_sprite_2d.play("idle")
				last_footstep_frame = -1

			else:

				animated_sprite_2d.play("run")

				if animated_sprite_2d.frame in [5, 13, 22]:

					if last_footstep_frame != animated_sprite_2d.frame:

						last_footstep_frame = animated_sprite_2d.frame
						play_footstep()

		# COYOTE TIME

		elif coyote_timer > 0.0:

			was_gliding = false
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

				animated_sprite_2d.visible = true
				animated_sprite_2d.play("wall")

			# GLIDING

			elif is_gliding:

				animated_sprite_2d.visible = true

				if not was_gliding:

					animated_sprite_2d.stop()
					animated_sprite_2d.frame = 0
					animated_sprite_2d.play("glide")

					was_gliding = true

				elif animated_sprite_2d.animation != "glide":
					animated_sprite_2d.play("glide")

			# RISING / JUMPING

			elif velocity.y >= 0:

				was_gliding = false
				animated_sprite_2d.visible = true

				if animated_sprite_2d.animation != "fall" \
				and animated_sprite_2d.animation != "falling":

					animated_sprite_2d.play("fall")

				if animated_sprite_2d.animation == "fall":
					var fall_frame_count := animated_sprite_2d.sprite_frames.get_frame_count("fall")

					if animated_sprite_2d.frame >= fall_frame_count - 1:
						animated_sprite_2d.play("falling")

			# FALLING

			else:

				was_gliding = false
				animated_sprite_2d.visible = true

				if animated_sprite_2d.animation != "fall" \
				and animated_sprite_2d.animation != "falling":

					animated_sprite_2d.play("fall")

				if animated_sprite_2d.animation == "fall" \
				and animated_sprite_2d.frame >= 4:

					animated_sprite_2d.play("falling")


# JUMP EFFECT

func _on_jump_effect_finished() -> void:
	if jump_effect.animation == "jumpwind":
		jump_effect.visible = false


# HP / MP

func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func restore_full_mp() -> void:
	mp = max_mp
	mp_changed.emit(mp, max_mp)
	GameState.current_mp = mp
# New functions — near restore_full_health() / restore_full_mp()

func apply_double_sword_damage(duration: float) -> void:
	sword_damage = _sword_damage_base * 2

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(self):
		sword_damage = _sword_damage_base


func apply_damage_reduction(duration: float) -> void:
	damage_reduction_active = true

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(self):
		damage_reduction_active = false


func apply_speed_boost(duration: float) -> void:
	speed_boost_active = true

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(self):
		speed_boost_active = false


func apply_infinite_stamina(duration: float) -> void:
	infinite_stamina_active = true

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(self):
		infinite_stamina_active = false

func increase_max_mp(amount: int) -> void:
	max_mp += amount
	mp_changed.emit(mp, max_mp)


# STAMINA

func spend_stamina(amount: float) -> bool:
	if infinite_stamina_active:
		stamina_regen_timer = STAMINA_REGEN_DELAY
		return true

	if stamina < amount:
		return false

	stamina -= amount
	stamina_regen_timer = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina)

	return true



func drain_stamina(amount: float) -> bool:
	if infinite_stamina_active:
		return true

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

	stamina = min(
		stamina + STAMINA_REGEN_RATE * delta,
		max_stamina
	)

	stamina_changed.emit(stamina, max_stamina)


# SLOW EFFECT

func set_slowed(slowed: bool) -> void:
	is_slowed = slowed
