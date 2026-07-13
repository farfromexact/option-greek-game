extends Control
class_name OnboardingOverlay

signal finished
signal skipped

const ForgeTheme = preload("res://scripts/ui/theme_factory.gd")

const STEPS := [
	{
		"eyebrow": "WELCOME TO THE DESK",
		"title": "Learn one risk at a time.",
		"body": "Each mission gives you one market, one portfolio problem, and a fixed horizon. You will build, run, then explain the result.",
		"accent": "1",
	},
	{
		"eyebrow": "THE CORE LOOP",
		"title": "Build → Step → Read the change.",
		"body": "Add a position, commit your forecast, then advance the market. The bottom bar always keeps P&L, risk, and the next action in reach.",
		"accent": "2",
	},
	{
		"eyebrow": "PASS WITH AN EXPLANATION",
		"title": "A good score is controlled, not lucky.",
		"body": "Review Delta, Gamma, Theta, Vega, costs, and drawdown. Practice weather never enters the official leaderboard.",
		"accent": "3",
	},
]

var _index := 0
var _eyebrow: Label
var _title: Label
var _body: Label
var _step_label: Label
var _back_button: Button
var _next_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_render_step()
	_next_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skipped.emit()
		queue_free()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.02, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_right = -24.0
	center.offset_top = 24.0
	center.offset_bottom = -24.0
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620.0, 430.0)
	card.add_theme_stylebox_override(
		"panel",
		ForgeTheme.panel_style(ForgeTheme.SURFACE_RAISED, 24, ForgeTheme.BORDER_STRONG, 1),
	)
	center.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	card.add_child(content)

	var top := HBoxContainer.new()
	content.add_child(top)

	var brand := Label.new()
	brand.text = "VOLATILITY FORGE 2D"
	brand.add_theme_color_override("font_color", ForgeTheme.TEAL)
	brand.add_theme_font_size_override("font_size", 13)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)

	var skip_button := Button.new()
	skip_button.text = "Skip for now"
	skip_button.tooltip_text = "Close the introduction. You can reopen it from Help."
	skip_button.custom_minimum_size.y = 44.0
	skip_button.pressed.connect(_skip)
	top.add_child(skip_button)

	_step_label = Label.new()
	_step_label.add_theme_color_override("font_color", ForgeTheme.AMBER)
	_step_label.add_theme_font_size_override("font_size", 52)
	content.add_child(_step_label)

	_eyebrow = Label.new()
	_eyebrow.add_theme_color_override("font_color", ForgeTheme.MUTED)
	_eyebrow.add_theme_font_size_override("font_size", 13)
	content.add_child(_eyebrow)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", ForgeTheme.TEXT)
	content.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", ForgeTheme.MUTED)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(110.0, 48.0)
	_back_button.pressed.connect(_back)
	actions.add_child(_back_button)

	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(160.0, 48.0)
	ForgeTheme.apply_primary(_next_button)
	_next_button.pressed.connect(_next)
	actions.add_child(_next_button)


func _render_step() -> void:
	var step: Dictionary = STEPS[_index]
	_step_label.text = str(step.accent).pad_zeros(2)
	_eyebrow.text = str(step.eyebrow)
	_title.text = str(step.title)
	_body.text = str(step.body)
	_back_button.visible = _index > 0
	_next_button.text = "Start first mission" if _index == STEPS.size() - 1 else "Continue"


func _skip() -> void:
	skipped.emit()
	queue_free()


func _back() -> void:
	_index = maxi(0, _index - 1)
	_render_step()
	_next_button.grab_focus()


func _next() -> void:
	if _index >= STEPS.size() - 1:
		finished.emit()
		queue_free()
		return
	_index += 1
	_render_step()
	_next_button.grab_focus()
