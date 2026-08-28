extends CharacterBody2D
class_name FallingRock


enum RockShape {
	SMALL,
	MEDIUM,
	LARGE,
	JAGGED,
	LONG
}


const DEFAULT_GRAVITY: float = 1800.0
const DEFAULT_DAMAGE: int = 1

const TELEGRAPH_SMOKE_HEIGHT: float = 420.0
const TELEGRAPH_WIDTH: float = 34.0
const TELEGRAPH_PARTICLES: int = 14

const BREAK_DURATION: float = 0.14
const BREAK_PARTICLE_COUNT: int = 8


var shape_type: int = RockShape.MEDIUM

var fall_delay: float = 2.5
var fall_speed: float = 120.0
var gravity: float = DEFAULT_GRAVITY
var damage: int = DEFAULT_DAMAGE

var rock_scale: float = 1.0
var rotation_speed: float = 0.0

var elapsed: float = 0.0
var break_timer: float = 0.0

var is_falling: bool = false
var is_breaking: bool = false
var has_hit_player: bool = false

var telegraph_time: float = 0.0


@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D


func _ready() -> void:
	_generate_rock_properties()
	_setup_collision()

	telegraph_time = fall_delay

	collision_shape.set_deferred("disabled", true)
	damage_collision.set_deferred("disabled", true)

	queue_redraw()


func setup(
	start_pos: Vector2,
	delay: float,
	initial_speed: float,
	damage_amount: int
) -> void:
	global_position = start_pos
	fall_delay = delay
	fall_speed = initial_speed
	damage = damage_amount
	telegraph_time = delay


func trigger() -> void:
	telegraph_time = fall_delay


func _generate_rock_properties() -> void:
	var shape_index: int = randi_range(
		RockShape.SMALL,
		RockShape.LONG
	)

	shape_type = shape_index

	rock_scale = randf_range(0.8, 1.25)
	rotation = randf_range(0.0, TAU)
	rotation_speed = randf_range(-3.0, 3.0)

	match shape_type:
		RockShape.SMALL:
			rock_scale *= 0.75
			fall_speed *= 1.15

		RockShape.MEDIUM:
			pass

		RockShape.LARGE:
			rock_scale *= 1.25
			fall_speed *= 0.8

		RockShape.JAGGED:
			rock_scale *= 1.1
			fall_speed *= 0.95

		RockShape.LONG:
			rock_scale *= 1.15
			fall_speed *= 0.9


func _setup_collision() -> void:
	var rock_shape: CircleShape2D = CircleShape2D.new()
	var damage_shape: CircleShape2D = CircleShape2D.new()

	match shape_type:
		RockShape.SMALL:
			rock_shape.radius = 14.0
			damage_shape.radius = 15.0

		RockShape.MEDIUM:
			rock_shape.radius = 20.0
			damage_shape.radius = 21.0

		RockShape.LARGE:
			rock_shape.radius = 28.0
			damage_shape.radius = 29.0

		RockShape.JAGGED:
			rock_shape.radius = 24.0
			damage_shape.radius = 25.0

		RockShape.LONG:
			rock_shape.radius = 18.0
			damage_shape.radius = 20.0

	collision_shape.shape = rock_shape
	damage_collision.shape = damage_shape


func _physics_process(delta: float) -> void:
	if is_breaking:
		_process_breaking(delta)
		return

	elapsed += delta

	if is_falling:
		_process_falling(delta)
	else:
		_process_telegraph(delta)


func _process_telegraph(delta: float) -> void:
	telegraph_time -= delta

	queue_redraw()

	if telegraph_time <= 0.0:
		_begin_falling()


func _begin_falling() -> void:
	if is_falling or is_breaking:
		return

	is_falling = true

	collision_shape.set_deferred("disabled", false)
	damage_collision.set_deferred("disabled", false)

	queue_redraw()


func _process_falling(delta: float) -> void:
	fall_speed += gravity * delta

	velocity = Vector2(
		0.0,
		fall_speed
	)

	var collision: KinematicCollision2D = move_and_collide(
		velocity * delta
	)

	if collision != null:
		_break()
		return

	rotation += rotation_speed * delta

	_check_player_hit()

	queue_redraw()


func _check_arena_collision() -> void:
	pass
func _check_player_hit() -> void:
	if has_hit_player:
		return

	for body in damage_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call(
					"take_damage",
					damage
				)

			has_hit_player = true
			break


