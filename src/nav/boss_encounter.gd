extends Node2D
class_name BossEncounter

## Controls a single boss encounter.
##
## The encounter is separate from EnemyGauntlet because bosses can have
## different entrances:
##
##   AWAKEN      - Boss starts inactive and performs an awakening sequence.
##   CEILING     - Boss enters from above.
##   CHARGE_IN   - Boss enters from outside the arena.
##
## The boss itself is responsible for its AI, attacks, animation,
## health, and setting is_dying = true when defeated.
##
## Scene setup:
## ├── BossEncounter
## │   ├── TriggerArea
## │   └── Boss
##
## The target door closes when the encounter begins.
## The shortcut door opens when the boss is defeated.

enum EntranceType {
	AWAKEN,
	CEILING,
	CHARGE_IN
}

@export var boss_id: String = ""
@export var trigger_area: Area2D
@export var boss: Node
@export var target_door: Node

## Door/object that should open when the boss is defeated.
@export var shortcut_door: Node

@export var shortcut_id_on_clear: String = ""

@export_category("Entrance")
@export var entrance_type: EntranceType = EntranceType.AWAKEN

@export_category("Screen Shake")
@export var shake_on_start: bool = false
@export var shake_strength: float = 12.0
@export var shake_duration: float = 0.3

@export_category("Boss Activation")
@export var boss_activation_delay: float = 0.0
@export var rock_spawn_area: Area2D

@export_category("Battle Music")
@export var battle_music: AudioStream
@export var battle_music_fade_time: float = 0.8
@export var return_music_fade_time: float = 0.8

var _started := false
var _finished := false
var _battle_music_active := false
var _resetting := false
var _player_death_reset_pending := false

# Position the boss had when the room was initially loaded.
var _boss_start_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("boss_encounters")

	# Already defeated in the save file.
	#
	# The room has been loaded again after the boss was defeated.
	# Keep the boss node in the scene, but make it invisible and inactive.
	if boss_id != "" and GameState.is_boss_defeated(boss_id):
		_finished = true

		_set_boss_active(false)

		if target_door and target_door.has_method("open"):
			target_door.open()

		# Also make sure the shortcut door is open when
		# returning to the room after the boss has been defeated.
		if shortcut_door and shortcut_door.has_method("_open"):
			shortcut_door._open(true)

		if trigger_area:
			trigger_area.set_deferred("monitoring", false)
			trigger_area.set_deferred("monitorable", false)

		return

	if not trigger_area:
		push_warning("BossEncounter has no trigger_area assigned.")
		return

	# Remember the boss's original position in the level.
	if is_instance_valid(boss):
		_boss_start_position = boss.global_position

	trigger_area.monitoring = true
	trigger_area.monitorable = true

	if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.connect(_on_trigger_area_entered)

	if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
		trigger_area.body_entered.connect(_on_trigger_body_entered)


func _process(_delta: float) -> void:
	# Player died during the encounter.
	#
	# Do not immediately reset the boss because the player's death
	# animation and screen fade are still playing.
	if _started and not _finished and not _resetting:
		var player := get_tree().get_first_node_in_group("player")

		if player and player.get("is_dead") == true:
			_queue_reset_after_player_death()
			return

	# Restore room music when the player dies.
	if _battle_music_active:
		var player := get_tree().get_first_node_in_group("player")

		if player and player.get("is_dead") == true:
			_restore_room_music()

	if not _started or _finished or _resetting:
		return

	if not is_instance_valid(boss):
		return

	# Boss marks itself as dying when defeated.
	if boss.get("is_dying") == true:
		_finish_encounter()


func _on_trigger_area_entered(area: Area2D) -> void:
	if _started or _finished:
		return

	if area.is_in_group("player_detection"):
		_start_encounter()


func _on_trigger_body_entered(body: Node2D) -> void:
	if _started or _finished:
		return

	if body.is_in_group("player"):
		_start_encounter()


func _start_encounter() -> void:
	if _started or _finished or _resetting:
		return

	if boss_id != "" and GameState.is_boss_defeated(boss_id):
		return

	if not is_instance_valid(boss):
		push_warning("BossEncounter has no valid boss assigned.")
		return

	_started = true

	# Seal the arena.
	if target_door and target_door.has_method("close"):
		target_door.close()

	# Disable the trigger after activation.
	if trigger_area:
		trigger_area.set_deferred("monitoring", false)

	# Give the boss access to the encounter's rock spawn area.
	if rock_spawn_area:
		if boss.has_method("set_rock_spawn_area"):
			boss.set_rock_spawn_area(rock_spawn_area)

	# Switch from room music to boss battle music.
	if battle_music != null:
		_battle_music_active = true

		Music.play_battle_music(
			battle_music,
			battle_music_fade_time
		)

	# Optional impact when the encounter begins.
	if shake_on_start:
		_shake_on_start()

	# Run the boss entrance.
	await _play_boss_entrance()

	# The encounter may have been reset while the entrance was playing.
	if _resetting or _finished:
		return

	var player := get_tree().get_first_node_in_group("player")

	if player and player.get("is_dead") == true:
		_queue_reset_after_player_death()
		return

	# Small optional delay before combat begins.
	if boss_activation_delay > 0.0:
		await get_tree().create_timer(
			boss_activation_delay
		).timeout

	if _resetting or _finished:
		return

	player = get_tree().get_first_node_in_group("player")

	if player and player.get("is_dead") == true:
		_queue_reset_after_player_death()
		return

	_activate_boss()


