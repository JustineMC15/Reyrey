extends Node


# --- Persistent Player Stats ---

var abilities: Dictionary = {
	"double_jump": false,
	"dash": false,
	"ground_slam": false,
	"glide": false,
	"dash_chain": false,
	"wall_cling": false,
	"recall": false,
	"ledge_grab": false,
}

var max_health: int = 5
var max_mp: int = 6
var current_mp: int = 6


# --- Room / Gate transition state ---

var pending_spawn_gate_id: String = ""
var _transition_lock: bool = false

var checkpoint_scene_path: String = ""
var checkpoint_id: String = ""
var checkpoint_room_name: String = ""

var activated_checkpoints: Dictionary = {}

var pending_entry_type: int = 0
var pending_entry_direction: Vector2 = Vector2.RIGHT
var pending_entry_distance: float = 180.0
var pending_jump_velocity: Vector2 = Vector2(400.0, -800.0)


# --- Fade overlay ---

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

const FADE_DURATION := 0.25


# --- Game startup ---
var is_loading_save: bool = false
var startup_room_path: String = ""
var startup_checkpoint_id: String = ""


# --- Star Shrines ---

var shrine_count: int = 0
var claimed_shrines: Dictionary = {}

const SHRINE_MP_GAINS: Array[int] = [
	3, 3, 3, 2, 2,
	2, 2, 2, 2, 1,
	1, 1, 1, 1, 1,
	1, 1
]


# --- Armor ---

var armor_tier: int = 0

var armor_data: Dictionary = {
	0: {
		"name": "Traveler's Garb",
		"description": "Roadworn leather and wool, patched more times than Reyrey can count. No ceremony to it. It has kept him alive this far, which is the only credential it needs.",
	},
}


func increase_armor_tier() -> void:
	armor_tier += 1


func get_armor_data() -> Dictionary:
	return armor_data.get(armor_tier, armor_data[0])


# --- Ability system ---

var keybind_display: Dictionary = {
	"jump": "Space",
	"dash": "Shift",
	"ground_slam": "S / ↓",
	"glide": "Shift",
	"recall": "R",
	"interact": "E",
}


func get_keybind_text(ability_id: String) -> String:
	var data: Dictionary = ability_data.get(ability_id, {})
	var action: String = data.get("input_action", "")
	var hint: String = data.get("keybind_hint", "")
	var key_label: String = keybind_display.get(action, "")

	if key_label != "" and hint != "":
		return "%s — %s" % [key_label, hint]
	elif key_label != "":
		return key_label

	return hint


