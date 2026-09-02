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

		var radius: float = lerp(
			start_radius,
			end_radius,
			progress
		)

		var alpha: float = 1.0 - progress

		draw_arc(
			Vector2.ZERO,
			radius,
			PI,
			TAU,
			32,
			Color(
				1.0,
				0.95,
				0.8,
				alpha
			),
			line_width,
			true
		)

		draw_arc(
			Vector2.ZERO,
			radius * 0.82,
			PI,
			TAU,
			32,
			Color(
				1.0,
				0.95,
				0.8,
				alpha * 0.45
			),
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
const LUNGE_SPEED: float = 1600.0


# -------------------------------------------------------------------
# Wind-ups
# -------------------------------------------------------------------

const LUNGE_WINDUP: float = 0.65
const GROUND_SLAM_WINDUP: float = 0.8
const CEILING_SLAM_WINDUP: float = 0.8
const FOLLOW_SPIN_WINDUP: float = 0.55
const REPOSITION_WINDUP: float = 0.3

const LUNGE_RECOIL_START: float = 0.45
const LUNGE_RECOIL_SPEED: float = 500.0


# -------------------------------------------------------------------
# Attack durations
# -------------------------------------------------------------------

const LUNGE_DURATION: float = 0.35
const REPOSITION_DURATION: float = 0.55
const FOLLOW_SPIN_DURATION: float = 2.6


# -------------------------------------------------------------------
# Slam movement
# -------------------------------------------------------------------

const GROUND_SLAM_RISE_SPEED: float = 220.0
const GROUND_SLAM_FALL_SPEED: float = 1700.0

const CEILING_SLAM_DESCEND_SPEED: float = 220.0
const CEILING_SLAM_RISE_SPEED: float = 1700.0


# -------------------------------------------------------------------
# Recovery / behavior
# -------------------------------------------------------------------

const REST_MIN_DURATION: float = 1.0
const REST_MAX_DURATION: float = 1.55

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

const MIN_ROCK_COUNT: int = 3
const MAX_ROCK_COUNT: int = 5

const ROCK_INITIAL_SPEED: float = 80.0

const ROCK_MIN_DELAY: float = 2.2
const ROCK_MAX_DELAY: float = 3.0


# -------------------------------------------------------------------
# Screen shake
# -------------------------------------------------------------------

const GROUND_SLAM_SHAKE_STRENGTH: float = 9.0
const GROUND_SLAM_SHAKE_DURATION: float = 0.18

const CEILING_SLAM_SHAKE_STRENGTH: float = 10.0
const CEILING_SLAM_SHAKE_DURATION: float = 0.2

const DEATH_SHAKE_STRENGTH: float = 14.0
const DEATH_SHAKE_DURATION: float = 0.3

const INACTIVE_MODULATE := Color(0.5, 0.5, 0.5, 1.0)
const DEFEATED_MODULATE := Color(0.3, 0.3, 0.3, 1.0)

const DEATH_FALL_GRAVITY: float = 2200.0
const DEATH_FALL_MAX_SPEED: float = 1600.0
# -------------------------------------------------------------------
# Procedural animation
# -------------------------------------------------------------------

const BASE_SPIN_SPEED: float = 1.2

const LUNGE_SPIN_SPEED: float = 12.0
const SLAM_SPIN_SPEED: float = 10.0
const FOLLOW_SPIN_SPEED: float = 20.0

const SLAM_IMPACT_SCALE_X: float = 0.80
const SLAM_IMPACT_SCALE_Y: float = 1.20
const SLAM_IMPACT_DURATION: float = 0.12

const LUNGE_SCALE_X: float = 1.05
const LUNGE_SCALE_Y: float = 0.95

const FOLLOW_SCALE_X: float = 1.02
const FOLLOW_SCALE_Y: float = 0.98

const MOVEMENT_SCALE_SMOOTHING: float = 14.0


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

var slam_impact_timer: float = 0.0

var base_sprite_scale: Vector2 = Vector2.ONE

# Assigned by BossEncounter.
var rock_spawn_area: Area2D = null

# Every FallingRock spawned by this boss is tracked here.
var spawned_rocks: Array[Node] = []


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var effect_sprite_2d: AnimatedSprite2D = $EffectSprite2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var killzone: Area2D = $Killzone
@onready var killzone_collision: CollisionShape2D = $Killzone/CollisionShape2D
@onready var damage_timer: Timer = $Killzone/DamageTimer

@onready var ground_slam_hitbox: Area2D = $GroundSlamHitbox
@onready var ground_slam_collision: CollisionShape2D = (
	$GroundSlamHitbox/CollisionShape2D
)

@onready var slam_sound: AudioStreamPlayer2D = $Sound/SlamSound
@onready var charge_sound: AudioStreamPlayer2D = $Sound/ChargeSound


func _ready() -> void:
	add_to_group("enemies")

	base_sprite_scale = animated_sprite_2d.scale

	active = false
	is_dying = false
	death_started = false

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = INACTIVE_MODULATE
	animated_sprite_2d.scale = base_sprite_scale
	animated_sprite_2d.rotation = 0.0

	effect_sprite_2d.visible = false

	if not effect_sprite_2d.animation_finished.is_connected(
		_on_effect_animation_finished
	):
		effect_sprite_2d.animation_finished.connect(
			_on_effect_animation_finished
	)

	_set_combat_active(false)

	state = State.INACTIVE

	set_physics_process(false)


# -------------------------------------------------------------------
# Effect animation
# -------------------------------------------------------------------

func _play_effect(animation_name: String) -> void:
	if effect_sprite_2d == null:
		return

	if effect_sprite_2d.sprite_frames == null:
		return

	if not effect_sprite_2d.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"GuidingSuperstar: EffectSprite2D has no animation named '"
			+ animation_name
			+ "'."
		)
		return

	effect_sprite_2d.visible = true
	effect_sprite_2d.play(animation_name)


