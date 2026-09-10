extends CanvasLayer


@export var scripture_icons: Dictionary = {
	"double_jump": preload("res://assets/ui/scripture/scripture1.png"),
	"dash": preload("res://assets/ui/scripture/scripture2.png"),
	"ground_slam": preload("res://assets/ui/scripture/scripture3.png"),
	"glide": preload("res://assets/ui/scripture/scripture4.png"),
	"dash_chain": preload("res://assets/ui/scripture/scripture5.png"),
	"wall_cling": preload("res://assets/ui/scripture/scripture6.png"),
	"recall": preload("res://assets/ui/scripture/scripture7.png"),
	"ledge_grab": preload("res://assets/ui/scripture/scripture8.png"),
}  # ability_id -> Texture2D (grid sprite)
@export var ability_images: Dictionary = {}     # ability_id -> Texture2D (large illustration, NOT the sprite — spec requires a separate image here)
@export var shard_icon: Texture2D               # fallback Starlight Shard symbol
@export var shard_icons: Dictionary = {
	"shrine01": preload("res://assets/ui/shards/shard01.png"),
	"shrine02": preload("res://assets/ui/shards/shard02.png"),
	"shrine03": preload("res://assets/ui/shards/shard03.png"),
	"shrine04": preload("res://assets/ui/shards/shard04.png"),
	"shrine05": preload("res://assets/ui/shards/shard05.png")
} # Will use placeholder fallback shard for now while i work on 6-17
@export var sword_icon: Texture2D
@export var armor_icons: Dictionary = {
	0: preload("res://assets/ui/armor/armor1.png"),
	1: preload("res://assets/ui/armor/armor2.png"),
	2: preload("res://assets/ui/armor/armor3.png"),
	3: preload("res://assets/ui/armor/armor4.png"),
	4: preload("res://assets/ui/armor/armor5.png"),
	5: preload("res://assets/ui/armor/armor6.png")
}     # armor_tier (int) -> Texture2D
@export var star_fragment_icon: Texture2D
@export var icon_button_scene: PackedScene

# Primeval Star Potion flask — one sprite per unlock combination.
# Key = "<starhearth><starbriar><stargleam>", each digit 1/0.
@export var potion_flask_icons: Dictionary = {
	"000": preload("res://assets/ui/potionbottle/PSP-000.png"),
	"100": preload("res://assets/ui/potionbottle/PSP-100.png"),
	"010": preload("res://assets/ui/potionbottle/PSP-010.png"),
	"001": preload("res://assets/ui/potionbottle/PSP-001.png"),
	"110": preload("res://assets/ui/potionbottle/PSP-110.png"),
	"101": preload("res://assets/ui/potionbottle/PSP-101.png"),
	"011": preload("res://assets/ui/potionbottle/PSP-011.png"),
	"111": preload("res://assets/ui/potionbottle/PSP-111.png"),
}
@export var prayerbook_icon: Texture2D = preload("res://assets/ui/prayerbook.png")


const SWORD_DESCRIPTION := "Reyrey's blade, carried since before the road began.\n\nThe ancestral sword of House Valecourt, stolen by Reyrey and replaced with a normal-looking longsword.\n\n\"No one uses it anyways, why must it collect dust? I'm just borrowing it, until I get back home.\""
const SWORD_KEYBIND := "Mouse1 / F — Swing"
const SHARD_FLAVOR_HEADER := "Upon this shrine, the remnants of a star remain"

const POTION_FLASK_SUBTITLES := {
	"000": "Sealed",
	"100": "Starhearth",
	"010": "Starbriar",
	"001": "Stargleam",
	"110": "Starhearth · Starbriar",
	"101": "Starhearth · Stargleam",
	"011": "Starbriar · Stargleam",
	"111": "Starhearth · Starbriar · Stargleam",
}

const POTION_FLASK_DESCRIPTIONS := {
	"000": "An empty flask. It waits for something worth keeping.",
	"100": "Warmth bottled against the dark. What heals lingers here, patient.",
	"010": "A thorn steeped in old defiance. Strength for when the blade isn't enough.",
	"001": "A shimmer that never quite settles. Borrowed speed, borrowed breath.",
	"110": "Warmth and thorn, mingled close. What mends you, and what lets you mend the fight.",
	"101": "Warmth and shimmer, entwined. What restores you also carries you faster.",
	"011": "Thorn and shimmer, bound together. What strikes harder also outlasts.",
	"111": "Warmth, thorn, and shimmer — the flask holds all three, waiting to be chosen.",
}

