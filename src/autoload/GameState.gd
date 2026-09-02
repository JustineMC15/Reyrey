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

var star_fragments: int = 0
var max_health: int = 5
var max_mp: int = 6
var current_mp: int = 6
var max_stamina: float = 100.0

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
	4, 3, 3, 3, 3, 2, 2, 2, 2,
	2, 2, 2, 2, 1, 1, 1, 1
]
# LCM of 2 and 3, Maxes out to 42 mana with base 6 included
const SHRINE_STAMINA_GAINS: Array[float] = [
	15.0, 12.0, 12.0, 10.0, 10.0, 8.0, 8.0, 8.0, 8.0,
	6.0, 6.0, 6.0, 6.0, 4.0, 4.0, 4.0, 4.0
]
# --- Armor ---

var armor_tier: int = 0

var armor_data: Dictionary = {
	0: {
		"name": "Traveler's Garb",
		"description": "Roadworn leather and wool, patched more times than Reyrey can count. No ceremony to it. It has kept him alive this far, which is the only credential it needs.",
	},
	1: {
		"name": "Worn Knight's Plate",
		"description": "Old steel beneath a faded blue tabard, scarred by years of neglect and hard travel. The cloth has lost much of its color, but the white rhombus remains clear. It was made for a knight once. For now, it is simply armor that still holds together.",
	},
	2: {
		"name": "Maintained Knight's Plate",
		"description": "Faded steel and weathered cloth, but carefully tended. Scratches have been cleaned, straps replaced, and loose plates secured. It bears the marks of its past without surrendering to them.",
	},
	3: {
		"name": "Knight's Plate",
		"description": "Solid steel worn with purpose rather than neglect. Its tabard still bears a respectable blue, and the armor has seen enough battles to prove its worth. Not pristine, not ornate—just dependable.",
	},
	4: {
		"name": "Ornate Knight's Plate",
		"description": "Polished steel framed with deliberate ornament, its blue tabard rich and carefully kept. Every plate has been shaped and fitted with pride. It is the sort of armor meant to be noticed when its wearer enters the room.",
	},
	5: {
		"name": "Starlit Knight's Plate",
		"description": "Pristine steel, immaculate cloth, and craftsmanship bordering on ceremonial. The blue tabard is deep and vivid beneath the polished plates, its white rhombus stark against the fabric. There is scarcely a scratch upon it. Whether it was earned, inherited, or taken is another matter entirely.",
	},
}

func increase_armor_tier() -> void:
	armor_tier = clamp(armor_tier + 1, 0, 5)


func get_armor_data() -> Dictionary:
	return armor_data.get(armor_tier, armor_data[0])


# --- Ability system ---

var keybind_display: Dictionary = {
	"jump": "Space / Z",
	"dash": "Shift / C",
	"ground_slam": "V / CTRL",
	"glide": "Space / Z",
	"recall": "R",
	"interact": "E",
}

