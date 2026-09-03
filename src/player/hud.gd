extends Control

@onready var hp_bar: TextureProgressBar = $HpBar
@onready var hp_bar_glow: TextureProgressBar = $HpBarGlow
@onready var hp_damage_bar: TextureProgressBar = $HpDamageBar
@onready var hp_empty_bar: NinePatchRect = $HpEmptyBar
@onready var hp_frame: NinePatchRect = $HpFrame
@onready var hp_frame_glow: TextureRect = $HpFrameGlow
@onready var hp_star: Sprite2D = $HpStar
@onready var hp_star_glow: Sprite2D = $HpStarGlow
@onready var hp_star_particles: GPUParticles2D = $HpStar/HpStarFlicker

@onready var mp_bar: ProgressBar = $MpBar
@onready var mp_damage_bar: ProgressBar = $MpDamageBar
@onready var mp_core: Sprite2D = $MpCore
@onready var mp_core_glow: Sprite2D = $MpCoreGlow

@onready var stamina_bar: ProgressBar = $StBar
@onready var stamina_damage_bar: ProgressBar = $StDamageBar
@onready var stamina_core: Sprite2D = $StaminaCore
@onready var stamina_core_glow: Sprite2D = $StaminaCoreGlow

@onready var star_fragment_reward: StarFragmentReward = $StarFragmentReward
var potion_indicator: Label

# --- HP bar sizing ---
# 9-patch stretch on HPBar/HPBarGlow/HPDamageBar/HpEmptyBar is 100px
# left / 40px right margin (set in the editor). Only the right offset
# grows here; left offset stays anchored at the star.
const HP_BAR_WIDTH_PER_HEALTH := 50.0
const HP_BAR_BASE_OFFSET_LEFT := 135.0
const HP_FRAME_BASE_OFFSET_LEFT := 127.0
const HP_FRAME_RIGHT_PADDING := 35.0
const HP_GLOW_OVERSHOOT := 20.0

# --- HP color/glow tuning (shader-driven, tweened by health_ratio) ---
const HEALTH_TWEEN_DURATION := 0.4
const HEALTH_LOW_THRESHOLD := 0.35

# --- HP fill-value drain animation (the bar itself receding) ---
# Separate from the color/glow tween above — this animates the actual
# TextureProgressBar.value instead of snapping it.
const HP_DRAIN_DURATION := 0.25       # main bar + its glow, drains fast
const HP_DAMAGE_TRAIL_DURATION := 0.6 # damage overlay, catches up slower

const STAR_GLOW_MIN_SCALE := 0.55
const STAR_GLOW_MAX_SCALE := 1.0
const STAR_GLOW_MIN_INTENSITY := 0.25
const STAR_GLOW_MAX_INTENSITY := 1.3

const BAR_GLOW_MIN_INTENSITY := 0.35
const BAR_GLOW_MAX_INTENSITY := 1.2

const FRAME_GLOW_MIN_INTENSITY := 0.3
const FRAME_GLOW_MAX_INTENSITY := 0.9

# --- MP / Stamina core glow tuning ---
# Fixed size icons — only the halo's intensity/scale reacts to the
# current/max ratio, no resizing, ever.
const MP_GLOW_MIN_INTENSITY := 0.2
const MP_GLOW_MAX_INTENSITY := 1.2
const MP_GLOW_MIN_SCALE := 0.6
const MP_GLOW_MAX_SCALE := 1.0

const STAMINA_GLOW_MIN_INTENSITY := 0.2
const STAMINA_GLOW_MAX_INTENSITY := 1.2
const STAMINA_GLOW_MIN_SCALE := 0.6
const STAMINA_GLOW_MAX_SCALE := 1.0

const RESOURCE_GLOW_TWEEN_DURATION := 0.4

var _last_max_health := -1
var _current_health_ratio := 1.0
var _health_tween: Tween
var _hp_value_tween: Tween

var _current_mp_ratio := 1.0
var _mp_glow_tween: Tween

var _current_stamina_ratio := 1.0
var _stamina_glow_tween: Tween