const PRAYERBOOK_DESCRIPTION := "Every knight is taught to trust the stars. I was no different. I keep this book beside me still, though I find it harder each day to believe what it asks of me."

@onready var root_panel: Control = $RootPanel

@onready var key_item_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/KeyItemsSection/KeyItemScroll/KeyItemGrid
@onready var shard_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ShardsSection/ShardScroll/ShardGrid

@onready var key_items_section: VBoxContainer = $RootPanel/MainFrame/Layout/MiddleColumn/KeyItemsSection
@onready var middle_separator: Control = $RootPanel/MainFrame/Layout/MiddleColumn/MiddleSeparator
@onready var shards_section: VBoxContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ShardsSection

@onready var prayerbook_overlay: VBoxContainer = $RootPanel/MainFrame/Layout/MiddleColumn/PrayerbookOverlay
@onready var prayerbook_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/PrayerbookOverlay/PrayerbookScroll/PrayerbookGrid

@onready var sword_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/SwordButton
@onready var armor_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ArmorButton
@onready var shard_currency_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ShardCurrencyButton
@onready var potion_flask_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/PotionFlaskButton
@onready var prayerbook_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/PrayerbookButton

@onready var detail_name_top: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailNameTop
@onready var detail_icon: TextureRect = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailIcon
@onready var detail_name_bottom: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailNameBottom
@onready var detail_shard_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailShardHeader
@onready var detail_description: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailDescription
@onready var detail_keybind: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailKeybind
@onready var detail_tin_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailTinHeader
@onready var detail_tin_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailTinText
@onready var detail_reynauld_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailReynauldHeader
@onready var detail_reynauld_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailReynauldText

var is_open := false
var prayerbook_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.hide()
	root_panel.modulate.a = 0.0

	sword_button.setup("sword", sword_icon)
	sword_button.hovered.connect(func(_id): _show_sword())

	armor_button.setup("armor", armor_icons.get(GameState.armor_tier))
	armor_button.hovered.connect(func(_id): _show_armor())

	shard_currency_button.setup("star_fragments", star_fragment_icon)
	shard_currency_button.hovered.connect(func(_id): _show_star_fragments())

	potion_flask_button.setup("potion_flask", _get_potion_flask_icon())
	potion_flask_button.hovered.connect(func(_id): _show_potion_flask())

	prayerbook_button.setup("prayerbook", prayerbook_icon)
	prayerbook_button.hovered.connect(func(_id): _show_prayerbook())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("inventory"):
		return

	if is_open:
		toggle()
		return

	if not GameState.can_trigger_gate() or GameState.is_other_modal_open("inventory"):
		return

	toggle()


# Handles the prayerbook's own open/close interaction. Everything
# else in this UI is pure hover — the prayerbook is the one entry
# that needs a real "press E to read" action, so it gets a _process
# check instead of a signal.
func _process(_delta: float) -> void:
	if not is_open:
		return

	if not prayerbook_open \
	and prayerbook_button.has_focus() \
	and Input.is_action_just_pressed("interact"):
		_open_prayerbook()
		return

	if prayerbook_open and Input.is_action_just_pressed("ui_cancel"):
		_close_prayerbook()


func toggle() -> void:
	close() if is_open else open()


func open() -> void:
	is_open = true
	GameState.register_modal_open("inventory")
	_populate()

	root_panel.show()
	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 1.0, 0.15)

	sword_button.grab_focus()


func close() -> void:
	is_open = false
	GameState.register_modal_closed("inventory")

	get_viewport().gui_release_focus()

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(root_panel.hide)
	tween.tween_callback(func():
		get_tree().paused = false
	)


func _populate() -> void:
	_clear_grid(key_item_grid)
	_clear_grid(shard_grid)

	var shard_ids := GameState.claimed_shrines.keys()

	shard_ids.sort_custom(func(a, b):
		return GameState.claimed_shrines[a].get("order", 0) < GameState.claimed_shrines[b].get("order", 0)
	)

	for shrine_id in shard_ids:
		var button := _spawn_icon(
			shard_grid,
			shrine_id,
			shard_icons.get(shrine_id, shard_icon)
		)
		button.hovered.connect(_show_shard)

	armor_button.icon_rect.texture = armor_icons.get(GameState.armor_tier)
	shard_currency_button.set_count(GameState.star_fragments)
	potion_flask_button.icon_rect.texture = _get_potion_flask_icon()

	_reset_prayerbook_view()

	_wire_focus_neighbors()

	_show_sword()