var camera_offset_locked: bool = false

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
		"description": "A small flame that bears its bearer aloft once more. When fed with MP, it burns brighter and carries greater force.",
		"tin_text": "Combustion. Whoever wrote this world's laws decided that flame needs something to eat before it's allowed to exist. No exceptions, not even for me. I can stop a heart, I can stop a star, and I still have to feed the fire before it will hold you up. Pathetic economy. Eternity doesn't need to be fed. I checked.",
		"reynauld_text": "It kicks like a mule and smells like my eyebrows. Effective, though. I've decided not to ask what it's burning. Whatever it is, it isn't coin, and that's the only ingredient I ever worry about running out of.",
		"input_action": "jump",
		"keybind_hint": "Press again mid-air",
	},

	"dash": {
		"name": "Holy Lance",
		"description": "A swift thrust that carries its bearer a great distance. When fed with MP, it strikes foes and shields the bearer from harm.",
		"tin_text": "Distance is the world's favorite lie. It insists that two things wanting to be close isn't enough — that wanting has to be spent crossing empty space first, like affection is a toll road. I built through this the same year I built through kingdoms. It still charges me anyway. Some laws don't care how old you are.",
		"reynauld_text": "It throws me forward faster than my legs would ever agree to. I used to close distance with my own two feet, thank you. Now I let something invisible do it for me and pretend that's dignified. It isn't. It is, however, faster, and I am a practical man.",
		"input_action": "dash",
		"keybind_hint": "Thrust forward while on the ground or while airborne",
	},

	"ground_slam": {
		"name": "Martyr's Drop",
		"description": "A mighty descent that shakes the earth beneath the bearer, harming those nearby and shattering fragile ground.",
		"tin_text": "Everything that rises has to come back down. I hate that rule more than any other, because I have tested every exception I could think of and the world simply waited me out. I have stopped stars mid-fall. I have not stopped myself. Apparently that's not how the arrangement works.",
		"reynauld_text": "They named it after martyrs, which I assume is meant to be poetic. I'd rather it be named after the ground, which is the thing doing all the suffering. I've cracked three shields testing this. I am billing someone. I haven't decided who yet.",
		"input_action": "ground_slam",
		"keybind_hint": "While airborne",
	},

	"glide": {
		"name": "Vigil Wind",
		"description": "A gentle wind that carries the bearer through the air, slowing their fall and carrying them aloft.",
		"tin_text": "You're allowed to stay up. You are not allowed to stop asking. The moment you let go of the wanting, gravity remembers you exist and collects what it's owed. I used to think that was cruelty. Now I think it might be the only honest law this world has. Nothing stays aloft by accident. Not wind. Not devotion.",
		"reynauld_text": "I hold the wind the way I hold a vigil — badly, and with my arm going numb halfway through. Still, it's the first time this armor hasn't tried to kill me on the way down. I'll take unnatural mercy over natural consequence any day of the week.",
		"input_action": "glide",
		"keybind_hint": "Hold while falling",
	},

	"dash_chain": {
		"name": "Litany Step",
		"description": "A practiced step that may be repeated before the first has faded, though each repetition taxes the body.",
		"tin_text": "Say a thing enough times and the world decides you've used it up. Chant it, mean it, repeat it — the meaning is supposed to survive the repetition, and instead the world taxes you for each recitation until there's nothing left to say. I have said the same three words for eight hundred years. I would like an exception. I have never once received one.",
		"reynauld_text": "Every knight drills the same forms until his arms forget how to do anything else. This isn't so different — same step, over and over, until the body stops asking permission. I only wish my knees had been consulted before agreeing to this many repetitions.",
		"input_action": "dash",
		"keybind_hint": "Chain into a second dash",
	},

	"wall_cling": {
		"name": "Wick Ember",
		"description": "A dying ember that clings to stone. While grasped, it slows the bearer’s fall, though the flame is spent with each moment.",
		"tin_text": "A wick doesn't get to choose how long it burns. It holds on, it gives light, and the whole time it's being consumed for the privilege. I resent that grip is never free. I resent it more that I understand it — I have held on to things for centuries and called it strength, when it was only ever a slower way of running out.",
		"reynauld_text": "My gauntlets are earning their keep tonight. Stone does not care for knuckles, and I suspect my knuckles have opinions about stone they've been too polite to share until now. I'll manage. I've held worse things longer for less reason.",
		"input_action": "",
		"keybind_hint": "Hold toward a wall while airborne",
	},

	"recall": {
		"name": "Star Anchor",
		"description": "A mark that binds the bearer to a chosen place. From afar, the mark may draw them home.",
		"tin_text": "You don't get to return to what you didn't think to keep. That's the law underneath every star chart, every memory, every fool who assumed the past would wait for them to come back and collect it. I mark my place now. Every time. I learned that lesson the hard way, and I intend to make sure I never learn it again.",
		"reynauld_text": "It hauls me backward like I'm on a leash I never agreed to wear, and somehow I don't mind it. I know where the mark is because he put it there. I've decided that's reason enough to trust it. I don't extend that courtesy to much else in this world.",
		"input_action": "recall",
		"keybind_hint": "Press once to place, again to return",
	},

	"ledge_grab": {
		"name": "Censer Swing",
		"description": "A swinging censer that catches the bearer upon a ledge, should one be within reach.",
		"tin_text": "The world does not catch you by default. That's the part nobody tells you. Every ledge, every fall, every threshold — you either seize it yourself or you don't, and the universe watches without opinion either way. I used to think mercy was rare because people were cruel. It's rarer than that. Mercy isn't even the world's job.",
		"reynauld_text": "I've been pulled from worse drops by worse hands. This one, at least, is mine — I catch the edge myself, every time, and no one has to come looking for what's left of me at the bottom. Small comfort. I'll take it.",
		"input_action": "",
		"keybind_hint": "Approach a ledge while falling, Jump to climb",
	},
}

