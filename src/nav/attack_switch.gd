extends StaticBody2D
class_name AttackSwitch

## Reacts to being struck by any player attack (sword, empowered
## double jump, dash) and opens a target door-like node (any node
## with open()/close() — SimpleDoor works out of the box).
##
## permanent_unlock = false  → "Attack switch, door opens temporarily"
##   Hitting it again refreshes the open timer, so the player can
##   keep it propped open by re-striking it.
##
## permanent_unlock = true   → "Attack object, door opens forever"
##   First hit unlocks it for good; further hits do nothing.
##
## Scene: needs a CollisionShape2D on collision_layer = 2 (the layer
## every weapon hitbox scans) and an optional TileMapLayer or Sprite2D
## that brightens on trigger.

@export var switch_id: String = ""
@export var target_door: Node
@export var permanent_unlock: bool = false
@export var open_duration: float = 4.0

@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)

var _triggered := false
var _close_timer: SceneTreeTimer


func _ready() -> void:
	add_to_group("attackable")

	if permanent_unlock and GameState.is_door_open(switch_id):
		_triggered = true
		_set_triggered_look()

		if target_door and target_door.has_method("open"):
			target_door.open()


func take_damage(_amount: int) -> void:
	if permanent_unlock and _triggered:
		return

	_triggered = true
	_set_triggered_look()

	if target_door == null:
		return

	if target_door.has_method("open"):
		target_door.open()

	if permanent_unlock:
		GameState.open_door_permanently(switch_id)
		return

	if _close_timer and _close_timer.time_left > 0.0:
		_close_timer.timeout.disconnect(_on_close_timeout)

	_close_timer = get_tree().create_timer(open_duration)
	_close_timer.timeout.connect(_on_close_timeout)


func _on_close_timeout() -> void:
	_triggered = false

	if target_door and target_door.has_method("close"):
		target_door.close()


func _set_triggered_look() -> void:
	if visual:
		visual.modulate = Color(1.4, 1.4, 0.8, 1.0)
