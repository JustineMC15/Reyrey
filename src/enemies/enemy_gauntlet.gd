extends Node2D
class_name EnemyGauntlet

## Walking into trigger_area closes target_door and spawns wave 1.
## Each wave is a Node2D full of enemy scenes, already placed in the
## editor but hidden until its turn. When the last enemy in a wave is
## freed (i.e. dies — every enemy in this project is expected to
## queue_free() itself on death), the next wave shows itself. Once
## the final wave is cleared, target_door opens and, optionally, a
## shortcut is activated — so a gauntlet can double as the thing that
## unlocks a shortcut back to an earlier area.
##
## Clearing it once is remembered in GameState, so revisiting the
## room never re-locks the door or re-spawns the fight.
##
## Scene setup:
##   trigger_area — Area2D, collision_layer = 4, mask = 5
##   waves        — an array of Node2D, each containing that wave's
##                  enemy scenes as direct children (add them in the
##                  Inspector's `waves` array, in clear order)

@export var gauntlet_id: String = ""
@export var trigger_area: Area2D
@export var target_door: Node
@export var shortcut_id_on_clear: String = ""
@export var waves: Array[Node] = []

var _current_wave := -1
var _started := false


func _ready() -> void:
	for wave in waves:
		if is_instance_valid(wave):
			wave.hide()

	if GameState.is_gauntlet_cleared(gauntlet_id):
		if target_door and target_door.has_method("open"):
			target_door.open()
		return

	if trigger_area:
		trigger_area.area_entered.connect(_on_trigger_area_entered)


func _on_trigger_area_entered(area: Area2D) -> void:
	if _started or not area.is_in_group("player_detection"):
		return

	_started = true

	if target_door and target_door.has_method("close"):
		target_door.close()

	_start_next_wave()


func _start_next_wave() -> void:
	_current_wave += 1

	if _current_wave >= waves.size():
		_finish()
		return

	var wave: Node = waves[_current_wave]
	wave.show()

	var alive: Array[Node] = []

	for enemy in wave.get_children():
		if not enemy.is_in_group("enemies"):
			enemy.add_to_group("enemies")

		alive.append(enemy)
		enemy.tree_exited.connect(
			_on_wave_enemy_defeated.bind(alive, enemy),
			CONNECT_ONE_SHOT
		)


func _on_wave_enemy_defeated(alive: Array[Node], enemy: Node) -> void:
	alive.erase(enemy)

	if alive.is_empty():
		_start_next_wave()


func _finish() -> void:
	GameState.clear_gauntlet(gauntlet_id)

	if target_door and target_door.has_method("open"):
		target_door.open()

	if shortcut_id_on_clear != "":
		GameState.activate_shortcut(shortcut_id_on_clear)