# Big claim-popup illustration per ability — separate from the small
# scripture grid sprite in inventory_ui.gd. Order matches the
# declaration order above (double_jump..ledge_grab -> 1..8).
const ABILITY_TUTORIAL_IMAGES := {
	"double_jump": preload(	"res://assets/ui/tutorials/abilitytutorial1.png"),
	"dash": preload("res://assets/ui/tutorials/abilitytutorial2.png"),
	"ground_slam": preload("res://assets/ui/tutorials/abilitytutorial3.png"),
	"glide": preload("res://assets/ui/tutorials/abilitytutorial4.png"),
	"dash_chain": preload("res://assets/ui/tutorials/abilitytutorial5.png"),
	"wall_cling": preload("res://assets/ui/tutorials/abilitytutorial6.png"),
	"recall": preload("res://assets/ui/tutorials/abilitytutorial7.png"),
	"ledge_grab": preload("res://assets/ui/tutorials/abilitytutorial8.png"),
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
	star_fragments_changed.connect(_on_star_fragments_changed)

# --- Modal UI panels ---
#
# Each full-screen modal registers itself here on open/close instead
# of every panel's toggle handler manually enumerating every other
# panel by name. Adding a new modal (map, potion unlock map, etc.)
# means one register call in that panel — zero edits to existing ones.

var _open_modals: Dictionary = {}  # panel_name -> true

signal modal_opened(panel_name: String)


func register_modal_open(panel_name: String) -> void:
	_open_modals[panel_name] = true
	modal_opened.emit(panel_name)

func register_modal_closed(panel_name: String) -> void:
	_open_modals.erase(panel_name)


func is_other_modal_open(panel_name: String) -> bool:
	for key in _open_modals.keys():
		if key != panel_name:
			return true
	return false

# --- Story beats (one-time cutscenes) ---

var story_beats_seen: Dictionary = {}


func has_seen_story_beat(beat_id: String) -> bool:
	return story_beats_seen.get(beat_id, false)


func mark_story_beat_seen(beat_id: String) -> void:
	story_beats_seen[beat_id] = true

# --- Helpers ---

func _get_game() -> Node:
	var game := get_tree().current_scene

	if game == null:
		push_error("GameState: Current scene not found.")
		return null

	return game

signal star_fragments_changed(amount: int)


func add_star_fragments(amount: int) -> void:
	if amount <= 0:
		return

	star_fragments += amount
	star_fragments_changed.emit(star_fragments)
var opened_chests: Dictionary = {}


func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)


func open_chest(chest_id: String) -> void:
	if chest_id == "":
		return

	if is_chest_opened(chest_id):
		return

	opened_chests[chest_id] = true
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
var is_room_unloading: bool = false
var cleared_gauntlets: Dictionary = {}
 
 
func is_gauntlet_cleared(gauntlet_id: String) -> bool:
	return cleared_gauntlets.has(gauntlet_id)
 
 
func clear_gauntlet(gauntlet_id: String) -> void:
	cleared_gauntlets[gauntlet_id] = true

var defeated_bosses: Dictionary = {}

# Boss

func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.has(boss_id)


func defeat_boss(boss_id: String) -> void:
	if boss_id == "":
		return

	defeated_bosses[boss_id] = true

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

	var mp_gain := SHRINE_MP_GAINS[shrine_count]
	var stamina_gain := SHRINE_STAMINA_GAINS[shrine_count]
	shrine_count += 1

	max_mp += mp_gain
	current_mp = max_mp

	max_stamina += stamina_gain

	if player:
		player.max_mp = max_mp
		player.mp = current_mp
		player.mp_changed.emit(
			player.mp,
			player.max_mp
		)

		if player.has_method("restore_full_stamina"):
			player.restore_full_stamina()

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	await _run_shrine_claim_sequence(
		player,
		mp_gain,
		stamina_gain,
		abandonment_text
	)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false

