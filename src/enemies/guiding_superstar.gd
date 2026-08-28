extends CharacterBody2D
class_name GuidingSuperstar


class ShockwaveEffect extends Node2D:
	var lifetime: float = 0.0
	var duration: float = 0.32
	var start_radius: float = 18.0
	var end_radius: float = 240.0
	var line_width: float = 8.0

	func setup(radius: float, life: float = 0.32) -> void:
		end_radius = radius
		duration = life

	func _process(delta: float) -> void:
		lifetime += delta

		if lifetime >= duration:
			queue_free()
			return

		queue_redraw()

	func _draw() -> void:
		var progress: float = lifetime / duration
		var radius: float = lerp(start_radius, end_radius, progress)
		var alpha: float = 1.0 - progress

		draw_arc(
			Vector2.ZERO,
			radius,
			PI,
			TAU,
			32,
			Color(1.0, 0.95, 0.8, alpha),
			line_width,
			true
		)

		draw_arc(
			Vector2.ZERO,
			radius * 0.82,
			PI,
			TAU,
			32,
			Color(1.0, 0.95, 0.8, alpha * 0.45),
			3.0,
			true
		)


enum State {
	INACTIVE,
	REST,
	DECIDE,
	LUNGE,
	GROUND_SLAM,
	CEILING_SLAM,
	REPOSITION,
	FOLLOW_SPIN,
	DEAD
}


# -------------------------------------------------------------------
# Boss stats
# -------------------------------------------------------------------

const MAX_HEALTH: int = 20
const CONTACT_DAMAGE: int = 1

const FOLLOW_SPEED: float = 400.0
const REPOSITION_SPEED: float = 500.0
const LUNGE_SPEED: float = 1500.0

# -------------------------------------------------------------------
# Wind-ups
# -------------------------------------------------------------------

const LUNGE_WINDUP: float = 0.75
const GROUND_SLAM_WINDUP: float = 0.8
const CEILING_SLAM_WINDUP: float = 0.8
const FOLLOW_SPIN_WINDUP: float = 0.55
const REPOSITION_WINDUP: float = 0.3

# -------------------------------------------------------------------
# Attack durations
# -------------------------------------------------------------------

const LUNGE_DURATION: float = 0.24
const GROUND_SLAM_DURATION: float = 0.28
const CEILING_SLAM_DURATION: float = 0.42
const REPOSITION_DURATION: float = 0.55
const FOLLOW_SPIN_DURATION: float = 2.5

# -------------------------------------------------------------------
# Recovery / behavior
# -------------------------------------------------------------------

const REST_MIN_DURATION: float = 0.75
const REST_MAX_DURATION: float = 0.95

const GROUND_BEHAVIOR_THRESHOLD: float = 0.65
const AIR_BEHAVIOR_THRESHOLD: float = 0.45

const HIGH_PLAYER_DISTANCE: float = 120.0
const CLOSE_RANGE: float = 500.0
const FAR_RANGE: float = 800.0

# -------------------------------------------------------------------
# Ground slam
# -------------------------------------------------------------------

const GROUND_SLAM_RADIUS: float = 240.0
const GROUND_SLAM_VERTICAL_RANGE: float = 135.0
const GROUND_SLAM_DAMAGE: int = 1

# -------------------------------------------------------------------
# Ceiling slam
# -------------------------------------------------------------------

const CEILING_SLAM_DAMAGE: int = 1
const ROCK_COUNT: int = 7
const ROCK_SPAWN_SPREAD: float = 520.0
const ROCK_SPAWN_DELAY_STEP: float = 0.08
const ROCK_INITIAL_SPEED: float = 80.0

# -------------------------------------------------------------------
# Screen shake
# -------------------------------------------------------------------

const GROUND_SLAM_SHAKE_STRENGTH: float = 9.0
const GROUND_SLAM_SHAKE_DURATION: float = 0.18

