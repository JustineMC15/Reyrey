extends Control
class_name StarFragmentReward

@export var display_duration: float = 3.0
@export var fade_duration: float = 0.4
@export var count_duration: float = 0.25

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel

var displayed_amount: int = 0
var target_amount: int = 0

var count_tween: Tween
var fade_tween: Tween
var hide_tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	amount_label.text = "0"


func initialize_amount(amount: int) -> void:
	displayed_amount = amount
	target_amount = amount
	amount_label.text = str(amount)


func show_new_total(new_total: int) -> void:
	if new_total <= displayed_amount:
		return

	target_amount = new_total

	# Make the notification visible.
	visible = true

	if fade_tween:
		fade_tween.kill()

	modulate.a = 1.0

	# Restart the hide countdown whenever a new reward arrives.
	_restart_hide_timer()

	# Continue counting from whatever number is currently displayed.
	if count_tween:
		count_tween.kill()

	var start_amount := displayed_amount
	var difference := target_amount - start_amount

	var duration := count_duration

	# Give larger rewards slightly more rolling time.
	if difference > 20:
		duration = min(
			count_duration + float(difference) * 0.003,
			0.5
		)

	count_tween = create_tween()

	count_tween.tween_method(
		_update_displayed_amount,
		float(start_amount),
		float(target_amount),
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_displayed_amount(value: float) -> void:
	displayed_amount = int(round(value))
	amount_label.text = str(displayed_amount)


func _restart_hide_timer() -> void:
	if hide_tween:
		hide_tween.kill()

	hide_tween = create_tween()

	hide_tween.tween_interval(display_duration)

	hide_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	)

	hide_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	hide_tween = null