func _run_shrine_claim_sequence(
	player: Node,
	mp_gain: int,
	stamina_gain: float,
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

	var mp_gain_text := Label.new()
	mp_gain_text.text = "Maximum MP increased by " + str(mp_gain)
	mp_gain_text.add_theme_font_size_override("font_size", 24)
	mp_gain_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mp_gain_text)

	var stamina_gain_text := Label.new()
	stamina_gain_text.text = "Maximum Stamina increased by " + str(int(stamina_gain))
	stamina_gain_text.add_theme_font_size_override("font_size", 24)
	stamina_gain_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stamina_gain_text)

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


func claim_ability(ability_id: String, player: Node, icon: Texture2D = null) -> void:
	if has_ability(ability_id):
		return

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	await _run_claim_sequence(ability_id, player, icon)

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

	# Picture — same "resize to fit, keep aspect, don't hand-resize the
	# source PNG" setup as DetailIcon in inventory_ui.tscn: fixed box
	# via custom_minimum_size + EXPAND_IGNORE_SIZE so the box size wins,
	# STRETCH_KEEP_ASPECT_CENTERED so any resolution PNG fits inside it.
	var picture: Texture2D = ABILITY_TUTORIAL_IMAGES.get(ability_id, icon)

	if picture:
		var picture_rect := TextureRect.new()
		picture_rect.texture = picture
		picture_rect.custom_minimum_size = Vector2(400, 240)
		picture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(picture_rect)

	if data.has("description"):
		var description_label := Label.new()
		description_label.text = data["description"]
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		description_label.custom_minimum_size = Vector2(420, 0)
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(description_label)

	var keybind_text := get_keybind_text(ability_id)

	if keybind_text != "":
		var keybind_label := Label.new()
		keybind_label.text = keybind_text
		keybind_label.modulate.a = 0.8
		keybind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(keybind_label)

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
func soft_respawn_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("respawn"):
			enemy.respawn()

	for gauntlet in get_tree().get_nodes_in_group("gauntlets"):
		if is_instance_valid(gauntlet) and gauntlet.has_method("reset_gauntlet"):
			gauntlet.reset_gauntlet()
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

	var target_scene_path := checkpoint_scene_path if has_checkpoint() else "res://src/rooms/A0R1.tscn"
	var target_checkpoint_id := checkpoint_id if has_checkpoint() else ""

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
		var recovery_fade := create_tween()
		recovery_fade.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
		await recovery_fade.finished
		_transition_lock = false
		return

	var current_room_path := ""

	if game.has_method("get_current_room_scene_path"):
		current_room_path = game.get_current_room_scene_path()

	# The respawn target can live in a different room than the one the
	# player died in (checkpoint set in A1R1, death in A1R2) — only skip
	# the genuine room load when we're already standing in the target room.
	if target_scene_path != current_room_path:
		LoadingScreen.show_loading()
		await game.load_room(target_scene_path)
		LoadingScreen.hide_loading()
	else:
		soft_respawn_enemies()

	if target_checkpoint_id != "" \
	and game.has_method("position_player_at_checkpoint"):
		await game.position_player_at_checkpoint(target_checkpoint_id)
	elif game.has_method("position_player_at_start"):
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
	fade_out.tween_property(_fade_rect, "color:a", 0.75, FADE_DURATION)
	await fade_out.finished

	soft_respawn_enemies()

	var game := _get_game()

	if game and game.has_method("position_player_at_checkpoint"):
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

	refill_potion_at_checkpoint()
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, 0.35)
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
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished

	LoadingScreen.show_loading()

	var game := _get_game()

	if game == null:
		LoadingScreen.hide_loading()
		await _fade_in()
		return

	if not game.has_method("load_room"):
		push_error("GameState: Game instance has no load_room() method.")
		LoadingScreen.hide_loading()
		await _fade_in()
		return

	await game.load_room(target_scene_path)
	LoadingScreen.hide_loading()
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
		pending_spawn_gate_id = ""
		await _fade_in()
		return

	var player = players[0]
	var camera := player.get_node_or_null("Camera2D")

	for gate in gates:
		if gate.gate_id != pending_spawn_gate_id:
			continue

		if camera:
			camera.position_smoothing_enabled = false

		player.global_position = gate.global_position
		player.velocity = Vector2.ZERO

		if player.has_method("lock_input"):
			player.lock_input()
		if player.has_method("enable_collision_only"):
			player.enable_collision_only()

		await get_tree().physics_frame

		pending_spawn_gate_id = ""
		await _start_room_entry(player)

		if camera:
			camera.position_smoothing_enabled = true

		return

	push_error("GameState: Destination gate not found: " + pending_spawn_gate_id)

	pending_spawn_gate_id = ""
	await _fade_in()


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

	var walk_speed: float = 430.0
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
	if not is_instance_valid(player):
		_transition_lock = false
		return

	if player.has_method("lock_input"):
		player.lock_input()

	player.transition_jump_started = false
	player.transition_movement = true
	player.velocity = pending_jump_velocity

	var safety_timer := 3.0

	while safety_timer > 0.0:
		safety_timer -= get_process_delta_time()

		if not is_instance_valid(player):
			_transition_lock = false
			return

		if not player.transition_movement:
			break

		await get_tree().process_frame

	if is_instance_valid(player):
		player.transition_movement = false

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
# --- Wondrous Star Potion ---