const CEILING_SLAM_SHAKE_STRENGTH: float = 10.0
const CEILING_SLAM_SHAKE_DURATION: float = 0.2

const DEATH_SHAKE_STRENGTH: float = 14.0
const DEATH_SHAKE_DURATION: float = 0.3

# -------------------------------------------------------------------
# Procedural animation
# -------------------------------------------------------------------

const BASE_SPIN_SPEED: float = 1.8
const FAST_SPIN_MULTIPLIER: float = 6.0


# -------------------------------------------------------------------
# State
# -------------------------------------------------------------------

var state: State = State.INACTIVE
var state_time: float = 0.0
var rest_duration: float = 0.0

var max_health: int = MAX_HEALTH
var health: int = MAX_HEALTH

var active: bool = false
var is_dying: bool = false
var death_started: bool = false

var player: Node2D = null

var player_ground_time: float = 0.0
var player_air_time: float = 0.0

var last_attack: State = State.REST

var attack_direction: Vector2 = Vector2.RIGHT
var reposition_target: Vector2 = Vector2.ZERO

var attack_impact_done: bool = false
var flash_timer: float = 0.0

# Stores the AnimatedSprite2D scale set in the editor.
# Your current Superstar scale is 0.21, 0.21.
var base_sprite_scale: Vector2 = Vector2.ONE


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var killzone: Area2D = $Killzone
@onready var killzone_collision: CollisionShape2D = $Killzone/CollisionShape2D
@onready var damage_timer: Timer = $Killzone/DamageTimer


func _ready() -> void:
	add_to_group("enemies")

	# Preserve the scale configured in the editor.
	base_sprite_scale = animated_sprite_2d.scale

	active = false
	is_dying = false
	death_started = false

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE
	animated_sprite_2d.scale = base_sprite_scale
	animated_sprite_2d.rotation = 0.0

	_set_combat_active(false)

	state = State.INACTIVE

	set_physics_process(false)


# -------------------------------------------------------------------
# BossEncounter interface
# -------------------------------------------------------------------

func boss_entrance_awaken() -> void:
	if death_started:
		return

	active = false
	is_dying = false

	_set_combat_active(false)

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color(0.55, 0.55, 0.55, 1.0)

	# Start slightly smaller than the normal editor-configured size.
	animated_sprite_2d.scale = base_sprite_scale * 0.9
	animated_sprite_2d.rotation = 0.0

	var tween: Tween = create_tween()

	tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color.WHITE,
		0.35
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		animated_sprite_2d,
		"scale",
		base_sprite_scale * 1.12,
		0.28
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		animated_sprite_2d,
		"scale",
		base_sprite_scale,
		0.22
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	await tween.finished


func activate_boss() -> void:
	if death_started:
		return

	active = true
	is_dying = false
	health = max_health

	state = State.REST
	state_time = 0.0
	rest_duration = REST_MIN_DURATION
	last_attack = State.REST

	velocity = Vector2.ZERO

	# Always return to the editor-configured scale.
	animated_sprite_2d.scale = base_sprite_scale

	_set_combat_active(true)

	set_physics_process(true)


func deactivate_boss() -> void:
	active = false
	velocity = Vector2.ZERO
	state = State.INACTIVE

	_set_combat_active(false)

	set_physics_process(false)


func reset_boss() -> void:
	active = false
	is_dying = false
	death_started = false

	health = max_health
	state = State.INACTIVE
	state_time = 0.0
	last_attack = State.REST

	player = null

	player_ground_time = 0.0
	player_air_time = 0.0

	velocity = Vector2.ZERO
	rotation = 0.0

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE
	animated_sprite_2d.scale = base_sprite_scale
	animated_sprite_2d.rotation = 0.0

	_set_combat_active(false)

	set_physics_process(false)