var ability_data: Dictionary = {
	"double_jump": {
		"name": "Spark Flame",
		"tin_text": "Combustion. Whoever wrote this world's laws decided that flame needs something to eat before it's allowed to exist. No exceptions, not even for me. I can stop a heart, I can stop a star, and I still have to feed the fire before it will hold you up. Pathetic economy. Eternity doesn't need to be fed. I checked.",
		"reynauld_text": "It kicks like a mule and smells like my eyebrows. Effective, though. I've decided not to ask what it's burning. Whatever it is, it isn't coin, and that's the only ingredient I ever worry about running out of.",
		"input_action": "jump",
		"keybind_hint": "Press again mid-air",
	},

	"dash": {
		"name": "Holy Lance",
		"tin_text": "Distance is the world's favorite lie. It insists that two things wanting to be close isn't enough — that wanting has to be spent crossing empty space first, like affection is a toll road. I built through this the same year I built through kingdoms. It still charges me anyway. Some laws don't care how old you are.",
		"reynauld_text": "It throws me forward faster than my legs would ever agree to. I used to close distance with my own two feet, thank you. Now I let something invisible do it for me and pretend that's dignified. It isn't. It is, however, faster, and I am a practical man.",
		"input_action": "dash",
		"keybind_hint": "Thrust forward while on the ground or while airborne",
	},

	"ground_slam": {
		"name": "Martyr's Drop",
		"tin_text": "Everything that rises has to come back down. I hate that rule more than any other, because I have tested every exception I could think of and the world simply waited me out. I have stopped stars mid-fall. I have not stopped myself. Apparently that's not how the arrangement works.",
		"reynauld_text": "They named it after martyrs, which I assume is meant to be poetic. I'd rather it be named after the ground, which is the thing doing all the suffering. I've cracked three shields testing this. I am billing someone. I haven't decided who yet.",
		"input_action": "ground_slam",
		"keybind_hint": "While airborne",
	},

	"glide": {
		"name": "Vigil Wind",
		"tin_text": "You're allowed to stay up. You are not allowed to stop asking. The moment you let go of the wanting, gravity remembers you exist and collects what it's owed. I used to think that was cruelty. Now I think it might be the only honest law this world has. Nothing stays aloft by accident. Not wind. Not devotion.",
		"reynauld_text": "I hold the wind the way I hold a vigil — badly, and with my arm going numb halfway through. Still, it's the first time this armor hasn't tried to kill me on the way down. I'll take unnatural mercy over natural consequence any day of the week.",
		"input_action": "glide",
		"keybind_hint": "Hold while falling",
	},

	"dash_chain": {
		"name": "Litany Step",
		"tin_text": "Say a thing enough times and the world decides you've used it up. Chant it, mean it, repeat it — the meaning is supposed to survive the repetition, and instead the world taxes you for each recitation until there's nothing left to say. I have said the same three words for eight hundred years. I would like an exception. I have never once received one.",
		"reynauld_text": "Every knight drills the same forms until his arms forget how to do anything else. This isn't so different — same step, over and over, until the body stops asking permission. I only wish my knees had been consulted before agreeing to this many repetitions.",
		"input_action": "dash",
		"keybind_hint": "Chain into a second dash",
	},

	"wall_cling": {
		"name": "Wick Ember",
		"tin_text": "A wick doesn't get to choose how long it burns. It holds on, it gives light, and the whole time it's being consumed for the privilege. I resent that grip is never free. I resent it more that I understand it — I have held on to things for centuries and called it strength, when it was only ever a slower way of running out.",
		"reynauld_text": "My gauntlets are earning their keep tonight. Stone does not care for knuckles, and I suspect my knuckles have opinions about stone they've been too polite to share until now. I'll manage. I've held worse things longer for less reason.",
		"input_action": "",
		"keybind_hint": "Hold toward a wall while airborne",
	},

	"recall": {
		"name": "Star Anchor",
		"tin_text": "You don't get to return to what you didn't think to keep. That's the law underneath every star chart, every memory, every fool who assumed the past would wait for them to come back and collect it. I mark my place now. Every time. I learned that lesson the hard way, and I intend to make sure I never learn it again.",
		"reynauld_text": "It hauls me backward like I'm on a leash I never agreed to wear, and somehow I don't mind it. I know where the mark is because he put it there. I've decided that's reason enough to trust it. I don't extend that courtesy to much else in this world.",
		"input_action": "recall",
		"keybind_hint": "Press once to place, again to return",
	},

	"ledge_grab": {
		"name": "Censer Swing",
		"tin_text": "The world does not catch you by default. That's the part nobody tells you. Every ledge, every fall, every threshold — you either seize it yourself or you don't, and the universe watches without opinion either way. I used to think mercy was rare because people were cruel. It's rarer than that. Mercy isn't even the world's job.",
		"reynauld_text": "I've been pulled from worse drops by worse hands. This one, at least, is mine — I catch the edge myself, every time, and no one has to come looking for what's left of me at the bottom. Small comfort. I'll take it.",
		"input_action": "",
		"keybind_hint": "Approach a ledge while falling, Jump to climb",
	},
}


signal ability_claimed(ability_id)

