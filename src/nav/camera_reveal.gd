@tool
extends Area2D
class_name CameraRevealZone

## A one-shot camera pan trigger ("camera hint") — walking through
## the threshold shifts the camera's view toward reveal_point,
## holds, then eases back, without moving the player or locking
## their input. Use it to spotlight a secret path, a door opening
## somewhere else, etc.
##
## Select the RectHandle CHILD (not this node) and drag its native
## resize handles to size the trigger area. Drop a Marker2D anywhere
## in the room (drag it like any other node) and assign it to
## reveal_point. A live yellow line is drawn from this zone to that
## marker in the editor so you can see the pan direction/distance
## without playtesting.
##
## Scene: this node IS the Area2D. collision_layer = 32,
## collision_mask = 64 (matches checkpoint.tscn / chest.tscn).
##   CollisionShape2D — the trigger threshold, kept in sync by this script
##   RectHandle        — Control, drag THIS to resize the trigger area

@export var reveal_point: Node2D
@export var pan_out_duration: float = 0.9
@export var hold_duration: float = 1.0
@export var pan_back_duration: float = 0.7
@export var max_offset_distance: float = 900.0
@export var retrigger: bool = false  ## fire every time the player enters, not just once per room visit

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var rect_handle: Control = $RectHandle

var _triggered := false
var _active := false


func _ready() -> void:
	if rect_handle:
		rect_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if Engine.is_editor_hint() and rect_handle.size == Vector2.ZERO:
			rect_handle.size = Vector2(150, 150)

	if Engine.is_editor_hint():
		set_process(true)
		return

	if rect_handle:
		rect_handle.hide()

	if collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()

	area_entered.connect(_on_area_entered)


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

	if shape:
		var half: Vector2 = shape.size * 0.5
		draw_rect(Rect2(collision_shape.position - half, shape.size), Color(1.0, 0.85, 0.3, 0.6), false, 2.0)

	if reveal_point:
		var target_local: Vector2 = to_local(reveal_point.global_position)
		draw_line(Vector2.ZERO, target_local, Color(1.0, 0.85, 0.3, 0.85), 2.0)
		draw_circle(target_local, 10.0, Color(1.0, 0.85, 0.3, 0.5))


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	if _active or (_triggered and not retrigger):
		return

	if reveal_point == null:
		push_warning("CameraRevealZone '%s' has no reveal_point assigned." % name)
		return

	var player := area.get_parent()
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	_triggered = true
	_run_reveal(camera)


func _run_reveal(camera: Camera2D) -> void:
	_active = true

	var base_offset: Vector2 = camera.offset
	var target_offset: Vector2 = reveal_point.global_position - camera.global_position

	if target_offset.length() > max_offset_distance:
		target_offset = target_offset.normalized() * max_offset_distance

	var tween := create_tween()

	tween.tween_property(
		camera, "offset", base_offset + target_offset, pan_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_interval(hold_duration)

	tween.tween_property(
		camera, "offset", base_offset, pan_back_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	_active = false
