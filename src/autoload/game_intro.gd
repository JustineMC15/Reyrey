extends CanvasLayer
# game_intro.gd — autoload singleton "GameIntro"
#
# One-time poem intro for a brand new save. Deliberately separate
# from Cutscene (which still handles every other story beat) — this
# has its own black backdrop, its own drifting-ash atmosphere
# (borrowed from main_menu.tscn's GPUParticles2D setup), and its own
# line-by-line fade pacing suited to a short verse rather than
# dialogue.
#
# Usage:
#   await GameIntro.play()
#
# game.gd is responsible for keeping room music silent until this
# returns — see the suppress_music param on Game.load_room().

const BODY_FONT := preload("res://assets/fonts/Seshat.otf")
const ASH_TEXTURE := preload("res://assets/environment/parallax/ash.png")

const LINE_FADE_DURATION := 0.6
const LINE_HOLD_AFTER := 1.1
const CITATION_HOLD_BEFORE := 1.6
const CITATION_FADE_DURATION := 0.8
const FULL_HOLD_DURATION := 3.5
const CONTENT_FADE_OUT_DURATION := 1.0
const BLACK_HOLD_DURATION := 0.5
const FINAL_FADE_DURATION := 1.0

const POEM_LINES := [
	"A thousand years the sky has not moved, and called it mercy.",
	"Ice does not forgive. It only keeps.",
	"Somewhere a star wears the shape of broken glass,",
	"walking north with a name it means to give away.",
	"It will not ask if you are ready.",
	"Only whose crest you wear above your heart.",
]

const CITATION_TEXT := "Axiom Cathedral reliquary — hand unknown, ink pre-dating the founding charter"

var _busy := false

var _root: Control
var _background: ColorRect
var _particles: GPUParticles2D
var _content: VBoxContainer
var _line_labels: Array[Label] = []
var _citation_wrapper: MarginContainer


func _ready() -> void:
	layer = 501
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_background = ColorRect.new()
	_background.color = Color.BLACK
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_background)

	_build_particles()

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_content.grow_vertical = Control.GROW_DIRECTION_BOTH
	_content.add_theme_constant_override("separation", 18)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)

	for line_text in POEM_LINES:
		var label := Label.new()
		label.text = line_text
		label.add_theme_font_override("font", BODY_FONT)
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(760, 0)
		label.modulate.a = 0.0
		_content.add_child(label)
		_line_labels.append(label)

	var citation_spacer := Control.new()
	citation_spacer.custom_minimum_size = Vector2(0, 26)
	_content.add_child(citation_spacer)

	var citation_label := Label.new()
	citation_label.text = CITATION_TEXT
	citation_label.add_theme_font_override("font", BODY_FONT)
	citation_label.add_theme_font_size_override("font_size", 18)
	citation_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6, 0.85))
	citation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	citation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	citation_label.custom_minimum_size = Vector2(640, 0)

	# Wider left margin than right — reads as a set-apart, indented
	# attribution line rather than another line of verse.
	_citation_wrapper = MarginContainer.new()
	_citation_wrapper.add_theme_constant_override("margin_left", 110)
	_citation_wrapper.add_theme_constant_override("margin_right", 10)
	_citation_wrapper.modulate.a = 0.0
	_citation_wrapper.add_child(citation_label)
	_content.add_child(_citation_wrapper)


func _build_particles() -> void:
	_particles = GPUParticles2D.new()
	_particles.texture = ASH_TEXTURE
	_particles.amount = 500
	_particles.lifetime = 4.0
	_particles.preprocess = 8.0
	_particles.speed_scale = 0.5
	_particles.local_coords = true
	_particles.position = Vector2(592, 291)
	_particles.visibility_rect = Rect2(-750, -350, 1500, 700)
	_particles.emitting = false

	var process_material := ParticleProcessMaterial.new()
	process_material.lifetime_randomness = 0.5
	process_material.particle_flag_disable_z = true
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(1000, 500, 1)
	process_material.direction = Vector3(-3, 1, 0)
	process_material.initial_velocity_min = 200.0
	process_material.initial_velocity_max = 400.0
	process_material.gravity = Vector3(0, 200, 0)
	process_material.scale_min = 2.5
	process_material.scale_max = 5.0
	_particles.process_material = process_material

	_root.add_child(_particles)


func play() -> void:
	if _busy:
		return

	_busy = true

	for label in _line_labels:
		label.modulate.a = 0.0

	_citation_wrapper.modulate.a = 0.0
	_root.modulate.a = 1.0
	_content.modulate.a = 1.0

	_particles.emitting = true
	visible = true

	for label in _line_labels:
		await _fade_in(label, LINE_FADE_DURATION)
		await get_tree().create_timer(LINE_HOLD_AFTER).timeout

	await get_tree().create_timer(CITATION_HOLD_BEFORE).timeout
	await _fade_in(_citation_wrapper, CITATION_FADE_DURATION)

	await get_tree().create_timer(FULL_HOLD_DURATION).timeout

	var content_fade := create_tween()
	content_fade.tween_property(_content, "modulate:a", 0.0, CONTENT_FADE_OUT_DURATION)
	await content_fade.finished

	await get_tree().create_timer(BLACK_HOLD_DURATION).timeout

	var final_fade := create_tween()
	final_fade.tween_property(_root, "modulate:a", 0.0, FINAL_FADE_DURATION)
	await final_fade.finished

	_particles.emitting = false
	visible = false

	_busy = false


func _fade_in(node: CanvasItem, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	await tween.finished
