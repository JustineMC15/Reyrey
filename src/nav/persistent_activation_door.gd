extends StaticBody2D
class_name PersistentActivationDoor

@export var required_activation_ids: Array[String] = []

@export_category("Door")
@export var door_visual: CanvasItem

@export_category("Indicators")
@export var indicators: Array[AnimatedSprite2D] = []
@export var inactive_indicator_animation: String = ""
@export var active_indicator_animation: String = ""

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var opened := false


func _ready() -> void:
	GameState.activation_changed.connect(_on_activation_changed)
	_refresh_state()


func _on_activation_changed(_activation_id: String) -> void:
	_refresh_state()


func _refresh_state() -> void:
	var all_active := true

	for i in range(required_activation_ids.size()):
		var activation_id := required_activation_ids[i]
		var active := GameState.is_activation_active(activation_id)

		if not active:
			all_active = false

		if i >= indicators.size():
			continue

		var indicator := indicators[i]

		if active:
			if active_indicator_animation != "":
				indicator.play(active_indicator_animation)
		else:
			if inactive_indicator_animation != "":
				indicator.animation = inactive_indicator_animation
				indicator.stop()
				indicator.frame = 0

	if all_active:
		_open()


func _open() -> void:
	if opened:
		return

	opened = true
	collision_shape.set_deferred("disabled", true)

	if door_visual:
		door_visual.visible = false