var tutorials_seen: Dictionary = {
	"movement": false,
	"jump": false,
	"attack": false,
}
var area_names_seen: Dictionary = {}
func has_seen_tutorial(tutorial_id: String) -> bool:
	return tutorials_seen.get(tutorial_id, false)


func mark_tutorial_seen(tutorial_id: String) -> void:
	tutorials_seen[tutorial_id] = true
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_overlay()


# --- Helpers ---

func _get_game() -> Node:
	var game := get_tree().current_scene

	if game == null:
		push_error("GameState: Current scene not found.")
		return null

	return game


# --- Window close ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_checkpoint():
			SaveManager.save_game(SaveManager.current_slot)

		get_tree().quit()


# --- Keys ---
 
var collected_keys: Dictionary = {}
 
 
func has_key(key_id: String) -> bool:
	if key_id == "":
		return true
	return collected_keys.has(key_id)
 
 
func collect_key(key_id: String) -> void:
	collected_keys[key_id] = true
 
 
func consume_key(key_id: String) -> void:
	collected_keys.erase(key_id)
 
 
# --- Doors (locked doors, attack-switch doors, gauntlet doors) ---
 
var opened_doors: Dictionary = {}
 
 
func is_door_open(door_id: String) -> bool:
	return opened_doors.has(door_id)
 
 
func open_door_permanently(door_id: String) -> void:
	opened_doors[door_id] = true
 
 
# --- Broken obstacles (breakable walls / breakable floors) ---
 
var broken_obstacles: Dictionary = {}
 
 
func is_obstacle_broken(obstacle_id: String) -> bool:
	return broken_obstacles.has(obstacle_id)
 
 
func break_obstacle(obstacle_id: String) -> void:
	broken_obstacles[obstacle_id] = true
 
 
# --- Revealed secrets (hidden walls) ---
 
var revealed_secrets: Dictionary = {}
 
 
func is_secret_revealed(secret_id: String) -> bool:
	return revealed_secrets.has(secret_id)
 
 
func reveal_secret(secret_id: String) -> void:
	revealed_secrets[secret_id] = true
 
 
# --- One-way shortcuts (levers unlocking doors/bridges/ladders/walls) ---
 
signal shortcut_activated(shortcut_id)
 
var activated_shortcuts: Dictionary = {}
 
 
func is_shortcut_activated(shortcut_id: String) -> bool:
	return activated_shortcuts.has(shortcut_id)
 
 
func activate_shortcut(shortcut_id: String) -> void:
	if is_shortcut_activated(shortcut_id):
		return
 
	activated_shortcuts[shortcut_id] = true
	shortcut_activated.emit(shortcut_id)
 
 
# --- Enemy gauntlets ---
 
var cleared_gauntlets: Dictionary = {}
 
 
func is_gauntlet_cleared(gauntlet_id: String) -> bool:
	return cleared_gauntlets.has(gauntlet_id)
 
 
func clear_gauntlet(gauntlet_id: String) -> void:
	cleared_gauntlets[gauntlet_id] = true
 

# --- Anvils ---

const ANVIL_HP_GAIN := 1

var claimed_anvils: Dictionary = {}


func is_anvil_claimed(anvil_id: String) -> bool:
	return claimed_anvils.has(anvil_id)


func claim_anvil(anvil_id: String, player: Node) -> void:
	if is_anvil_claimed(anvil_id):
		return

	claimed_anvils[anvil_id] = true

	max_health += ANVIL_HP_GAIN

	if player:
		player.max_health = max_health
		player.health = max_health
		player.health_changed.emit(
			player.health,
			player.max_health
		)

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	await _run_anvil_claim_sequence(player)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false