func _spawn_icon(
	grid: GridContainer,
	id: String,
	icon: Texture2D
) -> InventoryIconButton:
	var button: InventoryIconButton = icon_button_scene.instantiate()

	grid.add_child(button)
	button.setup(id, icon)

	return button


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


# Godot's automatic geometric focus-neighbor detection breaks down
# across very different container types (freeform LeftColumn vs.
# scrolled grids) — this wires the important cross-boundary links by
# hand so arrow-key navigation is deterministic. Navigation *within*
# a single grid still relies on Godot's automatic system, since that
# works fine on a uniform grid.
func _wire_focus_neighbors() -> void:
	sword_button.focus_neighbor_bottom = sword_button.get_path_to(armor_button)
	armor_button.focus_neighbor_top = armor_button.get_path_to(sword_button)
	armor_button.focus_neighbor_bottom = armor_button.get_path_to(shard_currency_button)
	shard_currency_button.focus_neighbor_top = shard_currency_button.get_path_to(armor_button)
	shard_currency_button.focus_neighbor_bottom = shard_currency_button.get_path_to(potion_flask_button)
	potion_flask_button.focus_neighbor_top = potion_flask_button.get_path_to(shard_currency_button)
	potion_flask_button.focus_neighbor_bottom = potion_flask_button.get_path_to(prayerbook_button)
	prayerbook_button.focus_neighbor_top = prayerbook_button.get_path_to(potion_flask_button)

	var shard_buttons := shard_grid.get_children()

	var first_middle_button: Control = null

	if not shard_buttons.is_empty():
		first_middle_button = shard_buttons[0]

	if first_middle_button:
		sword_button.focus_neighbor_right = sword_button.get_path_to(first_middle_button)
		armor_button.focus_neighbor_right = armor_button.get_path_to(first_middle_button)
		shard_currency_button.focus_neighbor_right = shard_currency_button.get_path_to(first_middle_button)
		potion_flask_button.focus_neighbor_right = potion_flask_button.get_path_to(first_middle_button)
		prayerbook_button.focus_neighbor_right = prayerbook_button.get_path_to(first_middle_button)
		first_middle_button.focus_neighbor_left = first_middle_button.get_path_to(prayerbook_button)


# --- Prayerbook overlay ---
#
# The prayerbook doesn't float above the middle column — it swaps
# into the same space. Hiding KeyItemsSection/MiddleSeparator/
# ShardsSection removes them from the VBoxContainer's layout, so
# PrayerbookOverlay (also a direct child of MiddleColumn) simply
# expands to fill the space they leave behind.

func _reset_prayerbook_view() -> void:
	prayerbook_open = false
	prayerbook_overlay.hide()
	key_items_section.show()
	middle_separator.show()
	shards_section.show()


func _open_prayerbook() -> void:
	prayerbook_open = true

	key_items_section.hide()
	middle_separator.hide()
	shards_section.hide()

	_populate_prayerbook_grid()

	prayerbook_overlay.show()

	var scripture_buttons := prayerbook_grid.get_children()

	if not scripture_buttons.is_empty():
		scripture_buttons[0].grab_focus()


func _close_prayerbook() -> void:
	prayerbook_open = false

	prayerbook_overlay.hide()
	key_items_section.show()
	middle_separator.show()
	shards_section.show()

	prayerbook_button.grab_focus()
	_show_prayerbook()


func _populate_prayerbook_grid() -> void:
	_clear_grid(prayerbook_grid)

	for ability_id in GameState.abilities.keys():
		if not GameState.has_ability(ability_id):
			continue

		var button := _spawn_icon(
			prayerbook_grid,
			ability_id,
			scripture_icons.get(ability_id)
		)
		button.custom_minimum_size = Vector2(110, 110)
		button.hovered.connect(_show_scripture)
# --- Potion flask state ---