# -------------------------------------------------------------------
# Main physics
# -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active or death_started:
		return

	state_time += delta

	_update_player()
	_update_visual_animation(delta)

	match state:
		State.REST:
			_state_rest()

		State.DECIDE:
			_state_decide()

		State.LUNGE:
			_state_lunge(delta)

		State.GROUND_SLAM:
			_state_ground_slam(delta)

		State.CEILING_SLAM:
			_state_ceiling_slam(delta)

		State.REPOSITION:
			_state_reposition(delta)

		State.FOLLOW_SPIN:
			_state_follow_spin(delta)

		State.INACTIVE:
			pass

		State.DEAD:
			pass


# -------------------------------------------------------------------
# Player analysis
# -------------------------------------------------------------------

func _update_player() -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		player = null
		player_ground_time = 0.0
		player_air_time = 0.0
		return

	player = player_node as Node2D

	if player == null:
		player_ground_time = 0.0
		player_air_time = 0.0
		return

	var delta: float = get_physics_process_delta_time()

	if player.has_method("is_on_floor") and player.is_on_floor():
		player_ground_time += delta
		player_air_time = 0.0
	else:
		player_air_time += delta
		player_ground_time = 0.0


func _player_distance() -> float:
	if player == null:
		return INF

	return global_position.distance_to(
		player.global_position
	)


func _player_vertical_difference() -> float:
	if player == null:
		return 0.0

	return player.global_position.y - global_position.y


# -------------------------------------------------------------------
# FSM
# -------------------------------------------------------------------

func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	attack_impact_done = false
	velocity = Vector2.ZERO

	match new_state:
		State.REST:
			rest_duration = randf_range(
				REST_MIN_DURATION,
				REST_MAX_DURATION
			)

		State.LUNGE:
			last_attack = State.LUNGE

			if player:
				attack_direction = global_position.direction_to(
					player.global_position + Vector2(0.0, -48.0)
				)
			else:
				attack_direction = Vector2.RIGHT

		State.GROUND_SLAM:
			last_attack = State.GROUND_SLAM

		State.CEILING_SLAM:
			last_attack = State.CEILING_SLAM

		State.REPOSITION:
			last_attack = State.REPOSITION

			if player:
				var side: float = sign(
					global_position.x - player.global_position.x
				)

				if side == 0.0:
					side = 1.0

				var vertical_offset: float = 0.0

				if _player_vertical_difference() < -100.0:
					vertical_offset = 120.0

				reposition_target = player.global_position + Vector2(
					side * 320.0,
					vertical_offset
				)

		State.FOLLOW_SPIN:
			last_attack = State.FOLLOW_SPIN

		State.DECIDE:
			pass

		State.INACTIVE:
			pass

		State.DEAD:
			pass


# -------------------------------------------------------------------
# REST
# -------------------------------------------------------------------

func _state_rest() -> void:
	velocity = Vector2.ZERO

	if state_time >= rest_duration:
		_change_state(State.DECIDE)


# -------------------------------------------------------------------
# DECIDE
# -------------------------------------------------------------------

func _state_decide() -> void:
	_choose_next_attack()


func _choose_next_attack() -> void:
	if player == null:
		_change_state(State.REPOSITION)
		return

	var distance: float = _player_distance()
	var vertical_difference: float = _player_vertical_difference()

	var weights: Array = []

	# Base choices.
	_add_attack_choice(weights, State.LUNGE, 25.0)
	_add_attack_choice(weights, State.GROUND_SLAM, 15.0)
	_add_attack_choice(weights, State.CEILING_SLAM, 15.0)
	_add_attack_choice(weights, State.REPOSITION, 20.0)
	_add_attack_choice(weights, State.FOLLOW_SPIN, 25.0)

	# Player is close.
	if distance <= CLOSE_RANGE:
		_add_attack_choice(weights, State.LUNGE, 30.0)
		_add_attack_choice(weights, State.FOLLOW_SPIN, 10.0)

	# Player is far away.
	if distance >= FAR_RANGE:
		_add_attack_choice(weights, State.REPOSITION, 30.0)
		_add_attack_choice(weights, State.FOLLOW_SPIN, 20.0)

	# Player has been staying on the ground.
	if (
		player_ground_time >= GROUND_BEHAVIOR_THRESHOLD
		and abs(vertical_difference) <= 240.0
	):
		_add_attack_choice(weights, State.GROUND_SLAM, 55.0)

	# Player has been staying above the boss.
	if (
		player_air_time >= AIR_BEHAVIOR_THRESHOLD
		and vertical_difference <= -HIGH_PLAYER_DISTANCE
	):
		_add_attack_choice(weights, State.CEILING_SLAM, 65.0)

	# Don't immediately repeat the same action.
	var filtered: Array = []

	for choice: Array in weights:
		var choice_state: State = choice[0]

		if choice_state != last_attack:
			filtered.append(choice)

	if filtered.is_empty():
		filtered = weights

	var selected_state: State = _weighted_random_choice(filtered)

	_change_state(selected_state)