func _run_anvil_claim_sequence(player: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.modulate.a = 0.0
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Max HP increased"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var prompt := Label.new()
	prompt.text = "Press Enter / Space to continue"
	prompt.modulate.a = 0.6
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var player_glow: Tween

	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")

		player_glow = create_tween().set_loops()

		player_glow.tween_property(
			sprite,
			"modulate",
			Color(2, 2, 1.4, 1),
			0.4
		)

		player_glow.tween_property(
			sprite,
			"modulate",
			Color.WHITE,
			0.4
		)

	var fade_in := create_tween()

	fade_in.tween_property(
		dim,
		"color:a",
		0.85,
		0.4
	)

	fade_in.parallel().tween_property(
		vbox,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_in.finished
	await get_tree().create_timer(0.2).timeout

	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

	if player_glow:
		player_glow.kill()

		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	var fade_out := create_tween()

	fade_out.tween_property(
		dim,
		"color:a",
		0.0,
		0.3
	)

	fade_out.parallel().tween_property(
		vbox,
		"modulate:a",
		0.0,
		0.3
	)

	await fade_out.finished

	layer.queue_free()


# --- Star Shrines ---

func is_shrine_claimed(shrine_id: String) -> bool:
	return claimed_shrines.has(shrine_id)


func claim_shrine(
	shrine_id: String,
	player: Node,
	abandonment_text: String
) -> void:
	if is_shrine_claimed(shrine_id):
		return

	if shrine_count >= SHRINE_MP_GAINS.size():
		return

	claimed_shrines[shrine_id] = {
		"text": abandonment_text,
		"order": shrine_count
	}

	var gain := SHRINE_MP_GAINS[shrine_count]
	shrine_count += 1

	max_mp += gain
	current_mp = max_mp

	if player:
		player.max_mp = max_mp
		player.mp = current_mp
		player.mp_changed.emit(
			player.mp,
			player.max_mp
		)

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	await _run_shrine_claim_sequence(
		player,
		gain,
		abandonment_text
	)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false


func _run_shrine_claim_sequence(
	player: Node,
	gain: int,
	abandonment_text: String
) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.modulate.a = 0.0
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = abandonment_text
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var gain_text := Label.new()
	gain_text.text = "Maximum MP increased by " + str(gain)
	gain_text.add_theme_font_size_override("font_size", 24)
	gain_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gain_text)

	var prompt := Label.new()
	prompt.text = "Press Enter / Space to continue"
	prompt.modulate.a = 0.6
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var player_glow: Tween

	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")

		player_glow = create_tween().set_loops()

		player_glow.tween_property(
			sprite,
			"modulate",
			Color(2, 2, 1.4, 1),
			0.4
		)

		player_glow.tween_property(
			sprite,
			"modulate",
			Color.WHITE,
			0.4
		)

	var fade_in := create_tween()

	fade_in.tween_property(
		dim,
		"color:a",
		0.85,
		0.4
	)

	fade_in.parallel().tween_property(
		vbox,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_in.finished

	await get_tree().create_timer(0.2).timeout

	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

	if player_glow:
		player_glow.kill()

		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	var fade_out := create_tween()

	fade_out.tween_property(
		dim,
		"color:a",
		0.0,
		0.3
	)

	fade_out.parallel().tween_property(
		vbox,
		"modulate:a",
		0.0,
		0.3
	)

	await fade_out.finished

	layer.queue_free()


# --- Ability system ---

func unlock_ability(ability_id: String) -> void:
	abilities[ability_id] = true


func has_ability(ability_id: String) -> bool:
	return abilities.get(ability_id, false)


func claim_ability(
	ability_id: String,
	player: Node,
	icon: Texture2D = null
) -> void:
	if has_ability(ability_id):
		return

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	_run_claim_sequence(
		ability_id,
		player,
		icon
	)


func _run_claim_sequence(
	ability_id: String,
	player: Node,
	icon: Texture2D
) -> void:
	var data: Dictionary = ability_data.get(
		ability_id,
		{}
	)

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.modulate.a = 0.0
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(96, 96)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)

		var pulse := create_tween().set_loops()

		pulse.tween_property(
			icon_rect,
			"scale",
			Vector2(1.15, 1.15),
			0.6
		).set_trans(Tween.TRANS_SINE)

		pulse.tween_property(
			icon_rect,
			"scale",
			Vector2(1.0, 1.0),
			0.6
		)

	var title := Label.new()
	title.text = data.get(
		"name",
		ability_id.capitalize()
	) + " Claimed"

	title.add_theme_font_size_override(
		"font_size",
		36
	)

	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for key in ["tin_text", "reynauld_text"]:
		if data.has(key):
			var line := Label.new()
			line.text = data[key]
			line.autowrap_mode = TextServer.AUTOWRAP_WORD
			line.custom_minimum_size = Vector2(760, 0)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(line)

	var prompt := Label.new()
	prompt.text = "Press Enter / Space to continue"
	prompt.modulate.a = 0.6
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var player_glow: Tween

	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")

		player_glow = create_tween().set_loops()

		player_glow.tween_property(
			sprite,
			"modulate",
			Color(2, 2, 1.4, 1),
			0.4
		)

		player_glow.tween_property(
			sprite,
			"modulate",
			Color.WHITE,
			0.4
		)

	var fade_in := create_tween()

	fade_in.tween_property(
		dim,
		"color:a",
		0.85,
		0.4
	)

	fade_in.parallel().tween_property(
		vbox,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_in.finished

	await get_tree().create_timer(0.2).timeout

	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

	if player_glow:
		player_glow.kill()

		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	var fade_out := create_tween()

	fade_out.tween_property(
		dim,
		"color:a",
		0.0,
		0.3
	)

	fade_out.parallel().tween_property(
		vbox,
		"modulate:a",
		0.0,
		0.3
	)

	await fade_out.finished

	layer.queue_free()

	unlock_ability(ability_id)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false
	ability_claimed.emit(ability_id)


# --- Checkpoints ---

func set_checkpoint(
	scene_path: String,
	checkpoint_id_value: String,
	room_name: String = ""
) -> void:
	checkpoint_scene_path = scene_path
	checkpoint_id = checkpoint_id_value
	checkpoint_room_name = room_name


func has_checkpoint() -> bool:
	return checkpoint_scene_path != "" and checkpoint_id != ""


func clear_checkpoint() -> void:
	checkpoint_scene_path = ""
	checkpoint_id = ""
	checkpoint_room_name = ""


func respawn_player() -> void:
	if _transition_lock:
		return

	_transition_lock = true

	if not has_checkpoint():
		await _fade_out_and_reload_current_scene()

		_transition_lock = false
		return

	var fade_out := create_tween()

	fade_out.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		FADE_DURATION
	)

	await fade_out.finished

	var game := _get_game()

	if game == null:
		_transition_lock = false
		return

	if not game.has_method("load_room"):
		push_error(
			"GameState: Game cannot load rooms during respawn."
		)

		_transition_lock = false
		return

	await game.load_room(checkpoint_scene_path)

	if game.has_method("position_player_at_checkpoint"):
		await game.position_player_at_checkpoint(checkpoint_id)

	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		var player = players[0]

		if player.has_method("reset_after_death"):
			player.reset_after_death()

		await get_tree().physics_frame

		if player.has_method("enable_world_interaction"):
			player.enable_world_interaction()

	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		FADE_DURATION
	)

	await fade_in.finished

	_transition_lock = false

