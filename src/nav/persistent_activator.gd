## ChurchBrazier (Area2D) or whatever name
## ├── CollisionShape2D
## ├── AnimatedSprite2D
## └── PromptPanel

extends Area2D
class_name PersistentActivator

@export var activation_id: String = ""
@export var prompt_panel: Panel

@export_category("Animation")
@export var inactive_animation: String = ""
@export var active_animation: String = ""

var player_inside := false
var activated := false
var animated_sprite: AnimatedSprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if has_node("AnimatedSprite2D"):
		animated_sprite = $AnimatedSprite2D

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	activated = GameState.is_activation_active(activation_id)
	_refresh_visual()

	GameState.activation_changed.connect(_on_activation_changed)


func _process(_delta: float) -> void:
	if activated or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		_activate()


func _activate() -> void:
	if activated:
		return

	activated = true
	player_inside = false

	GameState.activate_persistent_object(activation_id)

	if prompt_panel:
		prompt_panel.hide()

	_refresh_visual()


func _refresh_visual() -> void:
	if animated_sprite == null:
		return

	if activated:
		if active_animation != "":
			animated_sprite.play(active_animation)
	else:
		if inactive_animation != "":
			animated_sprite.animation = inactive_animation
			animated_sprite.stop()
			animated_sprite.frame = 0


func _on_activation_changed(changed_id: String) -> void:
	if changed_id != activation_id:
		return

	activated = GameState.is_activation_active(activation_id)
	_refresh_visual()


func _on_area_entered(area: Area2D) -> void:
	if activated or not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()

	var tween := create_tween()
	tween.tween_property(
		prompt_panel,
		"modulate:a",
		1.0,
		0.25
	)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween := create_tween()
	tween.tween_property(
		prompt_panel,
		"modulate:a",
		0.0,
		0.25
	)
	tween.tween_callback(prompt_panel.hide)