func _shake_on_start() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not player:
		return

	if player.has_method("camera_shake"):
		player.camera_shake(
			shake_strength,
			shake_duration
		)


func _play_boss_entrance() -> void:
	if not is_instance_valid(boss):
		return

	match entrance_type:
		EntranceType.AWAKEN:
			if boss.has_method("boss_entrance_awaken"):
				await boss.boss_entrance_awaken()

		EntranceType.CEILING:
			if boss.has_method("boss_entrance_ceiling"):
				await boss.boss_entrance_ceiling()

		EntranceType.CHARGE_IN:
			if boss.has_method("boss_entrance_charge_in"):
				await boss.boss_entrance_charge_in()


func _activate_boss() -> void:
	if not is_instance_valid(boss):
		return

	if boss.has_method("activate_boss"):
		boss.activate_boss()
	else:
		boss.set_process(true)
		boss.set_physics_process(true)


func _finish_encounter() -> void:
	if _finished or _resetting:
		return

	_finished = true
	_started = false

	# Remember that this boss has been defeated.
	if boss_id != "":
		GameState.defeat_boss(boss_id)

	# Open the arena door.
	if target_door and target_door.has_method("open"):
		target_door.open()

	# Activate the shortcut in GameState.
	if shortcut_id_on_clear != "":
		GameState.activate_shortcut(shortcut_id_on_clear)

	# Open the physical shortcut door/object.
	if shortcut_door and shortcut_door.has_method("_open"):
		shortcut_door._open(false)

	# Return to the room's normal music.
	_restore_room_music()


func _queue_reset_after_player_death() -> void:
	if _player_death_reset_pending or _resetting or _finished:
		return

	_player_death_reset_pending = true

	call_deferred("_wait_for_player_death_transition")


func _wait_for_player_death_transition() -> void:
	while true:
		await get_tree().process_frame

		if _finished:
			_player_death_reset_pending = false
			return

		if GameState.is_room_unloading:
			continue

		var player := get_tree().get_first_node_in_group("player")

		if player and player.get("is_dead") == true:
			continue

		break

	_reset_after_player_death()


func _reset_after_player_death() -> void:
	if _resetting or _finished:
		_player_death_reset_pending = false
		return

	_resetting = true
	_player_death_reset_pending = false

	_started = false

	_restore_room_music()

	if is_instance_valid(boss):
		if boss.has_method("reset_boss"):
			boss.reset_boss()
		else:
			push_warning(
				"BossEncounter boss has no reset_boss() method. "
				+ "The boss may retain its previous state after player death."
			)

		boss.global_position = _boss_start_position

		_set_boss_active(true)

	# Reset arena door.
	if target_door and target_door.has_method("open"):
		target_door.close()

	# Shortcut should NOT be opened just because the player died.
	# It remains locked until the boss is actually defeated.

	if trigger_area:
		trigger_area.set_deferred("monitoring", true)
		trigger_area.set_deferred("monitorable", true)

	_resetting = false


func _set_boss_active(active: bool) -> void:
	if not is_instance_valid(boss):
		return

	if boss is CanvasItem:
		boss.visible = active

	boss.set_process(active)
	boss.set_physics_process(active)

	for child in boss.get_children():
		_set_boss_child_active(child, active)


func _set_boss_child_active(node: Node, active: bool) -> void:
	if not is_instance_valid(node):
		return

	node.set_process(active)
	node.set_physics_process(active)

	if node is CanvasItem:
		node.visible = active

	if node is CollisionShape2D:
		node.set_deferred("disabled", not active)

	elif node is CollisionPolygon2D:
		node.set_deferred("disabled", not active)

	elif node is Area2D:
		node.set_deferred("monitoring", active)
		node.set_deferred("monitorable", active)

		if not active:
			for child in node.get_children():
				if child is Timer:
					child.stop()

	for child in node.get_children():
		_set_boss_child_active(child, active)


func _restore_room_music() -> void:
	if not _battle_music_active:
		return

	_battle_music_active = false

	Music.restore_room_music(return_music_fade_time)


func reset_boss_encounter() -> void:
	if boss_id != "" and GameState.is_boss_defeated(boss_id):
		return

	_resetting = true
	_started = false
	_finished = false
	_player_death_reset_pending = false

	_restore_room_music()

	if trigger_area:
		trigger_area.set_deferred("monitoring", true)
		trigger_area.set_deferred("monitorable", true)

	if target_door and target_door.has_method("close"):
		target_door.close()

	if is_instance_valid(boss):
		if boss.has_method("reset_boss"):
			boss.reset_boss()

		boss.global_position = _boss_start_position
		_set_boss_active(true)

	_resetting = false