const POTION_CATEGORIES := ["survival", "combat", "utility"]

# fragment_cost is a placeholder — lifetime star_fragments total,
# never spent/decremented. Tune once the real curve exists (see
# backlog: star fragment unlock map).
var potion_effect_data: Dictionary = {
	"survival_full_heal": {
		"name": "Vital Draught",
		"category": "survival",
		"description": "Restores your HP to full the moment it's drunk.",
		"fragment_cost": 300,
	},
	"survival_full_mana": {
		"name": "Mnemonic Draught",
		"category": "survival",
		"description": "Restores your MP to full the moment it's drunk.",
		"fragment_cost": 300,
	},
	"combat_double_sword": {
		"name": "Ember Edge",
		"category": "combat",
		"description": "Doubles your sword damage for a short time.",
		"fragment_cost": 600,
		"duration": 15.0,
	},
	"combat_damage_reduction": {
		"name": "Aegis Draught",
		"category": "combat",
		"description": "Halves incoming combat damage for a short time.",
		"fragment_cost": 600,
		"duration": 15.0,
	},
	"utility_speed": {
		"name": "Fleetfoot Draught",
		"category": "utility",
		"description": "Increases movement speed for a short time.",
		"fragment_cost": 450,
		"duration": 15.0,
	},
	"utility_infinite_stamina": {
		"name": "Tireless Draught",
		"category": "utility",
		"description": "Grants unlimited stamina for a short time.",
		"fragment_cost": 450,
		"duration": 15.0,
	},
}

var unlocked_potion_slots: Dictionary = {}     # category -> true
var unlocked_potion_effects: Dictionary = {}   # effect_id -> true

var selected_potion_effects: Dictionary = {
	"survival": "",
	"combat": "",
	"utility": "",
}

var potion_charged: bool = false   # true once mixed, false after drinking

var _checkpoint_range_count: int = 0

signal potion_slot_unlocked(category: String)
signal potion_effect_unlocked(effect_id: String)
signal potion_mix_changed()
signal potion_used()


# --- Slots (world pickups) ---

func is_potion_slot_unlocked(category: String) -> bool:
	return unlocked_potion_slots.has(category)


func unlock_potion_slot(category: String) -> void:
	if is_potion_slot_unlocked(category):
		return

	unlocked_potion_slots[category] = true
	potion_slot_unlocked.emit(category)
func has_any_potion_slot_unlocked() -> bool:
	return not unlocked_potion_slots.is_empty()