func _add_attack_choice(
	choices: Array,
	choice_state: State,
	weight: float
) -> void:
	choices.append([
		choice_state,
		weight
	])


func _weighted_random_choice(choices: Array) -> State:
	var total_weight: float = 0.0

	for choice: Array in choices:
		total_weight += float(choice[1])

	if total_weight <= 0.0:
		return State.REPOSITION

	var roll: float = randf() * total_weight

	for choice: Array in choices:
		roll -= float(choice[1])

		if roll <= 0.0:
			var selected_state: State = choice[0]
			return selected_state

	var fallback_state: State = choices.back()[0]
	return fallback_state


# -------------------------------------------------------------------
# LUNGE
# -------------------------------------------------------------------

func _state_lunge(delta: float) -> void:
	if state_time < LUNGE_WINDUP:
		velocity = Vector2.ZERO

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.25, 0.8),
			attack_direction.angle(),
			delta
		)

		return

	var lunge_time: float = state_time - LUNGE_WINDUP

	if lunge_time < LUNGE_DURATION:
		velocity = attack_direction * LUNGE_SPEED
		move_and_slide()

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.4, 0.72),
			attack_direction.angle(),
			delta
		)

		return

	velocity = Vector2.ZERO
	_change_state(State.REST)


# -------------------------------------------------------------------
# GROUND SLAM
# -------------------------------------------------------------------

func _state_ground_slam(delta: float) -> void:
	if state_time < GROUND_SLAM_WINDUP:
		velocity = Vector2.ZERO

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.3, 0.72),
			0.0,
			delta
		)

		return

	var slam_time: float = state_time - GROUND_SLAM_WINDUP

	if slam_time < GROUND_SLAM_DURATION:
		velocity = Vector2(0.0, 1400.0)

		var collision: KinematicCollision2D = move_and_collide(
			velocity * delta
		)

		_move_sprite_toward(
			base_sprite_scale * Vector2(0.82, 1.28),
			0.0,
			delta
		)

		if collision != null:
			_ground_slam_impact()
			_change_state(State.REST)

		return

	_ground_slam_impact()
	_change_state(State.REST)


func _ground_slam_impact() -> void:
	if attack_impact_done:
		return

	attack_impact_done = true
	velocity = Vector2.ZERO

	var shockwave: ShockwaveEffect = ShockwaveEffect.new()
	shockwave.setup(GROUND_SLAM_RADIUS)

	var scene: Node = get_tree().current_scene

	if scene != null:
		scene.add_child(shockwave)

		shockwave.global_position = (
			global_position + Vector2(0.0, 35.0)
		)

	var target: Node = get_tree().get_first_node_in_group("player")

	if target != null:
		var target_2d: Node2D = target as Node2D

		if target_2d != null:
			var horizontal_distance: float = abs(
				target_2d.global_position.x
				- global_position.x
			)

			var vertical_distance: float = abs(
				target_2d.global_position.y
				- global_position.y
			)

			if (
				horizontal_distance <= GROUND_SLAM_RADIUS
				and vertical_distance <= GROUND_SLAM_VERTICAL_RANGE
			):
				if target.has_method("take_damage"):
					target.call(
						"take_damage",
						GROUND_SLAM_DAMAGE
					)

	_camera_shake(
		GROUND_SLAM_SHAKE_STRENGTH,
		GROUND_SLAM_SHAKE_DURATION
	)