func _ready() -> void:
	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("HUD: Could not find Player in the 'player' group.")
		return

	_update_bar_length(player.max_health)
	_last_max_health = player.max_health

	hp_bar.max_value = player.max_health
	hp_bar.value = player.health
	hp_bar_glow.max_value = player.max_health
	hp_bar_glow.value = player.health

	hp_damage_bar.max_value = player.max_health
	hp_damage_bar.value = player.health

	mp_bar.max_value = player.max_mp
	mp_bar.value = player.mp

	mp_damage_bar.max_value = player.max_mp
	mp_damage_bar.value = player.mp

	if stamina_bar and stamina_damage_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.stamina

		stamina_damage_bar.max_value = player.max_stamina
		stamina_damage_bar.value = player.stamina

	_apply_health_visuals(player.health, player.max_health, true)
	_apply_mp_visuals(player.mp, player.max_mp, true)
	_apply_stamina_visuals(player.stamina, player.max_stamina, true)

	# Initialize the Star Fragment display without showing it.
	star_fragment_reward.initialize_amount(
		GameState.star_fragments
	)

	# Listen for new Star Fragment rewards.
	if not GameState.star_fragments_changed.is_connected(
		_on_star_fragments_changed
	):
		GameState.star_fragments_changed.connect(
			_on_star_fragments_changed
		)

	player.health_changed.connect(_on_player_health_changed)
	player.mp_changed.connect(_on_player_mp_changed)
	player.stamina_changed.connect(_on_player_stamina_changed)
	potion_indicator = Label.new()
	potion_indicator.text = "POTION READY"
	potion_indicator.add_theme_font_size_override("font_size", 16)
	potion_indicator.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	potion_indicator.position = Vector2(20, 112)
	potion_indicator.visible = GameState.potion_charged
	add_child(potion_indicator)

	GameState.potion_mix_changed.connect(_on_potion_state_changed)
	GameState.potion_used.connect(_on_potion_state_changed)


func _on_potion_state_changed() -> void:
	if potion_indicator:
		potion_indicator.visible = GameState.potion_charged

func _on_star_fragments_changed(amount: int) -> void:
	star_fragment_reward.show_new_total(amount)


func _safe_ratio(current: float, max_value: float) -> float:
	return 0.0 if max_value <= 0 else clamp(current / max_value, 0.0, 1.0)


# --- HP ---