func _break() -> void:
	if is_breaking:
		return

	is_breaking = true
	break_timer = BREAK_DURATION

	velocity = Vector2.ZERO

	collision_shape.set_deferred("disabled", true)
	damage_collision.set_deferred("disabled", true)

	queue_redraw()


func _process_breaking(delta: float) -> void:
	break_timer -= delta

	if break_timer <= 0.0:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	if is_breaking:
		_draw_break()
		return

	if not is_falling:
		_draw_smoke_telegraph()
		return

	_draw_rock()


func _draw_smoke_telegraph() -> void:
	var progress: float = clamp(
		1.0 - telegraph_time / max(fall_delay, 0.01),
		0.0,
		1.0
	)

	var pulse: float = 0.65 + sin(
		Time.get_ticks_msec() * 0.006
	) * 0.08

	var opacity: float = lerp(
		0.15,
		0.32,
		progress
	)

	for i: int in range(TELEGRAPH_PARTICLES):
		var t: float = float(i) / float(TELEGRAPH_PARTICLES - 1)

		var y: float = lerp(
			0.0,
			TELEGRAPH_SMOKE_HEIGHT,
			t
		)

		var drift: float = sin(
			Time.get_ticks_msec() * 0.0015
			+ float(i) * 1.7
		) * 12.0

		var width: float = lerp(
			10.0,
			TELEGRAPH_WIDTH,
			sin(t * PI)
		)

		var local_alpha: float = (
			opacity
			* pulse
			* (1.0 - t * 0.35)
		)

		draw_circle(
			Vector2(
				drift,
				y
			),
			width,
			Color(
				0.65,
				0.62,
				0.58,
				local_alpha
			)
		)


func _draw_rock() -> void:
	var points: PackedVector2Array

	match shape_type:
		RockShape.SMALL:
			points = PackedVector2Array([
				Vector2(0.0, -14.0),
				Vector2(11.0, -4.0),
				Vector2(8.0, 10.0),
				Vector2(-7.0, 11.0),
				Vector2(-12.0, -3.0)
			])

		RockShape.MEDIUM:
			points = PackedVector2Array([
				Vector2(0.0, -20.0),
				Vector2(15.0, -9.0),
				Vector2(19.0, 8.0),
				Vector2(7.0, 21.0),
				Vector2(-15.0, 17.0),
				Vector2(-20.0, -4.0)
			])

		RockShape.LARGE:
			points = PackedVector2Array([
				Vector2(0.0, -27.0),
				Vector2(20.0, -13.0),
				Vector2(25.0, 10.0),
				Vector2(10.0, 29.0),
				Vector2(-20.0, 24.0),
				Vector2(-28.0, -4.0),
				Vector2(-15.0, -23.0)
			])

		RockShape.JAGGED:
			points = PackedVector2Array([
				Vector2(0.0, -28.0),
				Vector2(10.0, -13.0),
				Vector2(25.0, -15.0),
				Vector2(15.0, 2.0),
				Vector2(23.0, 19.0),
				Vector2(5.0, 13.0),
				Vector2(-10.0, 27.0),
				Vector2(-12.0, 7.0),
				Vector2(-26.0, 12.0),
				Vector2(-19.0, -8.0),
				Vector2(-7.0, -9.0)
			])

		RockShape.LONG:
			points = PackedVector2Array([
				Vector2(-10.0, -28.0),
				Vector2(8.0, -25.0),
				Vector2(13.0, 26.0),
				Vector2(-12.0, 29.0)
			])

	var transformed_points: PackedVector2Array = PackedVector2Array()

	for point: Vector2 in points:
		transformed_points.append(
			point * rock_scale
		)

	draw_colored_polygon(
		transformed_points,
		Color(
			0.22,
			0.19,
			0.17,
			1.0
		)
	)

	draw_polyline(
		transformed_points + PackedVector2Array([
			transformed_points[0]
		]),
		Color(
			0.05,
			0.04,
			0.04,
			1.0
		),
		4.0,
		true
	)


func _draw_break() -> void:
	var progress: float = 1.0 - (
		break_timer / BREAK_DURATION
	)

	var radius: float = lerp(
		8.0,
		42.0,
		progress
	)

	for i: int in range(BREAK_PARTICLE_COUNT):
		var angle: float = (
			float(i)
			/ float(BREAK_PARTICLE_COUNT)
		) * TAU

		var direction: Vector2 = Vector2.from_angle(angle)

		draw_line(
			direction * 4.0,
			direction * radius,
			Color(
				0.35,
				0.32,
				0.29,
				1.0 - progress
			),
			3.0,
			true
		)