func respawn_at_position(
	player: Node,
	target_position: Vector2,
	fade_duration: float = 0.25,
	invincibility_after: float = 1.0
) -> void:
	if _transition_lock:
		return

	_transition_lock = true

	if player.has_method("lock_input"):
		player.lock_input()

	var fade_out := create_tween()

	fade_out.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		fade_duration
	)

	await fade_out.finished

	if not is_instance_valid(player):
		_transition_lock = false
		return

	var camera := player.get_node_or_null("Camera2D")

	if camera:
		camera.position_smoothing_enabled = false

	player.global_position = target_position
	player.velocity = Vector2.ZERO

	if camera:
		camera.reset_smoothing()

	await get_tree().physics_frame

	if camera:
		camera.position_smoothing_enabled = true

	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		fade_duration
	)

	await fade_in.finished

	if is_instance_valid(player):
		if player.has_method("unlock_input"):
			player.unlock_input()

		if player.has_method("grant_temporary_invincibility"):
			player.grant_temporary_invincibility(invincibility_after)

	_transition_lock = false

func rest_at_checkpoint() -> void:
	if _transition_lock:
		return

	_transition_lock = true

	if not has_checkpoint():
		_transition_lock = false
		return

	var fade_out := create_tween()

	fade_out.tween_property(
		_fade_rect,
		"color:a",
		0.75,
		FADE_DURATION
	)

	await fade_out.finished

	var game := _get_game()

	if game == null:
		_transition_lock = false
		return

	if not game.has_method("load_room"):
		push_error(
			"GameState: Game cannot load rooms."
		)

		_transition_lock = false
		return

	await game.load_room(checkpoint_scene_path)

	if game.has_method("position_player_at_checkpoint"):
		await game.position_player_at_checkpoint(checkpoint_id)

	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		var player = players[0]

		if player.has_method("restore_full_health"):
			player.restore_full_health()

		if player.has_method("restore_full_mp"):
			player.restore_full_mp()

		if player.has_method("restore_full_stamina"):
			player.restore_full_stamina()

		# Let the new room and player position synchronize
		# before restoring world collision.
		await get_tree().physics_frame

		if player.has_method("enable_world_interaction"):
			player.enable_world_interaction()

	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		0.35
	)

	await fade_in.finished

	_transition_lock = false


