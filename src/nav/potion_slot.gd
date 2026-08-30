extends Area2D
class_name PotionSlot

## One-time pickup unlocking a single Wondrous Star Potion mixing
## slot (Survival / Combat / Utility). Exactly three of these exist
## in the world — set `category` per instance in the Inspector.
##
## This does NOT grant an effect. Effects unlock separately through
## lifetime star fragment totals (see GameState.potion_effect_data).
## Picking this up only opens the category so an already-unlocked
## effect can be loaded into it at a checkpoint.
##
## Scene children expected:
##   Sprite2D
##   CollisionShape2D
##   PromptPanel
##       Label
##   PickupSound (optional AudioStreamPlayer2D)
##
## The pickup uses a 64x64 white Sprite2D.
## It gently pulses and has a visible white glow while sitting.
## On collection, it flashes, expands, then disappears.

@export_enum("survival", "combat", "utility") var category: String = "survival"
@export var prompt_panel: Panel

@onready var visual: Sprite2D = $Sprite2D
@onready var pickup_sound: AudioStreamPlayer2D = (
	$PickupSound if has_node("PickupSound") else null
)

var activated: bool = false
var player_inside: bool = false

var pulse_time: float = 0.0
var pulse_speed: float = 2.4

var visual_base_scale: Vector2 = Vector2.ONE

var glow: Sprite2D
var glow_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.is_potion_slot_unlocked(category):
		queue_free()
		return

	visual.visible = true
	visual.modulate = Color.WHITE
	visual_base_scale = visual.scale

	_create_glow()


func _process(delta: float) -> void:
	if activated:
		return

	pulse_time += delta * pulse_speed

	var pulse: float = (
		sin(pulse_time) + 1.0
	) * 0.5

	var pickup_scale: float = lerp(
		0.97,
		1.04,
		pulse
	)

	visual.scale = visual_base_scale * pickup_scale

	if is_instance_valid(glow):
		var glow_scale: float = lerp(
			0.51,
			0.69,
			pulse
		)

		glow.scale = glow_base_scale * glow_scale

		glow.modulate.a = lerp(
			0.27,
			0.51,
			pulse
		)

	if player_inside and Input.is_action_just_pressed("interact"):
		_collect()


func _create_glow() -> void:
	glow = Sprite2D.new()
	glow.name = "PotionGlow"

	glow.position = visual.position
	glow.z_index = 0

	visual.z_index = 1

	var gradient: Gradient = Gradient.new()

	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.57),
		Color(1.0, 1.0, 1.0, 0.39),
		Color(1.0, 1.0, 1.0, 0.15),
		Color(1.0, 1.0, 1.0, 0.0)
	])

	gradient.offsets = PackedFloat32Array([
		0.0,
		0.18,
		0.45,
		1.0
	])

	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_texture.height = 256
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)

	glow.texture = gradient_texture
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.centered = true

	glow.scale = Vector2(0.45, 0.45)
	glow_base_scale = glow.scale

	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material

	add_child(glow)
	move_child(glow, 0)


func _collect() -> void:
	if activated:
		return

	activated = true
	player_inside = false

	if prompt_panel:
		prompt_panel.hide()

	GameState.unlock_potion_slot(category)

	set_process(false)

	if pickup_sound:
		pickup_sound.play()

	visual.modulate = Color(
		3.0,
		3.0,
		3.0,
		1.0
	)

	if is_instance_valid(glow):
		glow.modulate = Color(
			1.0,
			1.0,
			1.0,
			0.6
		)

	var shine: Tween = create_tween()
	shine.set_parallel(true)

	shine.tween_property(
		visual,
		"scale",
		visual_base_scale * 1.35,
		0.16
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	shine.tween_property(
		visual,
		"modulate",
		Color(
			5.0,
			5.0,
			5.0,
			1.0
		),
		0.08
	)

	if is_instance_valid(glow):
		shine.tween_property(
			glow,
			"scale",
			glow_base_scale * 1.2,
			0.20
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)

	await get_tree().create_timer(0.18).timeout

	var disappear: Tween = create_tween()
	disappear.set_parallel(true)

	disappear.tween_property(
		visual,
		"scale",
		visual_base_scale * 0.7,
		0.18
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_IN
	)

	disappear.tween_property(
		visual,
		"modulate:a",
		0.0,
		0.18
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	if is_instance_valid(glow):
		disappear.tween_property(
			glow,
			"scale",
			glow_base_scale * 0.15,
			0.22
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN
		)

		disappear.tween_property(
			glow,
			"modulate:a",
			0.0,
			0.22
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN
		)

	await get_tree().create_timer(0.23).timeout

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()

	var tween: Tween = create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		1.0,
		0.25
	)


func _on_area_exited(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		0.0,
		0.25
	)

	tween.tween_callback(
		prompt_panel.hide
	)