# -------------------------------------------------------------------
# CEILING SLAM
# -------------------------------------------------------------------

func _state_ceiling_slam(delta: float) -> void:
	if state_time < CEILING_SLAM_WINDUP:
		velocity = Vector2.ZERO

		_move_sprite_toward(
			base_sprite_scale * Vector2(0.78, 1.25),
			0.0,
			delta
		)

		return

	var slam_time: float = state_time - CEILING_SLAM_WINDUP

	if slam_time < CEILING_SLAM_DURATION:
		velocity = Vector2(0.0, -1500.0)

		var collision: KinematicCollision2D = move_and_collide(
			velocity * delta
		)

		_move_sprite_toward(
			base_sprite_scale * Vector2(0.72, 1.4),
			0.0,
			delta
		)

		if collision != null:
			_ceiling_slam_impact()
			_change_state(State.REST)

		return

	_ceiling_slam_impact()
	_change_state(State.REST)


func _ceiling_slam_impact() -> void:
	if attack_impact_done:
		return

	attack_impact_done = true
	velocity = Vector2.ZERO

	_spawn_falling_rocks()

	_camera_shake(
		CEILING_SLAM_SHAKE_STRENGTH,
		CEILING_SLAM_SHAKE_DURATION
	)


func _spawn_falling_rocks() -> void:
	var scene: Node = get_tree().current_scene

	if scene == null:
		return

	# This will be assigned to the FallingRock.tscn scene.
	var rock_scene: PackedScene = preload(
		"res://src/enemies/falling_rock.tscn"
	)

	var center_x: float = global_position.x

	if player != null:
		center_x = player.global_position.x

	for i: int in range(ROCK_COUNT):
		var normalized: float = 0.0

		if ROCK_COUNT > 1:
			normalized = float(i) / float(ROCK_COUNT - 1)

		var x_offset: float = lerp(
			-ROCK_SPAWN_SPREAD * 0.5,
			ROCK_SPAWN_SPREAD * 0.5,
			normalized
		)

		x_offset += randf_range(-45.0, 45.0)

		var rock: FallingRock = rock_scene.instantiate() as FallingRock

		if rock == null:
			continue

		var spawn_position: Vector2 = Vector2(
			center_x + x_offset,
			global_position.y + 75.0
		)

		var delay: float = 2.5 + (
			float(i) * ROCK_SPAWN_DELAY_STEP
		)

		scene.add_child(rock)

		rock.setup(
			spawn_position,
			delay,
			ROCK_INITIAL_SPEED + randf_range(-20.0, 30.0),
			CEILING_SLAM_DAMAGE
		)


# -------------------------------------------------------------------
# REPOSITION
# -------------------------------------------------------------------

func _state_reposition(delta: float) -> void:
	if state_time < REPOSITION_WINDUP:
		velocity = Vector2.ZERO

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.08, 0.92),
			0.0,
			delta
		)

		return

	var move_time: float = state_time - REPOSITION_WINDUP

	if move_time < REPOSITION_DURATION:
		var direction: Vector2 = global_position.direction_to(
			reposition_target
		)

		velocity = direction * REPOSITION_SPEED
		move_and_slide()

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.12, 0.9),
			direction.angle(),
			delta
		)

		return

	velocity = Vector2.ZERO
	_change_state(State.REST)


# -------------------------------------------------------------------
# FOLLOW SPIN
# -------------------------------------------------------------------

