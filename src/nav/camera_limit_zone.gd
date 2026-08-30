@tool
extends Area2D
class_name CameraLimitZone

## Overrides the room's CameraBounds while the player is inside this
## zone — use it to stop the camera drifting into empty space around
## an L-shaped room, an alcove, etc. Reverts to the room's default
## CameraBounds on exit. Limits are tweened, not set instantly, so
## the camera slides into place instead of snapping.
##
## Select the RectHandle CHILD (not this node) and drag its native
## resize handles to size the zone. This script keeps the
## CollisionShape2D's RectangleShape2D synced to match while in the
## editor. RectHandle is purely an authoring aid — invisible and
## non-interactive at runtime.
##
## Scene: this node IS the Area2D. collision_layer = 32,
## collision_mask = 64 (matches checkpoint.tscn / chest.tscn).
##   CollisionShape2D — RectangleShape2D, kept in sync by this script
##   RectHandle        — Control, drag THIS to resize the zone

@export var tween_duration: float = 0.35

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var rect_handle: Control = $RectHandle

var _tween: Tween


func _ready() -> void:
	if rect_handle:
		rect_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if Engine.is_editor_hint() and rect_handle.size == Vector2.ZERO:
			rect_handle.size = Vector2(200, 200)

	if Engine.is_editor_hint():
		set_process(true)
		return

	if rect_handle:
		rect_handle.hide()

	# Guard against sharing a RectangleShape2D resource across instances.
	if collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	_sync_shape_from_handle()
	queue_redraw()


func _sync_shape_from_handle() -> void:
	if rect_handle == null:
		return

	if not (collision_shape.shape is RectangleShape2D):
		collision_shape.shape = RectangleShape2D.new()

	var shape := collision_shape.shape as RectangleShape2D

	shape.size = rect_handle.size
	collision_shape.position = rect_handle.position + rect_handle.size * 0.5


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var shape := collision_shape.shape as RectangleShape2D if collision_shape else null

	if shape == null:
		return

	var half: Vector2 = shape.size * 0.5
	draw_rect(Rect2(collision_shape.position - half, shape.size), Color(0.3, 0.9, 1.0, 0.9), false, 3.0)


func _get_limit_rect() -> Rect2:
	var shape := collision_shape.shape as RectangleShape2D

	if shape == null:
		push_warning("CameraLimitZone '%s' needs a RectangleShape2D." % name)
		return Rect2()

	var center: Vector2 = collision_shape.global_position
	var half_size: Vector2 = shape.size * 0.5 * collision_shape.global_scale.abs()

	return Rect2(center - half_size, half_size * 2.0)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	var player := area.get_parent()
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	var rect := _get_limit_rect()

	_tween_limits_to(
		camera,
		int(rect.position.x),
		int(rect.position.y),
		int(rect.position.x + rect.size.x),
		int(rect.position.y + rect.size.y)
	)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	var player := area.get_parent()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var game := player.get_tree().get_first_node_in_group("game")

	if camera == null or game == null:
		return

	var bounds: CameraBounds = game.current_room_camera_bounds

	if bounds == null:
		_tween_limits_to(camera, -10000000, -10000000, 10000000, 10000000)
	else:
		var limit_rect := bounds.get_limits()
		_tween_limits_to(
			camera,
			limit_rect.position.x,
			limit_rect.position.y,
			limit_rect.position.x + limit_rect.size.x,
			limit_rect.position.y + limit_rect.size.y
		)


func _tween_limits_to(
	camera: Camera2D,
	target_left: int,
	target_top: int,
	target_right: int,
	target_bottom: int
) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	var start_left := camera.limit_left
	var start_top := camera.limit_top
	var start_right := camera.limit_right
	var start_bottom := camera.limit_bottom

	_tween = camera.create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_method(
		func(t: float):
			camera.limit_left = int(lerp(start_left, target_left, t))
			camera.limit_top = int(lerp(start_top, target_top, t))
			camera.limit_right = int(lerp(start_right, target_right, t))
			camera.limit_bottom = int(lerp(start_bottom, target_bottom, t)),
		0.0,
		1.0,
		tween_duration
	)