func activate_checkpoint(
	scene_path: String,
	checkpoint_id_value: String
) -> void:
	var key := scene_path + "/" + checkpoint_id_value
	activated_checkpoints[key] = true


func is_checkpoint_activated(
	scene_path: String,
	checkpoint_id_value: String
) -> bool:
	var key := scene_path + "/" + checkpoint_id_value
	return activated_checkpoints.has(key)


func prepare_new_game() -> void:
	startup_room_path = "res://src/rooms/A0R1.tscn"
	startup_checkpoint_id = ""


func prepare_loaded_game() -> void:
	startup_room_path = checkpoint_scene_path
	startup_checkpoint_id = checkpoint_id

	pending_spawn_gate_id = ""
	pending_entry_type = TransitionGate.EntryType.INSTANT
	pending_entry_direction = Vector2.ZERO
	pending_entry_distance = 0.0
	pending_jump_velocity = Vector2.ZERO

	is_loading_save = true
	_transition_lock = false

	if startup_room_path == "":
		startup_room_path = "res://src/rooms/A0R1.tscn"
		startup_checkpoint_id = ""
# --- Room transition ---

func can_trigger_gate() -> bool:
	return not _transition_lock


func go_to_room(
	target_scene_path: String,
	target_gate_id: String,
	entry_type: int = 0,
	entry_direction: Vector2 = Vector2.RIGHT,
	entry_distance: float = 180.0,
	jump_velocity: Vector2 = Vector2(400.0, -800.0)
) -> void:
	if _transition_lock:
		return

	_transition_lock = true

	pending_spawn_gate_id = target_gate_id
	pending_entry_type = entry_type
	pending_entry_direction = entry_direction.normalized()
	pending_entry_distance = entry_distance
	pending_jump_velocity = jump_velocity

	await _fade_out_and_load(target_scene_path)


func _fade_out_and_load(target_scene_path: String) -> void:
	var tween := create_tween()

	tween.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		FADE_DURATION
	)

	await tween.finished

	var game := _get_game()

	if game == null:
		_transition_lock = false
		return

	if not game.has_method("load_room"):
		push_error(
			"GameState: Game instance has no load_room() method."
		)

		_transition_lock = false
		return

	await game.load_room(target_scene_path)

	await _on_new_room_ready()


