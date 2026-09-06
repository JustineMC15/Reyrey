@tool
extends Area2D
class_name CameraLimitZone

## Temporarily tightens (or otherwise changes) the room's camera
## limits while the player is standing inside this zone. Use this
## when a "weird shaped" bit of a room — an L-shaped nook, a secret
## side room, a boss arena — would otherwise be visible inside the
## room's normal rectangular CameraBounds: draw this zone's rect
## around the area the camera SHOULD be allowed to show while the
## player is there, and anything outside it simply can't be framed.
##
## Reverts to the room's default CameraBounds when the player exits —
## unless they're still standing inside another overlapping
## CameraLimitZone, in which case that zone's rect takes over instead
## of snapping straight back to the room default.
##
## Camera-limit ownership is fully centralized in Game
## (enter_camera_limit_zone / exit_camera_limit_zone /
## set_camera_limits) — this script only reports its own rect and
## lets Game decide what the camera should actually do. That's what
## guarantees only one tween is ever driving the camera's limits at
## once, so a zone active when you leave a room can never bleed its
## tween into the next one.
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

@export var tween_duration: float = 0.18

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var rect_handle: Control = $RectHandle


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


func _get_limit_rect() -> Rect2i:
	var shape := collision_shape.shape as RectangleShape2D

	if shape == null:
		push_warning("CameraLimitZone '%s' needs a RectangleShape2D." % name)
		return Rect2i()

	var center: Vector2 = collision_shape.global_position
	var half_size: Vector2 = shape.size * 0.5 * collision_shape.global_scale.abs()
	var top_left: Vector2 = center - half_size

	return Rect2i(
		int(top_left.x),
		int(top_left.y),
		int(half_size.x * 2.0),
		int(half_size.y * 2.0)
	)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	var player := area.get_parent()
	var game := player.get_tree().get_first_node_in_group("game")

	if game == null or not game.has_method("enter_camera_limit_zone"):
		return

	game.enter_camera_limit_zone(self, _get_limit_rect(), tween_duration)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	var player := area.get_parent()
	var game := player.get_tree().get_first_node_in_group("game")

	if game == null or not game.has_method("exit_camera_limit_zone"):
		return

	game.exit_camera_limit_zone(self, tween_duration)