func _stop_effect() -> void:
	if effect_sprite_2d == null:
		return

	effect_sprite_2d.stop()
	effect_sprite_2d.visible = false


func _on_effect_animation_finished() -> void:
	if effect_sprite_2d == null:
		return

	effect_sprite_2d.visible = false


func _play_slam_sound() -> void:
	if slam_sound == null:
		return

	slam_sound.play()


func _play_charge_sound() -> void:
	if charge_sound == null:
		return

	charge_sound.play()


# -------------------------------------------------------------------
# BossEncounter interface
# -------------------------------------------------------------------

func set_rock_spawn_area(area: Area2D) -> void:
	rock_spawn_area = area


func boss_entrance_awaken() -> void:
	if death_started:
		return

	active = false
	is_dying = false

	_set_combat_active(false)
	_stop_effect()

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = INACTIVE_MODULATE

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
		base_sprite_scale * 1.04,
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

	_stop_effect()

	animated_sprite_2d.scale = base_sprite_scale

	_set_combat_active(true)

	set_physics_process(true)


func deactivate_boss() -> void:
	active = false

	velocity = Vector2.ZERO
	state = State.INACTIVE

	_stop_effect()

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

	slam_impact_timer = 0.0

	_cleanup_spawned_rocks()

	_stop_effect()

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = INACTIVE_MODULATE
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
	var player_node: Node = get_tree().get_first_node_in_group(
		"player"
	)

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
					player.global_position
					+ Vector2(
						0.0,
						-48.0
					)
				)
			else:
				attack_direction = Vector2.RIGHT

			_play_effect("charge")
			_play_charge_sound()

		State.GROUND_SLAM:
			last_attack = State.GROUND_SLAM

		State.CEILING_SLAM:
			last_attack = State.CEILING_SLAM

		State.REPOSITION:
			last_attack = State.REPOSITION

			if player:
				var side: float = sign(
					global_position.x
					- player.global_position.x
				)

				if side == 0.0:
					side = 1.0

				var vertical_offset: float = 0.0

				if _player_vertical_difference() < -100.0:
					vertical_offset = 120.0

				reposition_target = (
					player.global_position
					+ Vector2(
						side * 320.0,
						vertical_offset
					)
				)

		State.FOLLOW_SPIN:
			last_attack = State.FOLLOW_SPIN

			_play_effect("charge")
			_play_charge_sound()

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

	_add_attack_choice(
		weights,
		State.LUNGE,
		25.0
	)

	_add_attack_choice(
		weights,
		State.GROUND_SLAM,
		15.0
	)

	_add_attack_choice(
		weights,
		State.CEILING_SLAM,
		15.0
	)

	_add_attack_choice(
		weights,
		State.REPOSITION,
		20.0
	)

	_add_attack_choice(
		weights,
		State.FOLLOW_SPIN,
		25.0
	)

	if distance <= CLOSE_RANGE:
		_add_attack_choice(
			weights,
			State.LUNGE,
			30.0
		)

		_add_attack_choice(
			weights,
			State.FOLLOW_SPIN,
			10.0
		)

	if distance >= FAR_RANGE:
		_add_attack_choice(
			weights,
			State.REPOSITION,
			30.0
		)

		_add_attack_choice(
			weights,
			State.FOLLOW_SPIN,
			20.0
		)

	if (
		player_ground_time >= GROUND_BEHAVIOR_THRESHOLD
		and abs(vertical_difference) <= 240.0
	):
		_add_attack_choice(
			weights,
			State.GROUND_SLAM,
			55.0
		)

	if (
		player_air_time >= AIR_BEHAVIOR_THRESHOLD
		and vertical_difference <= -HIGH_PLAYER_DISTANCE
	):
		_add_attack_choice(
			weights,
			State.CEILING_SLAM,
			65.0
		)

	var filtered: Array = []

	for choice: Array in weights:
		var choice_state: State = choice[0]

		if choice_state != last_attack:
			filtered.append(choice)

	if filtered.is_empty():
		filtered = weights

	var selected_state: State = _weighted_random_choice(
		filtered
	)

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
	if state_time < LUNGE_RECOIL_START:
		velocity = Vector2.ZERO

		_set_visual_scale(
			Vector2(
				LUNGE_SCALE_X,
				LUNGE_SCALE_Y
			),
			delta
		)

		animated_sprite_2d.rotation += (
			LUNGE_SPIN_SPEED * delta
		)

		return

	if state_time < LUNGE_WINDUP:
		var recoil_direction: Vector2 = -attack_direction

		velocity = recoil_direction * LUNGE_RECOIL_SPEED

		move_and_slide()

		_set_visual_scale(
			Vector2(
				LUNGE_SCALE_X,
				LUNGE_SCALE_Y
			),
			delta
		)

		animated_sprite_2d.rotation += (
			LUNGE_SPIN_SPEED * delta
		)

		return

	var lunge_time: float = (
		state_time - LUNGE_WINDUP
	)

	if lunge_time < LUNGE_DURATION:
		velocity = attack_direction * LUNGE_SPEED

		move_and_slide()

		_set_visual_scale(
			Vector2(
				LUNGE_SCALE_X,
				LUNGE_SCALE_Y
			),
			delta
		)

		animated_sprite_2d.rotation += (
			LUNGE_SPIN_SPEED * 1.25 * delta
		)

		return

	velocity = Vector2.ZERO
	_change_state(State.REST)


