extends CharacterBody2D

@export var enemy_id: String = ""
var base_damage := 1
var max_health := 5
var health := max_health
@export var star_fragment_reward: int = 5
@export var spin_speed: float = 2.0

enum MovementType {
	VERTICAL,
	HORIZONTAL,
	DIAGONAL
}

@export var movement_type: MovementType = MovementType.VERTICAL
@export var movement_distance: float = 50.0
@export var movement_speed: float = 2.0

@export var attack_cooldown: float = 1.5
@export var focus_time: float = 0.5
@export var explosion_time: float = 0.15
@export var fade_time: float = 0.3

var start_position: Vector2
var movement_time: float = 0.0

var is_dying := false
var player: Node2D = null
var is_attacking := false
var attack_position: Vector2

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_effect: AnimatedSprite2D = $DeathEffect
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

@onready var shoot_timer: Timer = $ShootTimer

@onready var pop_attack: Node2D = $PopAttack
@onready var pop_sprite: AnimatedSprite2D = $PopAttack/AnimatedSprite2D
@onready var pop_glow: PointLight2D = $PopAttack/PointLight2D
@onready var attack_sound: AudioStreamPlayer2D = $PopAttack/AttackSound
@onready var pop_hurtbox: Area2D = $PopAttack/Area2D


func _ready() -> void:
	add_to_group("enemies")

	start_position = position

	death_effect.visible = false

	pop_attack.visible = false
	pop_attack.top_level = true

	pop_hurtbox.monitoring = false
	pop_hurtbox.monitorable = false

	pop_glow.enabled = false
	pop_glow.energy = 0.0

	$DetectionArea.area_entered.connect(_on_detection_area_area_entered)
	$DetectionArea.area_exited.connect(_on_detection_area_area_exited)

	pop_hurtbox.body_entered.connect(_on_pop_hurtbox_body_entered)

	shoot_timer.wait_time = attack_cooldown
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	rotation += spin_speed * delta

	movement_time += delta * movement_speed
	var offset := sin(movement_time) * movement_distance

	match movement_type:
		MovementType.VERTICAL:
			position = start_position + Vector2(0, offset)

		MovementType.HORIZONTAL:
			position = start_position + Vector2(offset, 0)

		MovementType.DIAGONAL:
			position = start_position + Vector2(-offset, offset)


func _on_detection_area_area_entered(area: Area2D) -> void:
	if is_dying:
		return

	if not area.is_in_group("player_detection"):
		return

	player = area.get_parent()

	if shoot_timer.is_stopped():
		shoot_timer.start()


func _on_detection_area_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player = null
	shoot_timer.stop()


func _on_shoot_timer_timeout() -> void:
	if is_dying:
		return

	if player == null:
		return

	if is_attacking:
		return

	fire_attack()


func fire_attack() -> void:
	if player == null:
		return

	is_attacking = true

	# Target the middle of the player.
	attack_position = player.global_position + Vector2(0, -63)

	pop_attack.global_position = attack_position
	pop_attack.global_rotation = 0.0
	pop_attack.visible = true

	pop_sprite.visible = true
	pop_sprite.modulate = Color.WHITE
	pop_sprite.scale = Vector2.ONE

	pop_hurtbox.monitoring = false
	pop_hurtbox.monitorable = false

	# Focus / charge
	pop_glow.enabled = true
	pop_glow.energy = 0.0

	pop_sprite.play("focus")

	var focus_glow := create_tween()
	focus_glow.tween_property(
		pop_glow,
		"energy",
		1.5,
		focus_time
	)

	await get_tree().create_timer(focus_time).timeout

	if is_dying:
		return

	# Explosion
	pop_sprite.play("explode")
	attack_sound.play()
	fire_flash()

	# Keep the glow during the explosion.
	pop_glow.energy = 4.0

	pop_hurtbox.monitoring = true
	pop_hurtbox.monitorable = true

	await get_tree().create_timer(explosion_time).timeout

	pop_hurtbox.set_deferred("monitoring", false)
	pop_hurtbox.set_deferred("monitorable", false)

	# Fade sprite and glow together.
	var fade_tween := create_tween()

	fade_tween.parallel().tween_property(
		pop_sprite,
		"modulate:a",
		0.0,
		fade_time
	)

	fade_tween.parallel().tween_property(
		pop_glow,
		"energy",
		0.0,
		fade_time
	)

	await fade_tween.finished

	pop_attack.visible = false
	pop_sprite.stop()
	pop_glow.enabled = false

	is_attacking = false

	if player != null and not is_dying:
		shoot_timer.start()


func fire_flash() -> void:
	var tween := create_tween()

	animated_sprite_2d.modulate = Color(2.5, 2.5, 2.5, 1.0)

	tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color.WHITE,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_pop_hurtbox_body_entered(body: Node2D) -> void:
	if not is_attacking:
		return

	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(base_damage)


func take_damage(amount: int) -> void:
	if is_dying:
		return

	health -= amount

	hit_sound.play()

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
	shoot_timer.stop()

	pop_attack.visible = false

	pop_hurtbox.set_deferred("monitoring", false)
	pop_hurtbox.set_deferred("monitorable", false)

	pop_glow.enabled = false

	animated_sprite_2d.visible = false

	$CollisionShape2D.set_deferred("disabled", true)

	velocity = Vector2.ZERO

	death_effect.visible = true
	death_effect.play("death")

	death_sound.play()

	await death_effect.animation_finished
	death_effect.visible = false
	set_physics_process(false)


func respawn() -> void:
	if not is_dying:
		return

	is_dying = false
	health = max_health
	is_attacking = false
	player = null

	position = start_position
	movement_time = 0.0
	velocity = Vector2.ZERO

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE

	death_effect.visible = false
	death_effect.stop()

	$CollisionShape2D.set_deferred("disabled", false)

	pop_attack.visible = false
	pop_hurtbox.set_deferred("monitoring", false)
	pop_hurtbox.set_deferred("monitorable", false)
	pop_glow.enabled = false
	pop_glow.energy = 0.0

	set_physics_process(true)