func _on_new_room_ready() -> void:
	if pending_spawn_gate_id != "":
		await _position_player_at_gate()
		return

	await _fade_in()


func _position_player_at_gate() -> void:
	if pending_spawn_gate_id == "":
		return

	var players := get_tree().get_nodes_in_group("player")
	var gates := get_tree().get_nodes_in_group("gates")

	if players.is_empty():
		push_error("GameState: No player found during room transition.")
		return

	var player = players[0]
	var camera := player.get_node_or_null("Camera2D")

	for gate in gates:
		if gate.gate_id != pending_spawn_gate_id:
			continue

		if camera:
			camera.position_smoothing_enabled = false

		# Place player at destination gate.
		player.global_position = gate.global_position
		player.velocity = Vector2.ZERO

		# Freeze player movement during arrival.
		if player.has_method("lock_input"):
			player.lock_input()

		# Turn collision back on without unlocking movement.
		if player.has_method("enable_collision_only"):
			player.enable_collision_only()

		await get_tree().physics_frame

		print(
			"TRANSITION SPAWN: ",
			gate.gate_id,
			" at ",
			player.global_position
		)

		pending_spawn_gate_id = ""

		await _start_room_entry(player)

		if camera:
			camera.position_smoothing_enabled = true

		return

	push_error(
		"GameState: Destination gate not found: "
		+ pending_spawn_gate_id
	)


func _start_room_entry(player: Node) -> void:
	var fade_tween := create_tween()

	fade_tween.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		FADE_DURATION
	)

	await fade_tween.finished

	if not is_instance_valid(player):
		_transition_lock = false
		return

	match pending_entry_type:
		TransitionGate.EntryType.WALK:
			await _walk_into_room(player)

		TransitionGate.EntryType.JUMP:
			await _jump_into_room(player)

		TransitionGate.EntryType.INSTANT:
			pass

	if is_instance_valid(player):
		if player.has_method("unlock_input"):
			player.unlock_input()

	_transition_lock = false


func _walk_into_room(player: Node) -> void:
	var start_position: Vector2 = player.global_position

	var direction: Vector2 = pending_entry_direction

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	direction = direction.normalized()

	var target_position: Vector2 = (
		start_position
		+ direction * pending_entry_distance
	)

	var distance: float = start_position.distance_to(
		target_position
	)

	var walk_speed: float = 300.0
	var duration: float = distance / walk_speed

	if player.has_method("start_transition_walk"):
		player.start_transition_walk(sign(direction.x))

	if player.has_method("lock_input"):
		player.lock_input()

	var tween := create_tween()

	tween.tween_property(
		player,
		"global_position",
		target_position,
		duration
	).set_trans(Tween.TRANS_LINEAR)

	await tween.finished

	if player.has_method("stop_transition_walk"):
		player.stop_transition_walk()


func _jump_into_room(player: Node) -> void:
	if not player.has_method("lock_input"):
		return

	player.lock_input()

	player.velocity = pending_jump_velocity

	var safety_timer := 3.0

	while safety_timer > 0.0:
		safety_timer -= get_process_delta_time()

		if not is_instance_valid(player):
			return

		if player is CharacterBody2D:
			if player.is_on_floor() and safety_timer < 2.8:
				break

		await get_tree().process_frame


func _fade_out_and_reload_current_scene() -> void:
	var game := _get_game()

	if game == null:
		_transition_lock = false
		return

	if not game.has_method("get_current_room_scene_path"):
		push_error(
			"GameState: Game cannot provide current room path."
		)

		_transition_lock = false
		return

	var room_path: String = game.get_current_room_scene_path()

	if room_path == "":
		_transition_lock = false
		return

	var fade_out := create_tween()

	fade_out.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		FADE_DURATION
	)

	await fade_out.finished

	await game.load_room(room_path)

	if game.has_method("position_player_at_start"):
		await game.position_player_at_start()

	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		var player = players[0]

		if player.has_method("reset_after_death"):
			player.reset_after_death()

		await get_tree().physics_frame

		if player.has_method("enable_world_interaction"):
			player.enable_world_interaction()

	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		FADE_DURATION
	)

	await fade_in.finished

	_transition_lock = false