# -------------------------------------------------------------------
# GROUND SLAM
# -------------------------------------------------------------------

func _state_ground_slam(delta: float) -> void:
	if state_time < GROUND_SLAM_WINDUP:
		velocity = Vector2(
			0.0,
			-GROUND_SLAM_RISE_SPEED
		)

		move_and_slide()

		animated_sprite_2d.rotation += (
			SLAM_SPIN_SPEED * delta
		)

		return

	velocity = Vector2(
		0.0,
		GROUND_SLAM_FALL_SPEED
	)

	var collision: KinematicCollision2D = move_and_collide(
		velocity * delta
	)

	animated_sprite_2d.rotation += (
		SLAM_SPIN_SPEED * 1.15 * delta
	)

	if collision != null:
		var collision_normal: Vector2 = (
			collision.get_normal()
		)

		if collision_normal.y < -0.5:
			_ground_slam_impact()
			_change_state(State.REST)


func _ground_slam_impact() -> void:
	if attack_impact_done:
		return

	attack_impact_done = true
	velocity = Vector2.ZERO

	_play_effect("slam")
	_play_slam_sound()

	slam_impact_timer = SLAM_IMPACT_DURATION

	ground_slam_hitbox.set_deferred(
		"monitoring",
		true
	)

	ground_slam_hitbox.set_deferred(
		"monitorable",
		true
	)

	ground_slam_collision.set_deferred(
		"disabled",
		false
	)

	await get_tree().physics_frame

	if not is_instance_valid(self):
		return

	for body in ground_slam_hitbox.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue

		# Damage the player
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call(
					"take_damage",
					GROUND_SLAM_DAMAGE
				)

		# Damage enemies
		elif body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				body.call(
					"take_damage",
					GROUND_SLAM_DAMAGE
				)

		# Trigger slam-reactive objects
		elif body is CollisionObject2D:
			var collision_object: CollisionObject2D = (
				body as CollisionObject2D
			)

			if (
				collision_object.collision_layer
				& (1 << 6)
			) != 0:
				if body.has_method("slam"):
					body.call("slam")

	ground_slam_hitbox.set_deferred(
		"monitoring",
		false
	)

	ground_slam_collision.set_deferred(
		"disabled",
		true
	)

	var shockwave: ShockwaveEffect = ShockwaveEffect.new()

	shockwave.setup(
		GROUND_SLAM_RADIUS
	)

	var scene: Node = get_tree().current_scene

	if scene != null:
		scene.add_child(shockwave)

		shockwave.global_position = (
			global_position
			+ Vector2(
				0.0,
				35.0
			)
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
		velocity = Vector2(
			0.0,
			CEILING_SLAM_DESCEND_SPEED
		)

		move_and_slide()

		animated_sprite_2d.rotation += (
			SLAM_SPIN_SPEED * delta
		)

		return

	velocity = Vector2(
		0.0,
		-CEILING_SLAM_RISE_SPEED
	)

	var collision: KinematicCollision2D = move_and_collide(
		velocity * delta
	)

	animated_sprite_2d.rotation += (
		SLAM_SPIN_SPEED * 1.15 * delta
	)

	if collision != null:
		var collision_normal: Vector2 = (
			collision.get_normal()
		)

		if collision_normal.y > 0.5:
			_ceiling_slam_impact()
			_change_state(State.REST)


func _ceiling_slam_impact() -> void:
	if attack_impact_done:
		return

	attack_impact_done = true
	velocity = Vector2.ZERO

	_play_effect("slam")
	_play_slam_sound()

	slam_impact_timer = SLAM_IMPACT_DURATION

	_spawn_falling_rocks()

	_camera_shake(
		CEILING_SLAM_SHAKE_STRENGTH,
		CEILING_SLAM_SHAKE_DURATION
	)


func _spawn_falling_rocks() -> void:
	if rock_spawn_area == null:
		push_warning(
			"GuidingSuperstar: No RockSpawnArea was assigned."
		)
		return

	var scene: Node = get_tree().current_scene

	if scene == null:
		return

	var shape_node: CollisionShape2D = (
		rock_spawn_area.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
	)

	if shape_node == null:
		push_warning(
			"GuidingSuperstar: RockSpawnArea needs a "
			+ "CollisionShape2D."
		)
		return

	var rectangle: RectangleShape2D = (
		shape_node.shape as RectangleShape2D
	)

	if rectangle == null:
		push_warning(
			"GuidingSuperstar: RockSpawnArea CollisionShape2D "
			+ "must use a RectangleShape2D."
		)
		return

	var rock_scene: PackedScene = preload(
		"res://src/enemies/falling_rock.tscn"
	)

	var rock_count: int = randi_range(
		MIN_ROCK_COUNT,
		MAX_ROCK_COUNT
	)

	var center: Vector2 = shape_node.global_position
	var half_width: float = rectangle.size.x * 0.5

	const EDGE_MARGIN: float = 40.0

	var left_x: float = (
		center.x
		- half_width
		+ EDGE_MARGIN
	)

	var right_x: float = (
		center.x
		+ half_width
		- EDGE_MARGIN
	)

	if right_x <= left_x:
		push_warning(
			"GuidingSuperstar: RockSpawnArea is too narrow."
		)
		return

	var spawn_positions: Array[Vector2] = []

	for i: int in range(rock_count):
		var t: float = 0.5

		if rock_count > 1:
			t = float(i) / float(rock_count - 1)

		var x: float = lerp(
			left_x,
			right_x,
			t
		)

		x += randf_range(
			-60.0,
			60.0
		)

		x = clamp(
			x,
			left_x,
			right_x
		)

		spawn_positions.append(
			Vector2(
				x,
				center.y
			)
		)

	spawn_positions.shuffle()

	for spawn_position: Vector2 in spawn_positions:
		var rock: FallingRock = (
			rock_scene.instantiate()
			as FallingRock
		)

		if rock == null:
			continue

		var delay: float = randf_range(
			ROCK_MIN_DELAY,
			ROCK_MAX_DELAY
		)

		scene.add_child(rock)

		spawned_rocks.append(rock)

		rock.setup(
			spawn_position,
			delay,
			ROCK_INITIAL_SPEED + randf_range(
				-20.0,
				40.0
			),
			CEILING_SLAM_DAMAGE
		)


# -------------------------------------------------------------------
# REPOSITION
# -------------------------------------------------------------------

func _state_reposition(delta: float) -> void:
	if state_time < REPOSITION_WINDUP:
		velocity = Vector2.ZERO
		animated_sprite_2d.scale = base_sprite_scale
		return

	var move_time: float = (
		state_time - REPOSITION_WINDUP
	)

	if move_time < REPOSITION_DURATION:
		var direction: Vector2 = global_position.direction_to(
			reposition_target
		)

		velocity = direction * REPOSITION_SPEED

		move_and_slide()

		animated_sprite_2d.scale = base_sprite_scale

		animated_sprite_2d.rotation += (
			BASE_SPIN_SPEED * delta
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

		_set_visual_scale(
			Vector2(
				FOLLOW_SCALE_X,
				FOLLOW_SCALE_Y
			),
			delta
		)

		animated_sprite_2d.rotation += (
			FOLLOW_SPIN_SPEED * delta
		)

		return

	var chase_time: float = (
		state_time - FOLLOW_SPIN_WINDUP
	)

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

		_set_visual_scale(
			Vector2(
				FOLLOW_SCALE_X,
				FOLLOW_SCALE_Y
			),
			delta
		)

		animated_sprite_2d.rotation += (
			FOLLOW_SPIN_SPEED * delta
		)

		return

	velocity = Vector2.ZERO
	_change_state(State.REST)


# -------------------------------------------------------------------
# Visual animation
# -------------------------------------------------------------------

func _update_visual_animation(delta: float) -> void:
	if slam_impact_timer > 0.0:
		slam_impact_timer -= delta

		var impact_progress: float = clamp(
			slam_impact_timer
			/ SLAM_IMPACT_DURATION,
			0.0,
			1.0
		)

		var impact_scale: Vector2 = Vector2(
			lerp(
				1.0,
				SLAM_IMPACT_SCALE_X,
				impact_progress
			),
			lerp(
				1.0,
				SLAM_IMPACT_SCALE_Y,
				impact_progress
			)
		)

		animated_sprite_2d.scale = (
			base_sprite_scale * impact_scale
		)

	else:
		match state:
			State.LUNGE:
				pass

			State.FOLLOW_SPIN:
				pass

			State.REPOSITION:
				animated_sprite_2d.scale = base_sprite_scale

			_:
				animated_sprite_2d.scale = base_sprite_scale

	if flash_timer > 0.0:
		flash_timer -= delta

		if flash_timer <= 0.0 and not death_started:
			animated_sprite_2d.modulate = Color.WHITE


func _set_visual_scale(
	scale_multiplier: Vector2,
	delta: float
) -> void:
	var smoothing: float = 1.0 - exp(
		-MOVEMENT_SCALE_SMOOTHING * delta
	)

	var target_scale: Vector2 = (
		base_sprite_scale * scale_multiplier
	)

	animated_sprite_2d.scale = animated_sprite_2d.scale.lerp(
		target_scale,
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


# -------------------------------------------------------------------
# FallingRock cleanup
# -------------------------------------------------------------------

func _cleanup_spawned_rocks() -> void:
	for rock: Node in spawned_rocks:
		if is_instance_valid(rock):
			rock.queue_free()

	spawned_rocks.clear()


# -------------------------------------------------------------------
# Death
# -------------------------------------------------------------------

func die() -> void:
	if death_started:
		return

	death_started = true
	active = false
	state = State.DEAD
	velocity = Vector2.ZERO

	_cleanup_spawned_rocks()

	if ground_slam_hitbox:
		ground_slam_hitbox.set_deferred(
			"monitoring",
			false
		)

	if ground_slam_collision:
		ground_slam_collision.set_deferred(
			"disabled",
			true
		)

	_set_combat_active(false)
	_stop_effect()
	set_physics_process(false)

	# Keep the body's physical collision shape active so it can
	# land on the boss floor below — _set_combat_active(false)
	# above disables it along with the hurtbox/hitboxes.
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	_camera_shake(
		DEATH_SHAKE_STRENGTH,
		DEATH_SHAKE_DURATION
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		animated_sprite_2d,
		"scale",
		base_sprite_scale * 1.08,
		0.15
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.parallel().tween_property(
		animated_sprite_2d,
		"modulate",
		DEFEATED_MODULATE,
		0.4
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	await tween.finished

	await _fall_to_boss_floor()

	_stop_effect()

	is_dying = true

func _fall_to_boss_floor() -> void:
	velocity = Vector2.ZERO

	var elapsed := 0.0
	var max_fall_time := 5.0

	while elapsed < max_fall_time:
		var delta := get_physics_process_delta_time()

		velocity.y = min(
			velocity.y + DEATH_FALL_GRAVITY * delta,
			DEATH_FALL_MAX_SPEED
		)

		var collision := move_and_collide(velocity * delta)

		if collision != null and collision.get_normal().y < -0.5:
			velocity = Vector2.ZERO
			return

		elapsed += delta

		await get_tree().physics_frame

	velocity = Vector2.ZERO
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

	if ground_slam_hitbox:
		ground_slam_hitbox.set_deferred(
			"monitoring",
			false
		)

	if ground_slam_collision:
		ground_slam_collision.set_deferred(
			"disabled",
			true
		)


# -------------------------------------------------------------------
# Camera
# -------------------------------------------------------------------

func _camera_shake(
	strength: float,
	duration: float
) -> void:
	var player_node: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

	if player_node == null:
		return

	if player_node.has_method("camera_shake"):
		player_node.call(
			"camera_shake",
			strength * 1.2,
			duration * 1.3
		)
