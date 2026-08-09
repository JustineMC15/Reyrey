extends CharacterBody2D
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

@onready var slash_effect = $SlashEffect
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == "attack":
		is_attacking = false
		slash_effect.stop()
		slash_effect.visible = false
func _ready() -> void:
	floor_snap_length = 9.0
	slash_effect.visible = false
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
	elif direction < 0:
		animated_sprite_2d.flip_h = true

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
		animated_sprite_2d.play("attack")

		slash_effect.visible = true
		slash_effect.flip_h = animated_sprite_2d.flip_h
		slash_effect.play("slash")
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