func _get_potion_state_code() -> String:
	var code := ""
	code += "1" if GameState.is_potion_slot_unlocked("survival") else "0"
	code += "1" if GameState.is_potion_slot_unlocked("combat") else "0"
	code += "1" if GameState.is_potion_slot_unlocked("utility") else "0"
	return code


func _get_potion_flask_icon() -> Texture2D:
	return potion_flask_icons.get(
		_get_potion_state_code(),
		potion_flask_icons.get("000")
	)


func _clear_detail() -> void:
	detail_name_top.hide()
	detail_icon.hide()
	detail_name_bottom.hide()
	detail_shard_header.hide()
	detail_description.hide()
	detail_keybind.hide()
	detail_tin_header.hide()
	detail_tin_text.hide()
	detail_reynauld_header.hide()
	detail_reynauld_text.hide()


func _show_sword() -> void:
	_clear_detail()

	detail_name_top.text = "Sword"
	detail_name_top.show()

	detail_name_bottom.text = "Tidesplitter"
	detail_name_bottom.show()

	detail_description.text = SWORD_DESCRIPTION
	detail_description.show()

	detail_keybind.text = SWORD_KEYBIND
	detail_keybind.show()


func _show_armor() -> void:
	_clear_detail()

	var data := GameState.get_armor_data()
	var armor_name: String = data.get("name", "Armor")

	detail_name_top.text = "Armor"
	detail_name_top.show()

	detail_name_bottom.text = armor_name
	detail_name_bottom.show()

	detail_description.text = data.get("description", "")
	detail_description.show()


func _show_star_fragments() -> void:
	_clear_detail()

	detail_name_top.text = "Currency"
	detail_name_top.show()

	detail_name_bottom.text = "Star Fragments"
	detail_name_bottom.show()

	detail_description.text = "%d collected. Spent at shrines and anvils along the road." % GameState.star_fragments
	detail_description.show()


func _show_potion_flask() -> void:
	_clear_detail()

	var code := _get_potion_state_code()

	detail_name_top.text = "Primeval Star Potion"
	detail_name_top.show()

	detail_name_bottom.text = POTION_FLASK_SUBTITLES.get(code, "")
	detail_name_bottom.show()

	detail_icon.texture = potion_flask_icons.get(code, potion_flask_icons.get("000"))
	detail_icon.show()

	detail_description.text = POTION_FLASK_DESCRIPTIONS.get(code, "")
	detail_description.show()

	detail_keybind.text = "P — Mix\nO — Map"
	detail_keybind.show()


func _show_prayerbook() -> void:
	_clear_detail()

	detail_name_top.text = "Axiom Knight's\nPrayerbook"
	detail_name_top.show()

	detail_icon.texture = prayerbook_icon
	detail_icon.show()

	detail_description.text = PRAYERBOOK_DESCRIPTION
	detail_description.show()

	detail_keybind.text = "E — Read"
	detail_keybind.show()


func _show_scripture(ability_id: String) -> void:
	_clear_detail()

	var data: Dictionary = GameState.ability_data.get(ability_id, {})

	detail_name_top.text = data.get("name", ability_id.capitalize())
	detail_name_top.show()

	# Deliberately NOT the grid sprite — spec calls for a separate
	# illustration. Falls back to the sprite until you assign one in
	# the Inspector, so nothing renders blank in the meantime.
	detail_icon.texture = ability_images.get(ability_id, scripture_icons.get(ability_id))
	detail_icon.show()

	detail_description.text = data.get("description", "")
	detail_description.show()

	var keybind_text := GameState.get_keybind_text(ability_id)

	if keybind_text != "":
		detail_keybind.text = keybind_text
		detail_keybind.show()

	if data.has("tin_text"):
		detail_tin_header.show()
		detail_tin_text.text = data["tin_text"]
		detail_tin_text.show()

	if data.has("reynauld_text"):
		detail_reynauld_header.show()
		detail_reynauld_text.text = data["reynauld_text"]
		detail_reynauld_text.show()


func _show_shard(shrine_id: String) -> void:
	_clear_detail()

	var shard_data: Dictionary = GameState.claimed_shrines.get(shrine_id, {})

	detail_icon.texture = shard_icons.get(shrine_id, shard_icon)
	detail_icon.show()

	detail_shard_header.text = SHARD_FLAVOR_HEADER
	detail_shard_header.show()

	detail_description.text = shard_data.get("text", "")
	detail_description.show()