func _state_follow_spin(delta: float) -> void:
	if state_time < FOLLOW_SPIN_WINDUP:
		velocity = Vector2.ZERO

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.1, 0.9),
			0.0,
			delta
		)

		return

	var chase_time: float = state_time - FOLLOW_SPIN_WINDUP

	if chase_time < FOLLOW_SPIN_DURATION:
		if player == null:
			velocity = Vector2.ZERO
			_change_state(State.REST)
			return

		var direction: Vector2 = global_position.direction_to(
			player.global_position
		)

		velocity = direction * FOLLOW_SPEED
		move_and_slide()

		rotation += (
			BASE_SPIN_SPEED
			* FAST_SPIN_MULTIPLIER
			* delta
		)

		_move_sprite_toward(
			base_sprite_scale * Vector2(1.12, 0.88),
			direction.angle(),
			delta
		)

		return

	velocity = Vector2.ZERO
	_change_state(State.REST)


# -------------------------------------------------------------------
# Procedural animation
# -------------------------------------------------------------------

func _update_visual_animation(delta: float) -> void:
	match state:
		State.REST:
			rotation += BASE_SPIN_SPEED * delta

		State.DECIDE:
			rotation += BASE_SPIN_SPEED * 0.5 * delta

		State.LUNGE:
			pass

		State.GROUND_SLAM:
			pass

		State.CEILING_SLAM:
			pass

		State.REPOSITION:
			pass

		State.FOLLOW_SPIN:
			pass

		State.INACTIVE:
			pass

		State.DEAD:
			pass

	if flash_timer > 0.0:
		flash_timer -= delta

		if flash_timer <= 0.0 and not death_started:
			animated_sprite_2d.modulate = Color.WHITE


func _move_sprite_toward(
	target_scale: Vector2,
	target_rotation: float,
	delta: float
) -> void:
	var smoothing: float = 1.0 - exp(-14.0 * delta)

	animated_sprite_2d.scale = animated_sprite_2d.scale.lerp(
		target_scale,
		smoothing
	)

	animated_sprite_2d.rotation = lerp_angle(
		animated_sprite_2d.rotation,
		target_rotation,
		smoothing
	)


# -------------------------------------------------------------------
# Damage / death
# -------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if not active:
		return

	if death_started or is_dying:
		return

	health -= amount

	animated_sprite_2d.modulate = Color(
		5.0,
		5.0,
		5.0,
		1.0
	)

	flash_timer = 0.1

	if health <= 0:
		die()


func die() -> void:
	if death_started:
		return

	death_started = true
	active = false
	state = State.DEAD
	velocity = Vector2.ZERO

	_set_combat_active(false)
	set_physics_process(false)

	_camera_shake(
		DEATH_SHAKE_STRENGTH,
		DEATH_SHAKE_DURATION
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		animated_sprite_2d,
		"scale",
		base_sprite_scale * 1.18,
		0.15
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		animated_sprite_2d,
		"modulate",
		Color(
			1.0,
			1.0,
			1.0,
			0.0
		),
		0.4
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	await tween.finished

	animated_sprite_2d.visible = false

	# BossEncounter detects this and finishes the encounter.
	is_dying = true


# -------------------------------------------------------------------
# Collision / combat activation
# -------------------------------------------------------------------

func _set_combat_active(enabled: bool) -> void:
	if collision_shape:
		collision_shape.set_deferred(
			"disabled",
			not enabled
		)

	if killzone:
		killzone.set_deferred(
			"monitoring",
			enabled
		)

		killzone.set_deferred(
			"monitorable",
			enabled
		)

	if killzone_collision:
		killzone_collision.set_deferred(
			"disabled",
			not enabled
		)

	if damage_timer:
		if not enabled:
			damage_timer.stop()


# -------------------------------------------------------------------
# Camera
# -------------------------------------------------------------------

func _camera_shake(strength: float, duration: float) -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	if player_node.has_method("camera_shake"):
		player_node.call(
			"camera_shake",
			strength,
			duration
	)
