extends Node2D
class_name EnemyGauntlet

## Walking into trigger_area closes target_door and spawns wave 1.
## Each wave is a Node2D full of enemy scenes, already placed in the
## editor but hidden until its turn. When the last enemy in a wave is
## freed (i.e. dies — every enemy in this project is expected to
## queue_free() itself on death), the next wave shows itself. Once the
## final wave is cleared, target_door opens and, optionally, a shortcut
## is activated — so a gauntlet can double as the thing that unlocks a
## shortcut back to an earlier area.
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

@export var battle_music: AudioStream
@export var battle_music_fade_time: float = 0.8
@export var return_music_fade_time: float = 0.8

var _current_wave := -1
var _started := false
var _battle_music_active := false

const SPAWN_DURATION := 0.45
const SPAWN_START_SCALE := 0.2
const SPAWN_STAGGER := 0.06


func _ready() -> void:
	# Every wave starts hidden and inactive.
	for wave in waves:
		if is_instance_valid(wave):
			_set_wave_active(wave, false)

	if GameState.is_gauntlet_cleared(gauntlet_id):
		await get_tree().process_frame

		if target_door and target_door.has_method("open"):
			target_door.open()

		return

	if trigger_area:
		trigger_area.monitoring = true
		trigger_area.monitorable = true

		if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
			trigger_area.area_entered.connect(_on_trigger_area_entered)

		if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
			trigger_area.body_entered.connect(_on_trigger_body_entered)


func _process(_delta: float) -> void:
	# Restore room music when the player dies.
	if not _battle_music_active:
		return

	var player := get_tree().get_first_node_in_group("player")

	if player == null:
		return

	if player.get("is_dead") == true:
		_restore_room_music()


func _on_trigger_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_detection"):
		_start_gauntlet()


func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_start_gauntlet()


func _start_gauntlet() -> void:
	if _started:
		return

	if GameState.is_gauntlet_cleared(gauntlet_id):
		return

	_started = true

	if target_door and target_door.has_method("close"):
		target_door.close()

	# Switch from room music to battle music.
	if battle_music != null:
		_battle_music_active = true
		Music.play_battle_music(
			battle_music,
			battle_music_fade_time
		)

	_start_next_wave()


func _start_next_wave() -> void:
	_current_wave += 1

	if _current_wave >= waves.size():
		_finish()
		return

	var wave: Node = waves[_current_wave]

	if not is_instance_valid(wave):
		_start_next_wave()
		return

	var alive: Array[Node] = []

	for enemy in wave.get_children():
		if not is_instance_valid(enemy):
			continue

		if not enemy.is_in_group("enemies"):
			enemy.add_to_group("enemies")

		alive.append(enemy)

		enemy.tree_exited.connect(
			_on_wave_enemy_defeated.bind(alive, enemy),
			CONNECT_ONE_SHOT
		)

	# Animate the wave before activating its combat.
	await _animate_wave_in(wave)

	# Only after the entire animation is finished do the enemies
	# become active.
	_set_wave_active(wave, true)

	if alive.is_empty():
		_start_next_wave()


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

	# Return to the room's normal music.
	_restore_room_music()


func _restore_room_music() -> void:
	if not _battle_music_active:
		return

	_battle_music_active = false

	Music.restore_room_music(return_music_fade_time)


# Makes every enemy in the wave appear with a fade and scale-up.
#
# Enemies have no active collision/damage while this animation runs.
# Combat is enabled only after the entire wave finishes animating.
func _animate_wave_in(wave: Node) -> void:
	if not is_instance_valid(wave):
		return

	wave.visible = true

	var enemies: Array[Node] = []

	for enemy in wave.get_children():
		if not is_instance_valid(enemy):
			continue

		enemies.append(enemy)

		if enemy is CanvasItem:
			enemy.visible = true

		# Disable combat while the spawn animation is playing.
		_set_node_active(enemy, false)

		# Remember the enemy's normal scale.
		var target_scale: Vector2 = enemy.scale

		# Start small.
		enemy.scale = target_scale * SPAWN_START_SCALE

		# Start transparent.
		if enemy is CanvasItem:
			var modulate: Color = enemy.modulate
			modulate.a = 0.0
			enemy.modulate = modulate

	var tween := create_tween()
	tween.set_parallel(true)

	for i in range(enemies.size()):
		var enemy: Node = enemies[i]

		if not is_instance_valid(enemy):
			continue

		var delay := i * SPAWN_STAGGER

		var target_scale: Vector2 = enemy.scale / SPAWN_START_SCALE

		# Scale from small to normal size.
		tween.tween_property(
			enemy,
			"scale",
			target_scale,
			SPAWN_DURATION
		).set_delay(
			delay
		).set_trans(
			Tween.TRANS_BACK
		).set_ease(
			Tween.EASE_OUT
		)

		# Fade from transparent to fully visible.
		if enemy is CanvasItem:
			var target_modulate: Color = enemy.modulate
			target_modulate.a = 1.0

			tween.tween_property(
				enemy,
				"modulate",
				target_modulate,
				SPAWN_DURATION
			).set_delay(
				delay
			).set_trans(
				Tween.TRANS_QUAD
			).set_ease(
				Tween.EASE_OUT
			)

	await tween.finished


# Hides/shows the wave and disables/enables its gameplay collisions.
#
# Inactive waves:
#   - invisible
#   - enemy body collision disabled
#   - Area2D monitoring disabled
#   - damage timers stopped
#
# Active waves:
#   - visible
#   - enemy body collision enabled
#   - Area2D monitoring enabled
#   - damage timers allowed to run
#
# Enemy scripts are not modified.
func _set_wave_active(wave: Node, active: bool) -> void:
	if not is_instance_valid(wave):
		return

	wave.visible = active

	for enemy in wave.get_children():
		if not is_instance_valid(enemy):
			continue

		_set_node_active(enemy, active)


func _set_node_active(node: Node, active: bool) -> void:
	if not is_instance_valid(node):
		return

	# Disable the enemy's processing while it is spawning.
	#
	# We use explicit process toggles rather than PROCESS_MODE_DISABLED
	# so the enemy's own scene hierarchy is not changed.
	if active:
		node.set_process(true)
		node.set_physics_process(true)
	else:
		node.set_process(false)
		node.set_physics_process(false)

	# Collision shapes.
	if node is CollisionShape2D:
		node.set_deferred("disabled", not active)

	elif node is CollisionPolygon2D:
		node.set_deferred("disabled", not active)

	# Enemy damage/detection Area2D.
	elif node is Area2D:
		node.set_deferred("monitoring", active)
		node.set_deferred("monitorable", active)

		# Stop damage timers while inactive.
		if not active:
			for child in node.get_children():
				if child is Timer:
					child.stop()

	# Continue through nested children.
	for child in node.get_children():
		_set_node_active(child, active)
