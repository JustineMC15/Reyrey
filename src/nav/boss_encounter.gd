extends Node2D
class_name BossEncounter

## Controls a single boss encounter.
##
## The encounter is separate from EnemyGauntlet because bosses can have
## different entrances:
##
##   NONE        - Boss simply activates.
##   AWAKEN      - Boss starts inactive and performs an awakening sequence.
##   CEILING     - Boss enters from above.
##   CHARGE_IN   - Boss enters from outside the arena.
##
## The boss itself is responsible for its AI, attacks, animation,
## health, and setting is_dying = true when defeated.
##
## Scene setup:
##
## BossEncounter
## ├── TriggerArea
## └── Boss
##
## TriggerArea:
##   Area2D
##   collision_layer = 4
##   collision_mask = 5
##
## Boss:
##   CharacterBody2D or another Node
##   Must have an `is_dying` property.
##
## The target door is the door that should close when the encounter
## begins and reopen after the boss is defeated.

enum EntranceType {
	NONE,
	AWAKEN,
	CEILING,
	CHARGE_IN
}

@export var boss_id: String = ""
@export var trigger_area: Area2D
@export var boss: Node
@export var target_door: Node
@export var shortcut_id_on_clear: String = ""

@export_category("Entrance")
@export var entrance_type: EntranceType = EntranceType.NONE

@export_category("Screen Shake")
@export var shake_on_start: bool = false
@export var shake_strength: float = 12.0
@export var shake_duration: float = 0.3

@export_category("Boss Activation")
@export var boss_activation_delay: float = 0.0

var _started := false
var _finished := false


func _ready() -> void:
	add_to_group("boss_encounters")

	# Already cleared in the save file.
	if boss_id != "" and GameState.is_gauntlet_cleared(boss_id):
		_finished = true

		if target_door and target_door.has_method("open"):
			target_door.open()

		return

	if not trigger_area:
		push_warning("BossEncounter has no trigger_area assigned.")
		return

	trigger_area.monitoring = true
	trigger_area.monitorable = true

	if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.connect(_on_trigger_area_entered)

	if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
		trigger_area.body_entered.connect(_on_trigger_body_entered)


func _process(_delta: float) -> void:
	if not _started or _finished:
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
	if _started or _finished:
		return

	if boss_id != "" and GameState.is_gauntlet_cleared(boss_id):
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

	# Optional impact when the encounter begins.
	if shake_on_start:
		_shake_on_start()

	# Run the boss entrance.
	await _play_boss_entrance()

	# Small optional delay before combat begins.
	if boss_activation_delay > 0.0:
		await get_tree().create_timer(boss_activation_delay).timeout

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
		EntranceType.NONE:
			return

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
		# Default behavior:
		# enable normal processing if the boss has not implemented
		# a dedicated activation method yet.
		boss.set_process(true)
		boss.set_physics_process(true)


func _finish_encounter() -> void:
	if _finished:
		return

	_finished = true

	# Remember that the boss has been defeated.
	#
	# We reuse GameState's existing gauntlet-cleared persistence because
	# it already provides exactly the persistent encounter flag we need.
	if boss_id != "":
		GameState.clear_gauntlet(boss_id)

	# Open the arena after the boss dies.
	if target_door and target_door.has_method("open"):
		target_door.open()

	# Activate optional shortcut.
	if shortcut_id_on_clear != "":
		GameState.activate_shortcut(shortcut_id_on_clear)


func reset_boss_encounter() -> void:
	if boss_id != "" and GameState.is_gauntlet_cleared(boss_id):
		return

	_started = false
	_finished = false

	if trigger_area:
		trigger_area.set_deferred("monitoring", true)

	if target_door and target_door.has_method("close"):
		target_door.close()

	# Reset the boss if it provides a reset method.
	if is_instance_valid(boss) and boss.has_method("reset_boss"):
		boss.reset_boss()
