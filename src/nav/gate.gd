extends Area2D
class_name TransitionGate

enum EntryType {
	WALK,
	JUMP
}

@export var gate_id: String = ""
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_gate_id: String = ""

@export_category("Entry")
@export var entry_type: EntryType = EntryType.WALK
@export var entry_direction: Vector2 = Vector2.RIGHT
@export var entry_distance: float = 180.0
@export var jump_velocity: Vector2 = Vector2(400.0, -800.0)


func _ready() -> void:
	add_to_group("gates")
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not GameState.can_trigger_gate():
		return

	if area.is_in_group("player_detection"):
		GameState.go_to_room(
			target_scene_path,
			target_gate_id,
			entry_type,
			entry_direction,
			entry_distance,
			jump_velocity
		)