func _fade_in() -> void:
	var tween := create_tween()

	tween.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		FADE_DURATION
	)

	await tween.finished

	_transition_lock = false


# --- Fade overlay ---

func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

# --- Save system ---

func get_save_data() -> Dictionary:
	return {
		"abilities": abilities.duplicate(),
		"max_mp": max_mp,
		"max_health": max_health,
		"shrine_count": shrine_count,
		"claimed_anvils": claimed_anvils.duplicate(),
		"claimed_shrines": claimed_shrines.duplicate(true),
		"armor_tier": armor_tier,
		"activated_checkpoints": activated_checkpoints.duplicate(),
		"checkpoint_scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"checkpoint_room_name": checkpoint_room_name,
		"tutorials_seen": tutorials_seen.duplicate(),
		"collected_keys": collected_keys.duplicate(),
		"opened_doors": opened_doors.duplicate(),
		"broken_obstacles": broken_obstacles.duplicate(),
		"revealed_secrets": revealed_secrets.duplicate(),
		"activated_shortcuts": activated_shortcuts.duplicate(),
		"cleared_gauntlets": cleared_gauntlets.duplicate(),
		"area_names_seen": area_names_seen.duplicate(),
	}

func apply_save_data(data: Dictionary) -> void:
	abilities = data.get("abilities", abilities)
	max_mp = data.get("max_mp", max_mp)
	current_mp = max_mp
	max_health = data.get("max_health", max_health)
	shrine_count = data.get("shrine_count", 0)
	claimed_anvils = data.get("claimed_anvils", {})
	claimed_shrines = data.get("claimed_shrines", {})
	armor_tier = data.get("armor_tier", armor_tier)
	activated_checkpoints = data.get("activated_checkpoints", {})
	checkpoint_scene_path = data.get("checkpoint_scene_path", "")
	checkpoint_id = data.get("checkpoint_id", "")
	checkpoint_room_name = data.get("checkpoint_room_name", "")
	collected_keys = data.get("collected_keys", {})
	opened_doors = data.get("opened_doors", {})
	broken_obstacles = data.get("broken_obstacles", {})
	revealed_secrets = data.get("revealed_secrets", {})
	activated_shortcuts = data.get("activated_shortcuts", {})
	cleared_gauntlets = data.get("cleared_gauntlets", {})
	area_names_seen = data.get("area_names_seen", {})

	tutorials_seen = data.get("tutorials_seen", {
		"movement": false,
		"jump": false,
		"attack": false,
	}).duplicate()

func reset_to_defaults() -> void:
	for key in abilities.keys():
		abilities[key] = false

	max_mp = 6
	current_mp = 6
	max_health = 5
	armor_tier = 0
	shrine_count = 0

	claimed_anvils.clear()
	claimed_shrines.clear()
	activated_checkpoints.clear()
	
	tutorials_seen = {
	"movement": false,
	"jump": false,
	"attack": false,
}
	checkpoint_scene_path = ""
	checkpoint_id = ""
	checkpoint_room_name = ""
	collected_keys.clear()
	opened_doors.clear()
	broken_obstacles.clear()
	revealed_secrets.clear()
	activated_shortcuts.clear()
	cleared_gauntlets.clear()
	area_names_seen.clear()



func load_from_save(scene_path: String) -> void:
	if scene_path == "":
		scene_path = "res://src/rooms/A0R1.tscn"

	var game := _get_game()

	if game == null:
		return

	if not game.has_method("load_room"):
		push_error(
			"GameState: Game instance cannot load rooms."
		)
		return

	await game.load_room(scene_path)

	if checkpoint_id != "" \
	and game.has_method("position_player_at_checkpoint"):
		await game.position_player_at_checkpoint(checkpoint_id)