# Returns effect_ids ordered by ascending fragment_cost — the order
# the linear Potion Unlock Map chains them in. Ties keep their
# original potion_effect_data declaration order.
func get_potion_effects_by_progression() -> Array:
	var ids := potion_effect_data.keys()
	var original_order := {}

	for i in ids.size():
		original_order[ids[i]] = i

	ids.sort_custom(func(a, b):
		var cost_a: int = potion_effect_data[a].get("fragment_cost", 0)
		var cost_b: int = potion_effect_data[b].get("fragment_cost", 0)

		if cost_a == cost_b:
			return original_order[a] < original_order[b]

		return cost_a < cost_b
	)

	return ids

# --- Effects (fragment-gated, never picked up in the world) ---

func is_potion_effect_unlocked(effect_id: String) -> bool:
	return unlocked_potion_effects.has(effect_id)


func get_effects_for_category(category: String) -> Array:
	var result: Array = []

	for effect_id in potion_effect_data.keys():
		if potion_effect_data[effect_id].get("category") == category:
			result.append(effect_id)

	return result


func _on_star_fragments_changed(_amount: int) -> void:
	_check_potion_effect_unlocks()


# Fragments are lifetime total, never spent. Every locked effect
# whose threshold is now met unlocks automatically. Once the star
# fragment unlock map exists, this becomes "player picks which
# locked effect to spend toward" instead of auto-unlocking in order.
func _check_potion_effect_unlocks() -> void:
	for effect_id in potion_effect_data.keys():
		if is_potion_effect_unlocked(effect_id):
			continue

		var cost: int = potion_effect_data[effect_id].get("fragment_cost", 0)

		if star_fragments >= cost:
			unlocked_potion_effects[effect_id] = true
			potion_effect_unlocked.emit(effect_id)


# --- Mixing ---

func set_selected_potion_effect(category: String, effect_id: String) -> void:
	if not POTION_CATEGORIES.has(category):
		return
	if not is_potion_slot_unlocked(category):
		return
	if effect_id != "" and not is_potion_effect_unlocked(effect_id):
		return

	selected_potion_effects[category] = effect_id
	potion_charged = _has_any_potion_selection()

	potion_mix_changed.emit()

func _has_any_potion_selection() -> bool:
	for category in POTION_CATEGORIES:
		if selected_potion_effects[category] != "":
			return true

	return false


func _clear_potion_selection() -> void:
	for category in POTION_CATEGORIES:
		selected_potion_effects[category] = ""

func clear_potion_mix() -> void:
	if not can_mix_potion():
		return

	_clear_potion_selection()
	potion_charged = false
	potion_mix_changed.emit()
# Resting only recharges the existing mix — never touches the
# selection, so the player is never forced to remix.
func refill_potion_at_checkpoint() -> void:
	if _has_any_potion_selection():
		potion_charged = true
		potion_mix_changed.emit()


func use_potion(player: Node) -> void:
	if not potion_charged:
		return

	if player == null or not is_instance_valid(player):
		return

	if player.get("is_dead") == true:
		return

	for category in POTION_CATEGORIES:
		var effect_id: String = selected_potion_effects[category]

		if effect_id != "":
			_apply_potion_effect(effect_id, player)

	potion_charged = false
	potion_used.emit()


func _apply_potion_effect(effect_id: String, player: Node) -> void:
	var data: Dictionary = potion_effect_data.get(effect_id, {})
	var duration: float = data.get("duration", 0.0)

	match effect_id:
		"survival_full_heal":
			if player.has_method("restore_full_health"):
				player.restore_full_health()

		"survival_full_mana":
			if player.has_method("restore_full_mp"):
				player.restore_full_mp()

		"combat_double_sword":
			if player.has_method("apply_double_sword_damage"):
				player.apply_double_sword_damage(duration)

		"combat_damage_reduction":
			if player.has_method("apply_damage_reduction"):
				player.apply_damage_reduction(duration)

		"utility_speed":
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(duration)

		"utility_infinite_stamina":
			if player.has_method("apply_infinite_stamina"):
				player.apply_infinite_stamina(duration)


# --- Checkpoint proximity (gates mixing only, not drinking) ---

func enter_checkpoint_range() -> void:
	_checkpoint_range_count += 1


func exit_checkpoint_range() -> void:
	_checkpoint_range_count = max(0, _checkpoint_range_count - 1)


func is_near_checkpoint() -> bool:
	return _checkpoint_range_count > 0


