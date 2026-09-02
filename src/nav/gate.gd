extends Area2D
class_name TransitionGate

enum EntryType {
	WALK,
	JUMP,
	INSTANT
}

@export var gate_id: String = ""
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_gate_id: String = ""

@export_category("Preloading")
@export var preload_target: bool = true

@export_category("Entry")
@export var entry_type: EntryType = EntryType.WALK
@export var entry_direction: Vector2 = Vector2.RIGHT
@export var entry_distance: float = 180.0
@export var jump_velocity: Vector2 = Vector2(400.0, -800.0)


func _ready() -> void:
	add_to_group("gates")
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	if GameState.is_loading_save:
		return

	if not GameState.can_trigger_gate():
		return

	if target_scene_path == "":
		push_error(
			"TransitionGate '%s' has no target scene." % gate_id
		)
		return

	if target_gate_id == "":
		push_error(
			"TransitionGate '%s' has no target gate ID." % gate_id
		)
		return

	GameState.go_to_room(
		target_scene_path,
		target_gate_id,
		entry_type,
		entry_direction,
		entry_distance,
		jump_velocity
	)
