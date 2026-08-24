extends CharacterBody2D
@export var enemy_id: String = ""
var max_health := 4
var health := max_health

@export var spin_speed: float = 2.0
@export var bullet_scene: PackedScene
@export var star_fragment_reward: int = 4
var player: Node2D = null
var is_dying := false

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

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_effect: AnimatedSprite2D = $DeathEffect
@onready var hit_sound: AudioStreamPlayer2D = $HitSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound


func _ready() -> void:
	add_to_group("enemies")
	start_position = position

	death_effect.visible = false

	$DetectionArea.area_entered.connect(_on_detection_area_area_entered)
	$DetectionArea.area_exited.connect(_on_detection_area_area_exited)


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


func take_damage(amount: int) -> void:
	if is_dying:
		return

	health -= amount

	# Play hit sound
	hit_sound.play()

	# Flash enemy
	flash_damage()

	if health <= 0:
		die()


func flash_damage() -> void:
	animated_sprite_2d.modulate = Color(5, 5, 5, 1)

	await get_tree().create_timer(0.1).timeout

	if not is_dying:
		animated_sprite_2d.modulate = Color.WHITE


# Replace die() with:
func die() -> void:
	if is_dying:
		return

	is_dying = true
	GameState.add_star_fragments(star_fragment_reward)

	player = null
	$ShootTimer.stop()
	$DetectionArea.set_deferred("monitoring", false)

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
	player = null

	position = start_position
	movement_time = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0

	animated_sprite_2d.visible = true
	animated_sprite_2d.modulate = Color.WHITE

	death_effect.visible = false
	death_effect.stop()

	$CollisionShape2D.set_deferred("disabled", false)
	$DetectionArea.set_deferred("monitoring", true)

	set_physics_process(true)

func spin_once() -> void:
	var tween = create_tween()

	tween.tween_property(
		self,
		"rotation",
		rotation + TAU,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func fire_flash() -> void:
	var tween = create_tween()

	animated_sprite_2d.modulate = Color(2.5, 1.8, 0.3, 1.0)

	tween.tween_property(
		animated_sprite_2d,
		"modulate",
		Color.WHITE,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_shoot_timer_timeout() -> void:
	if player == null or is_dying:
		return

	$ShootSound.play()
	fire_flash()

	var bullet = bullet_scene.instantiate()

	bullet.global_position = $ShootPoint.global_position
	bullet.direction = (
		(player.global_position + Vector2(0, -48))
		- $ShootPoint.global_position
	).normalized()

	get_tree().current_scene.add_child(bullet)
	

func _on_detection_area_area_entered(area: Area2D) -> void:
	if is_dying:
		return

	if not area.is_in_group("player_detection"):
		return

	player = area.get_parent()
	$ShootTimer.start()


func _on_detection_area_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player = null
	$ShootTimer.stop()