func can_mix_potion() -> bool:
	return is_near_checkpoint()
# --- Save system ---

func get_save_data() -> Dictionary:
	return {
		"abilities": abilities.duplicate(),
		"max_mp": max_mp,
		"max_health": max_health,
		"max_stamina": max_stamina,
		"shrine_count": shrine_count,
		"claimed_anvils": claimed_anvils.duplicate(),
		"claimed_shrines": claimed_shrines.duplicate(true),
		"star_fragments": star_fragments,
		"armor_tier": armor_tier,
		"activated_checkpoints": activated_checkpoints.duplicate(),
		"checkpoint_scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"checkpoint_room_name": checkpoint_room_name,
		"tutorials_seen": tutorials_seen.duplicate(),
		"collected_keys": collected_keys.duplicate(),
		"opened_doors": opened_doors.duplicate(),
		"opened_chests": opened_chests.duplicate(),
		"broken_obstacles": broken_obstacles.duplicate(),
		"revealed_secrets": revealed_secrets.duplicate(),
		"activated_shortcuts": activated_shortcuts.duplicate(),
		"cleared_gauntlets": cleared_gauntlets.duplicate(),
		"defeated_bosses": defeated_bosses.duplicate(),
		"area_names_seen": area_names_seen.duplicate(),
		"story_beats_seen": story_beats_seen.duplicate(),
		"unlocked_potion_slots": unlocked_potion_slots.duplicate(),
		"unlocked_potion_effects": unlocked_potion_effects.duplicate(),
		"selected_potion_effects": selected_potion_effects.duplicate(),
		"potion_charged": potion_charged,
	}


func apply_save_data(data: Dictionary) -> void:
	abilities = data.get("abilities", abilities)
	max_mp = data.get("max_mp", max_mp)
	current_mp = max_mp
	max_health = data.get("max_health", max_health)
	max_stamina = data.get("max_stamina", max_stamina)
	shrine_count = data.get("shrine_count", 0)
	star_fragments = data.get("star_fragments", 0)
	claimed_anvils = data.get("claimed_anvils", {})
	claimed_shrines = data.get("claimed_shrines", {})
	armor_tier = data.get("armor_tier", armor_tier)
	activated_checkpoints = data.get("activated_checkpoints", {})
	checkpoint_scene_path = data.get("checkpoint_scene_path", "")
	checkpoint_id = data.get("checkpoint_id", "")
	checkpoint_room_name = data.get("checkpoint_room_name", "")
	collected_keys = data.get("collected_keys", {})
	opened_doors = data.get("opened_doors", {})
	opened_chests = data.get("opened_chests", {})
	broken_obstacles = data.get("broken_obstacles", {})
	revealed_secrets = data.get("revealed_secrets", {})
	activated_shortcuts = data.get("activated_shortcuts", {})
	cleared_gauntlets = data.get("cleared_gauntlets", {})
	defeated_bosses = data.get("defeated_bosses", {})
	area_names_seen = data.get("area_names_seen", {})
	story_beats_seen = data.get("story_beats_seen", {})
	tutorials_seen = data.get("tutorials_seen", {
		"movement": false,
		"jump": false,
		"attack": false,
	}).duplicate()
	unlocked_potion_slots = data.get("unlocked_potion_slots", {})
	unlocked_potion_effects = data.get("unlocked_potion_effects", {})
	selected_potion_effects = data.get("selected_potion_effects", {
		"survival": "",
		"combat": "",
		"utility": "",
	})
	potion_charged = data.get("potion_charged", false)
	_check_potion_effect_unlocks()


func reset_to_defaults() -> void:
	for key in abilities.keys():
		abilities[key] = false

	max_mp = 6
	current_mp = 6
	max_health = 5
	armor_tier = 0
	shrine_count = 0
	star_fragments = 0
	max_stamina = 100.0
	claimed_anvils.clear()
	claimed_shrines.clear()
	activated_checkpoints.clear()
	opened_chests.clear()

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
	defeated_bosses.clear()
	area_names_seen.clear()
	story_beats_seen.clear()
	unlocked_potion_slots.clear()
	unlocked_potion_effects.clear()
	_clear_potion_selection()
	potion_charged = false


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