func _on_player_health_changed(
	current_health,
	max_health
) -> void:
	hp_bar.max_value = max_health
	hp_bar_glow.max_value = max_health
	hp_damage_bar.max_value = max_health

	if int(max_health) != _last_max_health:
		_update_bar_length(max_health)
		_last_max_health = int(max_health)

	# Drain animation: the fill itself recedes instead of snapping.
	# Main bar + its glow move together and fast; the damage overlay
	# lags behind slower, leaving a bright sliver that catches down.
	if _hp_value_tween:
		_hp_value_tween.kill()

	_hp_value_tween = create_tween()
	_hp_value_tween.set_parallel(true)

	_hp_value_tween.tween_property(
		hp_bar,
		"value",
		current_health,
		HP_DRAIN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_hp_value_tween.tween_property(
		hp_bar_glow,
		"value",
		current_health,
		HP_DRAIN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_hp_value_tween.tween_property(
		hp_damage_bar,
		"value",
		current_health,
		HP_DAMAGE_TRAIL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_apply_health_visuals(current_health, max_health)


# Grows the bar/frame rightward from the star as max_health increases.
# 50px per health point: 250px at 5 (base), 500px at 10 (max).
func _update_bar_length(max_health: float) -> void:
	var bar_width := max_health * HP_BAR_WIDTH_PER_HEALTH
	var bar_right := HP_BAR_BASE_OFFSET_LEFT + bar_width

	hp_bar.offset_right = bar_right
	hp_bar_glow.offset_right = bar_right + HP_GLOW_OVERSHOOT
	hp_damage_bar.offset_right = bar_right
	hp_empty_bar.offset_right = bar_right

	var frame_right := HP_FRAME_BASE_OFFSET_LEFT + bar_width + HP_FRAME_RIGHT_PADDING
	hp_frame.offset_right = frame_right
	hp_frame_glow.offset_right = frame_right + HP_GLOW_OVERSHOOT


func _apply_health_visuals(
	current_health: float,
	max_health: float,
	instant: bool = false
) -> void:
	var ratio := _safe_ratio(current_health, max_health)
	var from_ratio := _current_health_ratio
	_current_health_ratio = ratio

	if instant:
		_set_health_shader_params(ratio)
		_set_glow_params(ratio)
		hp_star_glow.scale = Vector2.ONE * lerp(STAR_GLOW_MIN_SCALE, STAR_GLOW_MAX_SCALE, ratio)
		return

	if _health_tween:
		_health_tween.kill()

	_health_tween = create_tween()
	_health_tween.set_parallel(true)

	_health_tween.tween_method(
		_set_health_shader_params,
		from_ratio,
		ratio,
		HEALTH_TWEEN_DURATION
	)

	_health_tween.tween_method(
		_set_glow_params,
		from_ratio,
		ratio,
		HEALTH_TWEEN_DURATION
	)

	_health_tween.tween_property(
		hp_star_glow,
		"scale",
		Vector2.ONE * lerp(STAR_GLOW_MIN_SCALE, STAR_GLOW_MAX_SCALE, ratio),
		HEALTH_TWEEN_DURATION
	)


func _set_health_shader_params(ratio: float) -> void:
	hp_frame.material.set_shader_parameter("health_ratio", ratio)
	hp_bar.material.set_shader_parameter("health_ratio", ratio)
	hp_empty_bar.material.set_shader_parameter("health_ratio", ratio)

	hp_star_particles.emitting = ratio > 0.0 and ratio <= HEALTH_LOW_THRESHOLD


func _set_glow_params(ratio: float) -> void:
	hp_frame_glow.material.set_shader_parameter(
		"intensity",
		lerp(FRAME_GLOW_MIN_INTENSITY, FRAME_GLOW_MAX_INTENSITY, ratio)
	)

	hp_bar_glow.material.set_shader_parameter(
		"intensity",
		lerp(BAR_GLOW_MIN_INTENSITY, BAR_GLOW_MAX_INTENSITY, ratio)
	)

	hp_star_glow.material.set_shader_parameter(
		"intensity",
		lerp(STAR_GLOW_MIN_INTENSITY, STAR_GLOW_MAX_INTENSITY, ratio)
	)


# --- MP ---

func _on_player_mp_changed(
	current_mp,
	max_mp
) -> void:
	mp_bar.max_value = max_mp
	mp_bar.value = current_mp

	mp_damage_bar.max_value = max_mp

	var tween := create_tween()

	tween.tween_property(
		mp_damage_bar,
		"value",
		current_mp,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_apply_mp_visuals(current_mp, max_mp)


func _apply_mp_visuals(
	current_mp: float,
	max_mp: float,
	instant: bool = false
) -> void:
	if not mp_core_glow:
		return

	var ratio := _safe_ratio(current_mp, max_mp)
	var from_ratio := _current_mp_ratio
	_current_mp_ratio = ratio

	if instant:
		_set_mp_glow_params(ratio)
		mp_core_glow.scale = Vector2.ONE * lerp(MP_GLOW_MIN_SCALE, MP_GLOW_MAX_SCALE, ratio)
		return

	if _mp_glow_tween:
		_mp_glow_tween.kill()

	_mp_glow_tween = create_tween()
	_mp_glow_tween.set_parallel(true)

	_mp_glow_tween.tween_method(
		_set_mp_glow_params,
		from_ratio,
		ratio,
		RESOURCE_GLOW_TWEEN_DURATION
	)

	_mp_glow_tween.tween_property(
		mp_core_glow,
		"scale",
		Vector2.ONE * lerp(MP_GLOW_MIN_SCALE, MP_GLOW_MAX_SCALE, ratio),
		RESOURCE_GLOW_TWEEN_DURATION
	)


func _set_mp_glow_params(ratio: float) -> void:
	mp_core_glow.material.set_shader_parameter(
		"intensity",
		lerp(MP_GLOW_MIN_INTENSITY, MP_GLOW_MAX_INTENSITY, ratio)
	)


# --- Stamina ---

func _on_player_stamina_changed(
	current_stamina,
	max_stamina
) -> void:
	if not stamina_bar:
		return

	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina

	stamina_damage_bar.max_value = max_stamina

	var tween := create_tween()

	tween.tween_property(
		stamina_damage_bar,
		"value",
		current_stamina,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_apply_stamina_visuals(current_stamina, max_stamina)


func _apply_stamina_visuals(
	current_stamina: float,
	max_stamina: float,
	instant: bool = false
) -> void:
	if not stamina_core_glow:
		return

	var ratio := _safe_ratio(current_stamina, max_stamina)
	var from_ratio := _current_stamina_ratio
	_current_stamina_ratio = ratio

	if instant:
		_set_stamina_glow_params(ratio)
		stamina_core_glow.scale = Vector2.ONE * lerp(STAMINA_GLOW_MIN_SCALE, STAMINA_GLOW_MAX_SCALE, ratio)
		return

	if _stamina_glow_tween:
		_stamina_glow_tween.kill()

	_stamina_glow_tween = create_tween()
	_stamina_glow_tween.set_parallel(true)

	_stamina_glow_tween.tween_method(
		_set_stamina_glow_params,
		from_ratio,
		ratio,
		RESOURCE_GLOW_TWEEN_DURATION
	)

	_stamina_glow_tween.tween_property(
		stamina_core_glow,
		"scale",
		Vector2.ONE * lerp(STAMINA_GLOW_MIN_SCALE, STAMINA_GLOW_MAX_SCALE, ratio),
		RESOURCE_GLOW_TWEEN_DURATION
	)


func _set_stamina_glow_params(ratio: float) -> void:
	stamina_core_glow.material.set_shader_parameter(
		"intensity",
		lerp(STAMINA_GLOW_MIN_INTENSITY, STAMINA_GLOW_MAX_INTENSITY, ratio)
	)
