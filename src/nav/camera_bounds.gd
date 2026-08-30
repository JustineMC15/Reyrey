@tool
extends Control
class_name CameraBounds

## Defines the room's camera limits. Select this node directly and
## drag its native resize handles in the 2D viewport — same
## mechanism as any Panel/ColorRect in this project. Position and
## size ARE the limit rect. No CollisionShape2D, no manual limit_*
## numbers, no ruler math.
##
## Leave Layout on its default (position + size, no anchors) —
## that's automatic since this node's parent is a plain Node2D room
## root, not a Control container.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if Engine.is_editor_hint():
		if size == Vector2.ZERO:
			size = Vector2(640, 360)  # visible starting size on first add
		set_process(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.4, 0.9, 0.9), false, 3.0)


func get_limits() -> Rect2i:
	var top_left: Vector2 = global_position
	var world_scale: Vector2 = get_global_transform().get_scale().abs()
	var world_size: Vector2 = size * world_scale

	return Rect2i(
		int(top_left.x),
		int(top_left.y),
		int(world_size.x),
		int(world_size.y)
	)
